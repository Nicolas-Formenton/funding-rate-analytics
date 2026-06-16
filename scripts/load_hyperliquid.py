"""
Hyperliquid funding-rate ingestion (raw.funding_hyperliquid).

Pulls ``fundingHistory`` for BTC, ETH, and SOL directly from the public
Hyperliquid ``/info`` endpoint, downsamples any sub-hourly duplicates to a
single hourly observation per (coin, hour-bucket), and writes the result into
``raw.funding_hyperliquid`` with truncate+reload per symbol for idempotency.

Hyperliquid natively charges funding every hour and the API returns records
at ~1h intervals.  The endpoint, however, caps the response at 500 records
per call, so we paginate forward in 20-day windows from the earliest known
funding observation (2023-05-12 00:00 UTC) up to "now".

Schema target (from ``schemas/01_raw.sql``):
    raw.funding_hyperliquid(
        id, ts TIMESTAMPTZ, coin VARCHAR(10),
        funding_rate NUMERIC(12,8), funding_velocity NUMERIC(14,6),
        mark_price NUMERIC(18,4), open_interest NUMERIC(18,4)
    )

Usage:
    # Full load (BTC + ETH + SOL)
    python3 scripts/load_hyperliquid.py

    # One symbol only (e.g. dry-run / validation)
    python3 scripts/load_hyperliquid.py --coins BTC
"""
from __future__ import annotations

import argparse
import logging
import os
import sys
import time
from datetime import datetime, timezone
from typing import Any, Iterable

import psycopg2
import psycopg2.extras
import requests

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

#: Public Hyperliquid info endpoint (no auth required for public data).
HYPERLIQUID_INFO_URL = "https://api.hyperliquid.xyz/info"

#: Symbols we backfill.  Core perps with the longest history.
DEFAULT_COINS: tuple[str, ...] = ("BTC", "ETH", "SOL")

#: Earliest observed funding event on Hyperliquid (2023-05-12 00:00:00 UTC).
#: ``fundingHistory`` returns an empty array before this point, so we start
#: pagination from here to keep the loop bounded.
EARLIEST_HL_MS: int = 1683849600000  # 2023-05-12T00:00:00Z

#: Hyperliquid caps the response at 500 records per call.  20 days × 24 h
#: = 480 records, so a 20-day window fits comfortably and is still wide
#: enough to keep the number of HTTP calls small (~55 for ~3 years of data).
WINDOW_MS: int = 20 * 24 * 60 * 60 * 1000  # 20 days in ms

#: HTTP request timeout (seconds).
REQUEST_TIMEOUT_S: float = 30.0

#: Max retries with exponential backoff for transient HTTP failures.
MAX_RETRIES: int = 4

#: Small pause between successful calls to be polite to the public endpoint.
INTER_CALL_SLEEP_S: float = 0.15

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("load_hyperliquid")


# ---------------------------------------------------------------------------
# Hyperliquid API
# ---------------------------------------------------------------------------


def _post_funding_history(
    coin: str, start_ms: int, end_ms: int
) -> list[dict[str, Any]]:
    """POST a single ``fundingHistory`` window to Hyperliquid.

    Retries on transient HTTP errors with exponential backoff.  Returns an
    empty list on any non-recoverable failure (logged at WARNING).
    """
    body = {
        "type": "fundingHistory",
        "coin": coin,
        "startTime": start_ms,
        "endTime": end_ms,
    }

    last_err: Exception | None = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = requests.post(
                HYPERLIQUID_INFO_URL,
                json=body,
                timeout=REQUEST_TIMEOUT_S,
            )
            if resp.status_code != 200:
                raise RuntimeError(
                    f"HTTP {resp.status_code}: {resp.text[:200]}"
                )
            data = resp.json()
            if not isinstance(data, list):
                raise RuntimeError(
                    f"Unexpected payload type: {type(data).__name__}"
                )
            return data
        except Exception as exc:  # noqa: BLE001 — surface as warning + backoff
            last_err = exc
            backoff = min(2 ** attempt, 8)
            log.warning(
                "HL %s window [%s, %s] attempt %d/%d failed: %s. "
                "Sleeping %ds before retry.",
                coin, start_ms, end_ms, attempt, MAX_RETRIES, exc, backoff,
            )
            time.sleep(backoff)

    log.error(
        "HL %s window [%s, %s] exhausted %d retries; last error: %s",
        coin, start_ms, end_ms, MAX_RETRIES, last_err,
    )
    return []


def fetch_coin_history(coin: str) -> list[dict[str, Any]]:
    """Fetch the full funding history for one coin via forward pagination.

    Returns the raw list of records as returned by the API.  Empty
    sub-hourly duplicates are NOT removed here — call
    :func:`downsample_to_hourly` on the result.
    """
    all_records: list[dict[str, Any]] = []
    chunk_start_ms = EARLIEST_HL_MS
    end_ms = int(time.time() * 1000)

    while chunk_start_ms < end_ms:
        chunk_end_ms = min(chunk_start_ms + WINDOW_MS, end_ms)
        records = _post_funding_history(coin, chunk_start_ms, chunk_end_ms)
        n = len(records)
        log.info(
            "HL %s window %s -> %s : %d records",
            coin,
            _ms_to_iso(chunk_start_ms),
            _ms_to_iso(chunk_end_ms),
            n,
        )

        if n == 0:
            # Past the trailing edge of available data — stop pagination.
            log.info("HL %s : empty window reached, stopping.", coin)
            break

        all_records.extend(records)

        if n < 500:
            # Short window → likely near the trailing edge; one more
            # forward step to be safe, then stop.
            if chunk_end_ms >= end_ms:
                log.info("HL %s : reached 'now', stopping.", coin)
                break
            # Advance by the actual last observation to avoid infinite loop.
            chunk_start_ms = max(int(r["time"]) for r in records) + 1
        else:
            # Full window: step exactly WINDOW_MS forward.
            chunk_start_ms = chunk_end_ms

        time.sleep(INTER_CALL_SLEEP_S)

    return all_records


