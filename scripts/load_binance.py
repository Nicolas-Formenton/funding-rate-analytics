#!/usr/bin/env python3
"""
Idempotent Binance historical funding rate loader.

Downloads monthly ZIP files from data.binance.vision and loads them into
raw.funding_binance. Uses DELETE-per-symbol strategy for idempotency.

Usage:
    python3 scripts/load_binance.py                          # Full load, all symbols
    python3 scripts/load_binance.py --symbols BTCUSDT        # Single symbol
    python3 scripts/load_binance.py --start 2020-01 --end 2020-02  # Date range
    python3 scripts/load_binance.py --dry-run                # Preview without inserting
"""

from __future__ import annotations

import argparse
import csv
import io
import logging
import os
import sys
import time
import zipfile
from datetime import datetime, timezone
from typing import Optional

import psycopg2
import requests

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

BASE_URL = "https://data.binance.vision/data/futures/um/monthly/fundingRate"
DEFAULT_SYMBOLS = ["BTCUSDT", "ETHUSDT", "SOLUSDT"]
DEFAULT_START = "2020-01"
MAX_RETRIES = 3
RETRY_DELAY = 2  # seconds

DB_CONFIG = {
    "host": os.environ.get("PGHOST", "localhost"),
    "port": int(os.environ.get("PGPORT", "5432")),
    "dbname": os.environ.get("PGDATABASE", "funding_rates"),
    "user": os.environ.get("PGUSER", "postgres"),
    "password": os.environ.get("PGPASSWORD", "postgres"),
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("load_binance")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def month_range(start: str, end: str) -> list[str]:
    """Generate YYYY-MM strings from start to end (inclusive)."""
    sy, sm = map(int, start.split("-"))
    ey, em = map(int, end.split("-"))
    months = []
    y, m = sy, sm
    while (y, m) <= (ey, em):
        months.append(f"{y:04d}-{m:02d}")
        m += 1
        if m > 12:
            m = 1
            y += 1
    return months


def download_zip(symbol: str, year_month: str) -> Optional[bytes]:
    """Download a monthly funding rate ZIP. Returns bytes or None on 404."""
    url = f"{BASE_URL}/{symbol}/{symbol}-fundingRate-{year_month}.zip"
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = requests.get(url, timeout=30)
            if resp.status_code == 404:
                return None
            resp.raise_for_status()
            return resp.content
        except requests.RequestException as exc:
            if attempt < MAX_RETRIES:
                log.warning("Retry %d/%d for %s: %s", attempt, MAX_RETRIES, url, exc)
                time.sleep(RETRY_DELAY * attempt)
            else:
                log.error("Failed after %d retries: %s", MAX_RETRIES, url)
                raise
    return None


def parse_csv_from_zip(zip_bytes: bytes) -> list[tuple]:
    """Extract CSV from ZIP, parse funding rows.

    Returns list of (ts, funding_rate, funding_time_ms) tuples.
    CSV columns: calc_time, funding_interval_hours, last_funding_rate
    """
    zf = zipfile.ZipFile(io.BytesIO(zip_bytes))
    csv_name = zf.namelist()[0]
    rows = []
    with zf.open(csv_name) as f:
        reader = csv.reader(io.TextIOWrapper(f, encoding="utf-8"))
        header = next(reader)  # skip header
        for line in reader:
            if len(line) < 3:
                continue
            calc_time_ms = int(line[0])
            funding_rate = float(line[2])
            ts = datetime.fromtimestamp(calc_time_ms / 1000.0, tz=timezone.utc)
            rows.append((ts, funding_rate, calc_time_ms))
    return rows


def get_db_connection():
    """Create a psycopg2 connection."""
    return psycopg2.connect(**DB_CONFIG)


# ---------------------------------------------------------------------------
# Core loader
# ---------------------------------------------------------------------------


def load_symbol(
    conn,
    symbol: str,
    months: list[str],
    dry_run: bool = False,
) -> dict:
    """Load all months for a single symbol. Returns stats dict."""
    total_rows = 0
    loaded_months = 0
    skipped_months = 0

    # Idempotency: delete existing rows for this symbol
    if not dry_run:
        cur = conn.cursor()
        cur.execute("DELETE FROM raw.funding_binance WHERE symbol = %s", (symbol,))
        deleted = cur.rowcount
        conn.commit()
        if deleted > 0:
            log.info("Deleted %d existing rows for %s", deleted, symbol)

    total_months = len(months)
    for idx, ym in enumerate(months, 1):
        zip_data = download_zip(symbol, ym)
        if zip_data is None:
            skipped_months += 1
            continue

        rows = parse_csv_from_zip(zip_data)
        if not rows:
            skipped_months += 1
            continue

        if not dry_run:
            cur = conn.cursor()
            args = [
                (ts, symbol, rate, ftms, None, None)
                for ts, rate, ftms in rows
            ]
            cur.executemany(
                """INSERT INTO raw.funding_binance
                   (ts, symbol, funding_rate, funding_time_ms, mark_price, index_price)
                   VALUES (%s, %s, %s, %s, %s, %s)""",
                args,
            )
            conn.commit()

        total_rows += len(rows)
        loaded_months += 1
        log.info(
            "Month %d/%d: %s %s: %d rows loaded",
            idx, total_months, ym, symbol, len(rows),
        )

    return {
        "symbol": symbol,
        "total_rows": total_rows,
        "loaded_months": loaded_months,
        "skipped_months": skipped_months,
    }


def load_all(
    symbols: list[str],
    start: str,
    end: str,
    dry_run: bool = False,
) -> list[dict]:
    """Load funding rates for all symbols."""
    months = month_range(start, end)
    log.info(
        "Loading %d symbols × %d months (%s → %s)%s",
        len(symbols), len(months), start, end,
        " [DRY RUN]" if dry_run else "",
    )

    conn = get_db_connection()
    results = []
    try:
        for sym in symbols:
            stats = load_symbol(conn, sym, months, dry_run=dry_run)
            results.append(stats)
            log.info(
                "✓ %s: %d rows from %d months (%d skipped)",
                sym, stats["total_rows"], stats["loaded_months"], stats["skipped_months"],
            )
    finally:
        conn.close()

    grand_total = sum(r["total_rows"] for r in results)
    log.info("Total: %d rows across %d symbols", grand_total, len(symbols))
    return results


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description="Binance funding rate loader")
    parser.add_argument(
        "--symbols", nargs="+", default=DEFAULT_SYMBOLS,
        help=f"Symbols to load (default: {DEFAULT_SYMBOLS})",
    )
    parser.add_argument("--start", default=DEFAULT_START, help="Start month YYYY-MM")
    parser.add_argument(
        "--end",
        default=datetime.now(timezone.utc).strftime("%Y-%m"),
        help="End month YYYY-MM (default: current month)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Preview without inserting")
    args = parser.parse_args()

    results = load_all(args.symbols, args.start, args.end, dry_run=args.dry_run)

    # Print summary
    log.info("=== Summary ===")
    for r in results:
        log.info("  %s: %d rows, %d months loaded, %d skipped", r['symbol'], r['total_rows'], r['loaded_months'], r['skipped_months'])
    log.info("  Grand total: %d rows", sum(r['total_rows'] for r in results))


if __name__ == "__main__":
    main()
