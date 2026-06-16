"""
Tests for scripts/load_hyperliquid.py.

These are integration tests: they assume the loader has already been run
against the local Docker Postgres (``funding-rates-pg``) so that
``raw.funding_hyperliquid`` is populated.

If the DB is unreachable the tests are skipped (the CI environment for
this pipeline is a single-host Docker setup, so the skip is a safety net
for contributors who run ``pytest`` without the container up).
"""
from __future__ import annotations

import os

import psycopg2
import pytest

DSN = os.environ.get(
    "FUNDING_RATES_DSN",
    "host=localhost port=5432 user=postgres password=postgres dbname=funding_rates",
)


def _connect_or_skip():
    try:
        conn = psycopg2.connect(DSN)
    except psycopg2.OperationalError as exc:
        pytest.skip(f"Postgres unavailable, skipping integration test: {exc}")
    return conn


@pytest.fixture(scope="module")
def db_conn():
    conn = _connect_or_skip()
    yield conn
    conn.close()


class TestRawHyperliquid:
    """Post-load invariants on ``raw.funding_hyperliquid``."""

    def test_row_count_minimum(self, db_conn) -> None:
        """BTC must have >4000 rows (≈6 months × 30 days × 24 h)."""
        with db_conn.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) FROM raw.funding_hyperliquid WHERE coin = %s",
                ("BTC",),
            )
            (count,) = cur.fetchone()
        assert count > 4000, f"BTC row count {count} not > 4000"

    def test_hourly_granularity(self, db_conn) -> None:
        """No sub-hourly duplicates: at most one row per (coin, hour bucket)."""
        with db_conn.cursor() as cur:
            cur.execute(
                """
                SELECT coin, COUNT(*) - COUNT(DISTINCT date_trunc('hour', ts)) AS dupes
                FROM raw.funding_hyperliquid
                GROUP BY coin
                HAVING COUNT(*) - COUNT(DISTINCT date_trunc('hour', ts)) > 0
                """
            )
            offenders = cur.fetchall()
        assert not offenders, f"sub-hourly duplicates present: {offenders}"

    def test_symbol_coverage(self, db_conn) -> None:
        """BTC, ETH, and SOL must each be present (any positive row count)."""
        with db_conn.cursor() as cur:
            cur.execute(
                "SELECT coin, COUNT(*) FROM raw.funding_hyperliquid "
                "WHERE coin IN ('BTC', 'ETH', 'SOL') GROUP BY coin"
            )
            rows = dict(cur.fetchall())
        for coin in ("BTC", "ETH", "SOL"):
            assert coin in rows, f"Missing rows for {coin}"
            assert rows[coin] > 0, f"{coin} has 0 rows in raw.funding_hyperliquid"
