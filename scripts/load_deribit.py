"""
Deribit perpetual-futures funding-rate historical loader.

Pulls historical funding-rate history for Deribit's perpetual futures
(``BTC-PERPETUAL`` and ``ETH-PERPETUAL``) from the public JSON-RPC
endpoint ``public/get_funding_rate_history`` and writes the records into
``raw.funding_deribit`` in the local Postgres instance.

The loader is idempotent per instrument: it truncates the rows for the
instrument being loaded before inserting the freshly fetched history.

API
---
- Endpoint: ``POST https://www.deribit.com/api/v2/public/get_funding_rate_history``
- Body:    ``{"jsonrpc":"2.0","method":"public/get_funding_rate_history",
  "params":{"instrument_name":<name>,"start_timestamp":<ms>,
  "end_timestamp":<ms>},"id":1}``
- Response (per record): ``timestamp`` (ms), ``interest_8h``,
  ``interest_1h``, ``index_price``, ``prev_index_price``.

Notes
-----
- Deribit caps each response at ~744 records.  Hourly funding means ~24
  records / day, so we paginate in **1-week** windows (≤ ~168 records
  each) for safety margin.
- Deribit's public API does **not** return ``mark_price`` on
  ``get_funding_rate_history``; only ``index_price`` and
  ``prev_index_price``.  We therefore store ``mark_price`` as NULL.
  Normalisation across venues happens later in dbt staging.
- Rate limiting: the public endpoint is uncapped for our usage, but we
  add exponential backoff (1s, 2s, 4s, 8s) on transient failures
  (HTTP 429 / 5xx, JSON-RPC errors) just in case.
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
import time
from datetime import datetime, timezone
from typing import Any, Optional

import psycopg2
import psycopg2.extras
import requests

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DERIBIT_URL = "https://www.deribit.com/api/v2/public/get_funding_rate_history"

# Instruments to load.  Order is preserved in the tracker output.
INSTRUMENTS = ("BTC-PERPETUAL", "ETH-PERPETUAL")

# Window size in days.  7 days × 24 h = 168 records, well under the
# Deribit response cap (~744 records).
WINDOW_DAYS = 7

# Default date range: from the launch of the loader.  Deribit's first
# BTC-PERPETUAL funding event was in 2019-06 -- earlier queries return
# an empty list and are harmless.
DEFAULT_START = datetime(2019, 1, 1, tzinfo=timezone.utc)

# Backoff schedule (seconds) for retryable failures.
BACKOFF_SCHEDULE = (1, 2, 4, 8)

# Database connection defaults (matches docker-compose.yml).
DB_DEFAULTS = {
    "host": "localhost",
    "port": 5432,
    "user": "postgres",
    "password": "postgres",
    "dbname": "funding_rates",
}

logger = logging.getLogger("load_deribit")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _ms(dt: datetime) -> int:
    """Convert a timezone-aware ``datetime`` to a Unix epoch in milliseconds."""
    if dt.tzinfo is None:
        raise ValueError("datetime must be timezone-aware")
    return int(dt.timestamp() * 1000)


def _iso(ms: int) -> str:
    """Render a millisecond epoch as an ISO-8601 UTC string (no microseconds)."""
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).strftime(
        "%Y-%m-%d %H:%M:%S UTC"
    )


def _fetch_window(
    session: requests.Session,
    instrument: str,
    start_ms: int,
    end_ms: int,
    *,
    timeout: int = 30,
) -> list[dict[str, Any]]:
    """Fetch a single weekly window of funding-rate history.

    Implements exponential backoff on transient errors.  Returns the
    list of records on success, raises ``RuntimeError`` if all retries
    are exhausted.
    """
    body = {
        "jsonrpc": "2.0",
        "method": "public/get_funding_rate_history",
        "params": {
            "instrument_name": instrument,
            "start_timestamp": start_ms,
            "end_timestamp": end_ms,
        },
        "id": 1,
    }
    last_error: Optional[str] = None
    for attempt, sleep_s in enumerate((0.0,) + BACKOFF_SCHEDULE):
        if sleep_s:
            logger.debug("Sleeping %.1fs before retry", sleep_s)
            time.sleep(sleep_s)
        try:
            resp = session.post(DERIBIT_URL, json=body, timeout=timeout)
        except requests.RequestException as exc:
            last_error = f"network error: {exc}"
            logger.warning(
                "Window %s-%s attempt %d failed: %s",
                _iso(start_ms),
                _iso(end_ms),
                attempt + 1,
                last_error,
            )
            continue

        # Rate-limit / transient HTTP error -> back off and retry.
        if resp.status_code in (429, 500, 502, 503, 504):
            last_error = f"HTTP {resp.status_code}: {resp.text[:200]}"
            logger.warning(
                "Window %s-%s attempt %d rate-limited/transient: %s",
                _iso(start_ms),
                _iso(end_ms),
                attempt + 1,
                last_error,
            )
            continue

        if resp.status_code != 200:
            raise RuntimeError(
                f"Deribit HTTP {resp.status_code} for {instrument} "
                f"{_iso(start_ms)} -> {_iso(end_ms)}: {resp.text[:300]}"
            )

        payload = resp.json()
        if "error" in payload:
            last_error = f"JSON-RPC error: {payload['error']}"
            logger.warning(
                "Window %s-%s attempt %d JSON-RPC error: %s",
                _iso(start_ms),
                _iso(end_ms),
                attempt + 1,
                last_error,
            )
            continue

        return payload.get("result", []) or []

    raise RuntimeError(
        f"Exhausted retries for {instrument} {_iso(start_ms)} -> "
        f"{_iso(end_ms)}: {last_error}"
    )


def _record_to_row(rec: dict[str, Any], instrument: str) -> tuple:
    """Map a single API record to a tuple for ``raw.funding_deribit``.

    The Deribit response does not include ``mark_price``; we store NULL
    for that column.
    """
    ts = datetime.fromtimestamp(rec["timestamp"] / 1000, tz=timezone.utc)
    return (
        ts,
        instrument,
        rec.get("interest_8h"),
        rec.get("interest_1h"),
        None,  # mark_price -- not present in API response
        rec.get("index_price"),
    )


# ---------------------------------------------------------------------------
# Loader
# ---------------------------------------------------------------------------


def load_instrument(
    instrument: str,
    start: datetime,
    end: datetime,
    *,
    conn_factory=psycopg2.connect,
    session_factory=requests.Session,
) -> dict[str, int]:
    """Truncate-and-reload all funding-rate history for one instrument.

    Parameters
    ----------
    instrument:
        Deribit instrument name (e.g. ``"BTC-PERPETUAL"``).
    start, end:
        Timezone-aware datetimes bounding the history window.
    conn_factory, session_factory:
        Factories used to obtain a DB connection and HTTP session.
        Overridable in tests.

    Returns
    -------
    dict
        ``{"windows": <n>, "rows": <n>}`` describing the run.
    """
    if start.tzinfo is None or end.tzinfo is None:
        raise ValueError("start and end must be timezone-aware")
    if start >= end:
        raise ValueError("start must be < end")

    start_ms = _ms(start)
    end_ms = _ms(end)
    window_ms = WINDOW_DAYS * 86_400_000

    conn = conn_factory(**DB_DEFAULTS)
    try:
        with conn.cursor() as cur:
            # Idempotency: drop any existing rows for this instrument,
            # then re-insert.  Done in a single transaction so a partial
            # failure cannot leave the table half-loaded.
            cur.execute(
                "DELETE FROM raw.funding_deribit WHERE instrument_name = %s",
                (instrument,),
            )
            deleted = cur.rowcount
            if deleted:
                logger.info(
                    "Truncated %d existing rows for %s", deleted, instrument
                )

        session = session_factory()
        total_rows = 0
        windows = 0
        cursor_ms = start_ms
        # Pre-compute total number of windows for progress logging.
        total_windows = max(1, -(-(end_ms - start_ms) // window_ms))
        window_idx = 0

        try:
            with conn.cursor() as cur:
                while cursor_ms < end_ms:
                    chunk_end_ms = min(cursor_ms + window_ms, end_ms)
                    window_idx += 1
                    records = _fetch_window(
                        session, instrument, cursor_ms, chunk_end_ms
                    )
                    windows += 1
                    n = len(records)
                    total_rows += n
                    logger.info(
                        "Week %d/%d: %s to %s: %d rows",
                        window_idx,
                        total_windows,
                        _iso(cursor_ms),
                        _iso(chunk_end_ms),
                        n,
                    )
                    if n:
                        psycopg2.extras.execute_values(
                            cur,
                            """
                            INSERT INTO raw.funding_deribit
                                (ts, instrument_name, interest_8h, interest_1h,
                                 mark_price, index_price)
                            VALUES %s
                            """,
                            [_record_to_row(r, instrument) for r in records],
                            page_size=500,
                        )
                    conn.commit()
                    cursor_ms = chunk_end_ms
        finally:
            session.close()
    finally:
        conn.close()

    return {"windows": windows, "rows": total_rows}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Load Deribit perpetual funding-rate history into Postgres."
    )
    parser.add_argument(
        "--instruments",
        nargs="+",
        default=list(INSTRUMENTS),
        help="Instruments to load (default: BTC-PERPETUAL ETH-PERPETUAL).",
    )
    parser.add_argument(
        "--start",
        default=DEFAULT_START.strftime("%Y-%m-%d"),
        help="Start date (UTC, YYYY-MM-DD). Default: 2019-01-01.",
    )
    parser.add_argument(
        "--end",
        default=datetime.now(tz=timezone.utc).strftime("%Y-%m-%d"),
        help="End date (UTC, YYYY-MM-DD). Default: today.",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=("DEBUG", "INFO", "WARNING", "ERROR"),
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(asctime)s %(levelname)-7s %(name)s: %(message)s",
    )

    start = datetime.fromisoformat(args.start).replace(tzinfo=timezone.utc)
    end = datetime.fromisoformat(args.end).replace(tzinfo=timezone.utc)
    logger.info(
        "Loading Deribit funding history: %s -> %s, instruments=%s",
        start.date().isoformat(),
        end.date().isoformat(),
        args.instruments,
    )

    summary: dict[str, dict[str, int]] = {}
    for instrument in args.instruments:
        logger.info("=== %s ===", instrument)
        summary[instrument] = load_instrument(instrument, start, end)

    logger.info("Summary: %s", json.dumps(summary))
    return 0


if __name__ == "__main__":
    sys.exit(main())
