#!/usr/bin/env python3
"""
Push local Docker PostgreSQL data to Supabase.

Strategy: pipe pg_dump output directly into psql against Supabase.
This is the most efficient approach for medium-sized datasets (~550K rows).

Usage:
    export SUPABASE_URL="postgresql://postgres.xxxxx:password@aws-0-us-east-1.pooler.supabase.com:6543/postgres"
    python scripts/push_to_supabase.py

Requires:
    - Local Docker PG running (postgres:postgres@localhost:5432/funding_rates)
    - psql and pg_dump installed locally
    - SUPABASE_URL environment variable set
"""

import os
import subprocess
import sys
import time

LOCAL_URL = "postgresql://postgres:postgres@localhost:5432/funding_rates"

SCHEMAS_WITH_TABLES = {
    "raw": ["funding_binance", "funding_hyperliquid", "funding_deribit", "funding_equity_perps"],
    "staging": ["stg_funding_events"],  # view, not a table — DDL only, no data
    "marts": ["mart_hourly_funding", "mart_daily_funding", "mart_venue_comparison"],
}


def run(cmd: str, label: str = "", check: bool = True) -> subprocess.CompletedProcess:
    """Run a shell command with optional label for logging."""
    print(f"  → {label or cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=False, text=True)
    if check and result.returncode != 0:
        print(f"  ✗ ERROR (exit {result.returncode})")
        if result.stderr:
            print(f"    stderr: {result.stderr[:500]}")
        sys.exit(result.returncode)
    return result


def get_local_row_counts() -> dict[str, int]:
    """Query row counts for each table in local PG."""
    counts: dict[str, int] = {}
    query_parts = []
    for schema, tables in SCHEMAS_WITH_TABLES.items():
        for table in tables:
            query_parts.append(
                f"SELECT '{schema}.{table}' AS tbl, COUNT(*) AS cnt FROM {schema}.{table}"
            )
    if not query_parts:
        return counts
    union_query = " UNION ALL ".join(query_parts)
    # Use psql to query and parse
    cmd = (
        f'psql "{LOCAL_URL}" -t -A -F"|" '
        f'-c "{union_query}"'
    )
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  ⚠ Could not query row counts: {result.stderr[:200]}")
        return counts
    for line in result.stdout.strip().splitlines():
        line = line.strip()
        if not line or "|" not in line:
            continue
        tbl, cnt = line.split("|", 1)
        counts[tbl.strip()] = int(cnt.strip())
    return counts


def push_ddl() -> None:
    """Push schema DDL (no data) to Supabase — raw first, then staging, then marts."""
    print("  Schema: raw tables...")
    run(
        f'pg_dump "{LOCAL_URL}" --schema-only --schema=raw | psql "{SUPABASE_URL}"',
        label="raw tables DDL",
    )
    print("  Schema: staging views...")
    run(
        f'pg_dump "{LOCAL_URL}" --schema-only --schema=staging | psql "{SUPABASE_URL}"',
        label="staging views DDL",
    )
    print("  Schema: marts tables...")
    run(
        f'pg_dump "{LOCAL_URL}" --schema-only --schema=marts | psql "{SUPABASE_URL}"',
        label="marts tables DDL",
    )


def push_data() -> None:
    """Push data rows for raw and marts schemas (staging is views only)."""
    print("  Data: raw tables...")
    run(
        f'pg_dump "{LOCAL_URL}" --data-only --schema=raw | psql "{SUPABASE_URL}"',
        label="raw data",
    )
    print("  Data: marts tables...")
    run(
        f'pg_dump "{LOCAL_URL}" --data-only --schema=marts | psql "{SUPABASE_URL}"',
        label="marts data",
    )


def verify_counts() -> bool:
    """Compare row counts between local and Supabase."""
    print("  Verifying row counts...")
    verify_queries = []
    for schema, tables in SCHEMAS_WITH_TABLES.items():
        if schema == "staging":
            continue  # view — no data to verify
        for table in tables:
            verify_queries.append(
                f"SELECT '{schema}.{table}' AS tbl, COUNT(*) FROM {schema}.{table}"
            )
    union_query = " UNION ALL ".join(verify_queries)
    local_cmd = f'psql "{LOCAL_URL}" -t -A -F"|" -c "{union_query}"'
    remote_cmd = f'psql "{SUPABASE_URL}" -t -A -F"|" -c "{union_query}"'

    local_result = subprocess.run(local_cmd, shell=True, capture_output=True, text=True)
    remote_result = subprocess.run(remote_cmd, shell=True, capture_output=True, text=True)

    if local_result.returncode != 0 or remote_result.returncode != 0:
        print("  ⚠ Verification query failed — check connectivity")
        return False

    local_counts: dict[str, int] = {}
    remote_counts: dict[str, int] = {}

    for line in local_result.stdout.strip().splitlines():
        line = line.strip()
        if "|" not in line:
            continue
        tbl, cnt = line.split("|", 1)
        local_counts[tbl.strip()] = int(cnt.strip())

    for line in remote_result.stdout.strip().splitlines():
        line = line.strip()
        if "|" not in line:
            continue
        tbl, cnt = line.split("|", 1)
        remote_counts[tbl.strip()] = int(cnt.strip())

    all_ok = True
    for tbl in sorted(set(list(local_counts.keys()) + list(remote_counts.keys()))):
        lc = local_counts.get(tbl, 0)
        rc = remote_counts.get(tbl, 0)
        status = "✓" if lc == rc else "✗ MISMATCH"
        if lc != rc:
            all_ok = False
        print(f"    {status} {tbl}: local={lc}  remote={rc}")

    return all_ok


def main() -> None:
    global SUPABASE_URL
    SUPABASE_URL = os.environ.get("SUPABASE_URL")
    if not SUPABASE_URL:
        print("ERROR: SUPABASE_URL environment variable is not set.")
        print("  export SUPABASE_URL='postgresql://postgres.xxxxx:password@...'")
        sys.exit(1)

    print("=" * 60)
    print("  Push local Docker PG → Supabase")
    print("=" * 60)

    # Phase 0: Gather local row counts for progress logging
    print("\n[0/4] Gathering local row counts...")
    counts = get_local_row_counts()
    total_rows = sum(counts.values())
    for tbl, cnt in counts.items():
        print(f"    {tbl}: {cnt:,} rows")
    print(f"    Total: {total_rows:,} rows")

    # Phase 1: Push DDL
    print(f"\n[1/4] Pushing DDL ({len(SCHEMAS_WITH_TABLES)} schemas)...")
    start = time.time()
    push_ddl()
    print(f"    ✓ DDL pushed ({time.time() - start:.1f}s)")

    # Phase 2: Push data
    print(f"\n[2/4] Pushing data ({total_rows:,} rows)...")
    start = time.time()
    push_data()
    print(f"    ✓ Data pushed ({time.time() - start:.1f}s)")

    # Phase 3: Verify
    print(f"\n[3/4] Verifying data integrity...")
    ok = verify_counts()
    print(f"\n[4/4] {'✓ Push complete — all counts match!' if ok else '⚠ Push completed but counts differ. Check logs above.'}")

    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
