"""Tests for scripts/load_binance.py — Binance funding rate loader.

Integration tests require a running PostgreSQL with pre-loaded data.
Set PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD env vars to override defaults.
"""

from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timezone

import psycopg2
import pytest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

DB_CONFIG = {
    "host": os.environ.get("PGHOST", "localhost"),
    "port": int(os.environ.get("PGPORT", "5432")),
    "dbname": os.environ.get("PGDATABASE", "funding_rates"),
    "user": os.environ.get("PGUSER", "postgres"),
    "password": os.environ.get("PGPASSWORD", "postgres"),
}

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _get_conn():
    return psycopg2.connect(**DB_CONFIG)


def _run_loader(*extra_args: str) -> subprocess.CompletedProcess:
    """Run the loader script as a subprocess."""
    cmd = [sys.executable, "scripts/load_binance.py"] + list(extra_args)
    env = {**os.environ}
    env["PGHOST"] = DB_CONFIG["host"]
    env["PGPORT"] = str(DB_CONFIG["port"])
    env["PGDATABASE"] = DB_CONFIG["dbname"]
    env["PGUSER"] = DB_CONFIG["user"]
    env["PGPASSWORD"] = DB_CONFIG["password"]
    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        env=env,
        cwd=PROJECT_ROOT,
        timeout=600,
    )


# ---------------------------------------------------------------------------
# Unit tests (no DB required)
# ---------------------------------------------------------------------------


class TestMonthRange:
    """Tests for the month_range helper."""

    def test_single_month(self):
        from scripts.load_binance import month_range
        assert month_range("2020-01", "2020-01") == ["2020-01"]

    def test_cross_year(self):
        from scripts.load_binance import month_range
        result = month_range("2020-11", "2021-02")
        assert result == ["2020-11", "2020-12", "2021-01", "2021-02"]

    def test_full_year(self):
        from scripts.load_binance import month_range
        result = month_range("2020-01", "2020-12")
        assert len(result) == 12
        assert result[0] == "2020-01"
        assert result[-1] == "2020-12"


class TestParseCsv:
    """Tests for CSV parsing from ZIP bytes."""

    def test_parse_real_zip(self):
        """Download a real ZIP and verify parsing."""
        from scripts.load_binance import download_zip, parse_csv_from_zip
        zip_data = download_zip("BTCUSDT", "2020-01")
        assert zip_data is not None
        rows = parse_csv_from_zip(zip_data)
        assert len(rows) > 80  # ~90 rows per month at 8h intervals
        # Each row is (ts, funding_rate, funding_time_ms)
        ts, rate, ftms = rows[0]
        assert isinstance(ts, datetime)
        assert ts.tzinfo is not None
        assert isinstance(rate, float)
        assert isinstance(ftms, int)

    def test_404_returns_none(self):
        """SOLUSDT didn't exist in Jan 2020."""
        from scripts.load_binance import download_zip
        result = download_zip("SOLUSDT", "2020-01")
        assert result is None


# ---------------------------------------------------------------------------
# Integration tests (require DB with pre-loaded data)
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def db_conn():
    """Connect to the DB (assumes data is already loaded)."""
    conn = _get_conn()
    yield conn
    conn.close()


class TestRowCountMinimum:
    """Verify minimum row counts against pre-loaded data."""

    def test_btcusdt_over_7000(self, db_conn):
        cur = db_conn.cursor()
        cur.execute("SELECT count(*) FROM raw.funding_binance WHERE symbol = 'BTCUSDT'")
        count = cur.fetchone()[0]
        assert count > 7000, f"BTCUSDT has only {count} rows, expected > 7000"

    def test_ethusdt_over_7000(self, db_conn):
        cur = db_conn.cursor()
        cur.execute("SELECT count(*) FROM raw.funding_binance WHERE symbol = 'ETHUSDT'")
        count = cur.fetchone()[0]
        assert count > 7000, f"ETHUSDT has only {count} rows, expected > 7000"

    def test_solusdt_over_4000(self, db_conn):
        cur = db_conn.cursor()
        cur.execute("SELECT count(*) FROM raw.funding_binance WHERE symbol = 'SOLUSDT'")
        count = cur.fetchone()[0]
        assert count > 4000, f"SOLUSDT has only {count} rows, expected > 4000"


class TestDateRange:
    """Verify date range coverage."""

    def test_btcusdt_starts_before_2020_02(self, db_conn):
        cur = db_conn.cursor()
        cur.execute("SELECT min(ts) FROM raw.funding_binance WHERE symbol = 'BTCUSDT'")
        min_ts = cur.fetchone()[0]
        assert min_ts is not None
        cutoff = datetime(2020, 2, 1, tzinfo=timezone.utc)
        assert min_ts <= cutoff, f"BTCUSDT min(ts) = {min_ts}, expected ≤ {cutoff}"


class TestSymbolCoverage:
    """Verify all three symbols are present."""

    def test_all_symbols_present(self, db_conn):
        cur = db_conn.cursor()
        cur.execute(
            "SELECT DISTINCT symbol FROM raw.funding_binance "
            "WHERE symbol IN ('BTCUSDT', 'ETHUSDT', 'SOLUSDT') "
            "ORDER BY symbol"
        )
        symbols = [row[0] for row in cur.fetchall()]
        assert symbols == ["BTCUSDT", "ETHUSDT", "SOLUSDT"]


class TestIdempotent:
    """Verify script idempotency using a limited range to avoid full reload."""

    def test_limited_rerun_is_idempotent(self, db_conn):
        """Run loader on a tiny range (1 month, 1 symbol) twice; counts must match."""
        sym = "BTCUSDT"
        start, end = "2020-01", "2020-01"

        # Get count before
        cur = db_conn.cursor()
        cur.execute(
            "SELECT count(*) FROM raw.funding_binance WHERE symbol = %s AND ts >= %s",
            (sym, f"{start}-01"),
        )

        # Run loader on just this slice
        r1 = _run_loader("--symbols", sym, "--start", start, "--end", end)
        assert r1.returncode == 0, f"First run failed:\n{r1.stderr}"

        cur.execute("SELECT count(*) FROM raw.funding_binance WHERE symbol = %s", (sym,))
        count_after_1 = cur.fetchone()[0]

        # Run again
        r2 = _run_loader("--symbols", sym, "--start", start, "--end", end)
        assert r2.returncode == 0, f"Second run failed:\n{r2.stderr}"

        cur.execute("SELECT count(*) FROM raw.funding_binance WHERE symbol = %s", (sym,))
        count_after_2 = cur.fetchone()[0]

        assert count_after_2 == count_after_1, (
            f"Count changed from {count_after_1} to {count_after_2} after re-run"
        )