# ---------------------------------------------------------------------------
# Downsampling
# ---------------------------------------------------------------------------


def downsample_to_hourly(
    records: Iterable[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Collapse sub-hourly duplicates to one record per (coin, hour bucket).

    The Hyperliquid API is already at ~1h granularity, but each record
    carries ms precision and on rare occasions a single hour can hold more
    than one observation (e.g. after a re-snap).  We keep the record with
    the largest ``time`` within each hour bucket — that is the freshest
    observation, which is what most downstream annualisation logic wants.

    Returns a new list of records with ``time`` rewritten to the start of
    the hour (so the same record is idempotent if re-inserted).
    """
    HOUR_MS = 60 * 60 * 1000
    latest_per_bucket: dict[tuple[str, int], dict[str, Any]] = {}

    for rec in records:
        ts_ms = int(rec["time"])
        coin = rec.get("coin", "UNKNOWN")
        bucket = (ts_ms // HOUR_MS) * HOUR_MS
        key = (coin, bucket)

        existing = latest_per_bucket.get(key)
        if existing is None or int(existing["time"]) < ts_ms:
            # Clone the record and normalise time → start of hour bucket.
            new_rec = dict(rec)
            new_rec["time"] = bucket
            latest_per_bucket[key] = new_rec

    # Sort by (coin, time) for stable, diff-friendly output.
    return sorted(
        latest_per_bucket.values(),
        key=lambda r: (r.get("coin", ""), int(r["time"])),
    )


# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------


def get_dsn() -> str:
    """Build a libpq DSN from environment with sensible local defaults."""
    return os.environ.get(
        "FUNDING_RATES_DSN",
        "host=localhost port=5432 user=postgres password=postgres dbname=funding_rates",
    )


def connect():
    """Open a psycopg2 connection.  Raises on failure."""
    return psycopg2.connect(get_dsn())


def truncate_symbol(cur, coin: str) -> None:
    """Remove all existing rows for ``coin`` (idempotent reload)."""
    cur.execute(
        "DELETE FROM raw.funding_hyperliquid WHERE coin = %s", (coin,)
    )


def bulk_insert(cur, rows: list[tuple]) -> None:
    """Batch-insert rows with ``execute_values`` for speed."""
    psycopg2.extras.execute_values(
        cur,
        """
        INSERT INTO raw.funding_hyperliquid
            (ts, coin, funding_rate, funding_velocity, mark_price, open_interest)
        VALUES %s
        """,
        rows,
        page_size=500,
    )


def row_from_record(rec: dict[str, Any]) -> tuple:
    """Map a downsampled API record to the table's insert tuple.

    The Hyperliquid payload has no direct ``mark_price`` or ``open_interest``
    fields, so those columns stay NULL.  ``premium`` is kept out of the
    table by design; only the funding rate (and a derived velocity) are
    persisted here.
    """
    ts = datetime.fromtimestamp(int(rec["time"]) / 1000, tz=timezone.utc)
    coin = rec.get("coin", "UNKNOWN")
    funding_rate = _to_decimal_str(rec.get("fundingRate"))
    # No first-class funding_velocity field in the payload; leave NULL.
    return (ts, coin, funding_rate, None, None, None)


def load_coin(coin: str, conn) -> int:
    """Fetch → downsample → truncate+insert for a single coin.

    Returns the number of rows inserted.
    """
    log.info("=== %s : starting fetch ===", coin)
    raw = fetch_coin_history(coin)
    log.info("=== %s : fetched %d raw records ===", coin, len(raw))

    if not raw:
        log.warning("=== %s : no records returned; nothing to insert. ===", coin)
        return 0

    hourly = downsample_to_hourly(raw)
    log.info(
        "=== %s : downsampled to %d hourly rows (raw=%d) ===",
        coin, len(hourly), len(raw),
    )

    rows = [row_from_record(r) for r in hourly]

    with conn:  # transactional
        with conn.cursor() as cur:
            truncate_symbol(cur, coin)
            bulk_insert(cur, rows)
    log.info("=== %s : inserted %d rows (truncate+reload) ===", coin, len(rows))
    return len(rows)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--coins",
        nargs="+",
        default=list(DEFAULT_COINS),
        metavar="COIN",
        help=f"Coins to load (default: {' '.join(DEFAULT_COINS)})",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    coins = [c.upper() for c in args.coins]

    log.info("Hyperliquid ingestion starting for coins=%s", coins)
    try:
        conn = connect()
    except Exception as exc:  # noqa: BLE001
        log.error("Could not connect to Postgres: %s", exc)
        return 2

    totals: dict[str, int] = {}
    try:
        for coin in coins:
            totals[coin] = load_coin(coin, conn)
    finally:
        conn.close()

    grand_total = sum(totals.values())
    log.info(
        "Done. inserted per coin: %s | grand total: %d",
        totals, grand_total,
    )
    return 0 if grand_total > 0 else 1


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _ms_to_iso(ms: int) -> str:
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )


def _to_decimal_str(v: Any) -> str | None:
    """Cast a Hyperliquid numeric value to a string for NUMERIC(12,8) bind."""
    if v is None:
        return None
    try:
        return str(v)
    except (TypeError, ValueError):
        return None


if __name__ == "__main__":
    sys.exit(main())
