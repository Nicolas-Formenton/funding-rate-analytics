"""Tests for scripts/load_equity_perps.py.

The loader is a *hunter* that tries multiple equity perps sources and
ingests whatever it finds.  These tests assert the contract required by
Task 9:

1. At least one venue ingested data (raw.funding_equity_perps is not empty).
2. At least one equity symbol is present.
3. Weekend data exists — critical for downstream oracle-freeze research.
4. Re-running the loader is idempotent: no duplicate rows are created.

The fixture in this file runs the loader once via subprocess so the
tests have a known data state.  ``test_idempotent`` then runs the loader
a second time and asserts the row count is unchanged.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import psycopg2
import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = PROJECT_ROOT / "scripts" / "load_equity_perps.py"

DEFAULT_DB = {
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": int(os.getenv("POSTGRES_PORT", "5432")),
    "user": os.getenv("POSTGRES_USER", "postgres"),
    "password": os.getenv("POSTGRES_PASSWORD", "postgres"),
    "dbname": os.getenv("POSTGRES_DB", "funding_rates"),
}


def _conn():
    return psycopg2.connect(**DEFAULT_DB)


def _run_loader() -> subprocess.CompletedProcess:
    """Execute the hunter script as a subprocess and return its result."""
    return subprocess.run(
        [sys.executable, str(SCRIPT)],
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
        timeout=300,
        env={**os.environ,
             "POSTGRES_HOST": DEFAULT_DB["host"],
             "POSTGRES_PORT": str(DEFAULT_DB["port"]),
             "POSTGRES_USER": DEFAULT_DB["user"],
             "POSTGRES_PASSWORD": DEFAULT_DB["password"],
             "POSTGRES_DB": DEFAULT_DB["dbname"]},
    )


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module", autouse=True)
def ensure_data_loaded():
    """Run the loader once before any test executes.

    Uses module scope so the data is shared across tests in this file
    (loading takes ~5–15 s with the current source count).
    """
    if not SCRIPT.exists():
        pytest.fail(f"Loader script not found: {SCRIPT}")
    result = _run_loader()
    # Log the loader output so a failure is debuggable from pytest -s.
    if result.returncode != 0:
        sys.stderr.write("--- loader stdout ---\n" + result.stdout + "\n")
        sys.stderr.write("--- loader stderr ---\n" + result.stderr + "\n")


@pytest.fixture(scope="module")
def table_counts() -> dict:
    """Snapshot the distinct venues, symbols, and weekend counts once."""
    with _conn() as conn, conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM raw.funding_equity_perps")
        total = cur.fetchone()[0]
        cur.execute(
            "SELECT COUNT(DISTINCT venue) FROM raw.funding_equity_perps"
        )
        venues = cur.fetchone()[0]
        cur.execute(
            "SELECT COUNT(DISTINCT symbol) FROM raw.funding_equity_perps"
        )
        symbols = cur.fetchone()[0]
        cur.execute(
            """
            SELECT COUNT(*) FROM raw.funding_equity_perps
            WHERE EXTRACT(DOW FROM ts AT TIME ZONE 'UTC') IN (0, 6)
            """
        )
        weekend = cur.fetchone()[0]
    return {"total": total, "venues": venues, "symbols": symbols, "weekend": weekend}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


def test_at_least_one_venue(table_counts) -> None:
    """At least one venue must have written at least one row."""
    assert table_counts["venues"] >= 1, (
        "No venues in raw.funding_equity_perps; loader reported all sources "
        "empty (see .omo/evidence/task-9-equity-rows.txt)."
    )
    assert table_counts["total"] > 0, (
        "raw.funding_equity_perps is empty after loader run"
    )


def test_at_least_one_symbol(table_counts) -> None:
    """At least one equity symbol must be present in the data."""
    assert table_counts["symbols"] >= 1, (
        "raw.funding_equity_perps has no equity symbols ingested"
    )


def test_weekend_data(table_counts) -> None:
    """At least one row must fall on a Saturday (DOW=6) or Sunday (DOW=0).

    The oracle-freeze research depends on weekend funding data, so this
    is a hard requirement, not a soft check.  Binance equity perps
    charge funding on weekends (verified during research on 2026-04-11
    Saturday); if the test ever fails after that, the loader probably
    regressed and lost the weekend window.
    """
    assert table_counts["weekend"] >= 1, (
        "No weekend rows (DOW IN (0, 6)) in raw.funding_equity_perps; "
        "oracle-freeze research cannot proceed without weekend funding."
    )


def test_idempotent(table_counts) -> None:
    """Running the loader a second time must not add new rows.

    The UNIQUE INDEX on (ts, venue, symbol) plus
    ``ON CONFLICT DO NOTHING`` guarantees this.  We re-run the loader
    and assert the row count is unchanged.
    """
    before = table_counts["total"]
    result = _run_loader()
    assert result.returncode == 0, (
        f"Second loader run failed (rc={result.returncode}): {result.stderr}"
    )
    with _conn() as conn, conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM raw.funding_equity_perps")
        after = cur.fetchone()[0]
    assert after == before, (
        f"Loader is not idempotent: row count changed {before} -> {after} "
        f"after a second run."
    )
