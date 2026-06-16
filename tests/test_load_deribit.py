"""Tests for scripts/load_deribit.py.

These tests assume the loader has already been run against the local
Docker Postgres instance (``localhost:5432``, db ``funding_rates``) and
that ``raw.funding_deribit`` is populated.  The ``test_idempotent_reload``
test does invoke the loader twice on a small window to verify the
truncate-and-reload path is safe.
"""

from __future__ import annotations

import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable

import psycopg2
import psycopg2.extras
import pytest

# Make scripts/ importable.
SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

from load_deribit import DB_DEFAULTS, load_instrument  # noqa: E402


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _connect():
    return psycopg2.connect(**DB_DEFAULTS)


def _count_rows(instrument: str | None = None) -> int:
    with _connect() as conn, conn.cursor() as cur:
        if instrument is None:
            cur.execute("SELECT COUNT(*) FROM raw.funding_deribit")
        else:
            cur.execute(
                "SELECT COUNT(*) FROM raw.funding_deribit "
                "WHERE instrument_name = %s",
                (instrument,),
            )
        return cur.fetchone()[0]


def _instruments() -> list[str]:
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT DISTINCT instrument_name FROM raw.funding_deribit "
            "ORDER BY instrument_name"
        )
        return [r[0] for r in cur.fetchall()]


def _min_ts(instrument: str) -> datetime | None:
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT MIN(ts) FROM raw.funding_deribit "
            "WHERE instrument_name = %s",
            (instrument,),
        )
        return cur.fetchone()[0]


class _FakeResponse:
    """Minimal stand-in for ``requests.Response`` used by ``_fetch_window``."""

    def __init__(self, payload: dict[str, Any], status_code: int = 200) -> None:
        self._payload = payload
        self.status_code = status_code
        self.text = ""

    def json(self) -> dict[str, Any]:
        return self._payload


def _make_session(records_per_window: int) -> Any:
    """Build a fake ``requests.Session`` that returns deterministic records.

    Each call to ``post`` produces a window with the given number of
    records (timestamped hourly starting from 2020-01-01 UTC).  This is
    enough to exercise the truncate-and-reload code path without
    hitting Deribit.
    """

    class _FakeSession:
        def __init__(self) -> None:
            self.call_count = 0

        def close(self) -> None:
            pass

        def post(self, url: str, json: dict, timeout: int) -> _FakeResponse:
            self.call_count += 1
            params = json["params"]
            start_ms = params["start_timestamp"]
            result = []
            for i in range(records_per_window):
                result.append(
                    {
                        "timestamp": start_ms + i * 3_600_000,
                        "interest_8h": 0.0001 * (i + 1),
                        "interest_1h": 0.0000125 * (i + 1),
                        "index_price": 10000.0 + i,
                        "prev_index_price": 10000.0 + i - 1,
                    }
                )
            return _FakeResponse(
                {"jsonrpc": "2.0", "id": 1, "result": result}
            )

    return _FakeSession()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestPopulatedTable:
    """Tests that exercise the already-loaded data in ``raw.funding_deribit``."""

    def test_row_count_minimum(self) -> None:
        """BTC-PERPETUAL must have more than 7,000 rows."""
        btc_rows = _count_rows("BTC-PERPETUAL")
        assert btc_rows > 7_000, (
            f"BTC-PERPETUAL only has {btc_rows} rows; expected > 7000"
        )

    def test_date_range(self) -> None:
        """Earliest BTC-PERPETUAL row must be on or before 2019-06-01."""
        earliest = _min_ts("BTC-PERPETUAL")
        assert earliest is not None, "No BTC-PERPETUAL rows found"
        cutoff = datetime(2019, 6, 1, tzinfo=timezone.utc)
        assert earliest <= cutoff, (
            f"Earliest BTC-PERPETUAL row is {earliest.isoformat()}, "
            f"expected <= {cutoff.isoformat()}"
        )

    def test_instrument_coverage(self) -> None:
        """Both BTC-PERPETUAL and ETH-PERPETUAL must be present."""
        instruments = _instruments()
        assert "BTC-PERPETUAL" in instruments, instruments
        assert "ETH-PERPETUAL" in instruments, instruments


class TestIdempotentReload:
    """Run the loader twice against a synthetic session to verify idempotency."""

    def test_idempotent(self) -> None:
        end = datetime(2020, 1, 8, tzinfo=timezone.utc)
        start = end - timedelta(days=1)  # 1 day => 1 window

        # Use a dedicated instrument name so this test never touches
        # the production BTC/ETH data.
        test_instrument = "TEST-IDEMPOTENT"
        records_per_window = 24

        # ``load_instrument`` calls ``conn_factory(**DB_DEFAULTS)``, so
        # we need a factory that accepts those kwargs (not the no-arg
        # ``_connect`` helper used elsewhere in this file).
        def conn_factory(**kwargs):
            return psycopg2.connect(**kwargs)

        # Clean up any leftover from a previous failed run.
        with _connect() as conn, conn.cursor() as cur:
            cur.execute(
                "DELETE FROM raw.funding_deribit "
                "WHERE instrument_name = %s",
                (test_instrument,),
            )
            conn.commit()

        # First run: insert.
        load_instrument(
            test_instrument,
            start,
            end,
            conn_factory=conn_factory,
            session_factory=lambda: _make_session(records_per_window),
        )
        first_count = _count_rows(test_instrument)
        assert first_count == records_per_window, first_count

        # Second run: truncate + reload must give the same count.
        load_instrument(
            test_instrument,
            start,
            end,
            conn_factory=conn_factory,
            session_factory=lambda: _make_session(records_per_window),
        )
        second_count = _count_rows(test_instrument)
        assert second_count == records_per_window, second_count
        assert second_count == first_count

        # Cleanup: leave the table tidy.
        with _connect() as conn, conn.cursor() as cur:
            cur.execute(
                "DELETE FROM raw.funding_deribit "
                "WHERE instrument_name = %s",
                (test_instrument,),
            )
            conn.commit()
