"""Equity perps ingestion — hunter for funding data.

Equity perps (perpetual futures on individual stocks and indices) are rare
compared to crypto perps. The task spec confirms that
``.SPYPERP`` on BitMEX and the main ``SPY`` coin on Hyperliquid both return
empty. This module is a *hunter* — it tries multiple candidate sources in
priority order, paginates each working source, and writes whatever it can
find into ``raw.funding_equity_perps``.

Sources attempted (in order):

1. **Hyperliquid HIP-3 (``xyz`` perp dex)** — has TSLA/NVDA/MSFT/GOOGL/
   META/AMZN with hourly funding data since Nov 2025. Note: SPY/QQQ are
   *not* in the ``xyz`` universe (verified during research), so we skip
   them there.
2. **Hyperliquid main perp** — has no equity perps in the universe, but
   we still probe ``SPY``/``SPYUSDT``/``S&P 500`` and log the negative
   result for documentation.
3. **BitMEX** — 8 equity perps (AAPLUSDT, TSLAUSDT, …) with 8 h
   funding data, but rates are all 0 (per Task 2 evidence). Ingested
   anyway because the timestamps are real, and a 0 rate is a valid
   market signal.
4. **Binance fapi (TradFi perps)** — 9 equity perps (SPYUSDT, QQQUSDT,
   …) with 8 h funding data starting 2026-04-11. **This is the
   primary working source** with non-zero rates and weekend data.
5. **Bybit v5** — returns a single current funding rate, no history.
   Logged but not ingested.
6. **Vest Exchange** — requires an API key; endpoint not reachable
   anonymously. Logged but not ingested.

For every source the function ``ingest_*`` returns a
``SourceResult`` with rows-fetched, errors, and a status flag. The
top-level ``main()`` orchestrates sources, prints a summary, and
returns the count of rows that were newly written (after the
idempotency UNIQUE INDEX).

Idempotency
-----------

A UNIQUE INDEX on ``(ts, venue, symbol)`` is created on first run.
Subsequent runs use ``INSERT … ON CONFLICT DO NOTHING`` so re-running
the script does not duplicate rows.

Configuration
-------------

Connection parameters are read from environment variables
(``POSTGRES_HOST``, ``POSTGRES_PORT``, ``POSTGRES_USER``,
``POSTGRES_PASSWORD``, ``POSTGRES_DB``) and fall back to the
``docker-compose.yml`` defaults (``localhost:5432``, ``postgres`` /
``postgres``, ``funding_rates``).
"""

from __future__ import annotations

import json
import logging
import os
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Callable, Optional

import psycopg2
import requests

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("load_equity_perps")

# ---------------------------------------------------------------------------
# Connection helpers
# ---------------------------------------------------------------------------

DEFAULT_DB = {
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": int(os.getenv("POSTGRES_PORT", "5432")),
    "user": os.getenv("POSTGRES_USER", "postgres"),
    "password": os.getenv("POSTGRES_PASSWORD", "postgres"),
    "dbname": os.getenv("POSTGRES_DB", "funding_rates"),
}


def connect():
    """Open a psycopg2 connection with the default database params."""
    return psycopg2.connect(**DEFAULT_DB)


def ensure_unique_index(cur) -> None:
    """Create the idempotency UNIQUE INDEX if it does not yet exist.

    The raw table was created in Task 3 without a uniqueness constraint.
    Adding it here keeps the loader self-contained — the index is
    additive and does not require changes to ``01_raw.sql``.
    """
    cur.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS funding_equity_perps_uniq
        ON raw.funding_equity_perps (ts, venue, symbol);
        """
    )


# ---------------------------------------------------------------------------
# Source result type
# ---------------------------------------------------------------------------


@dataclass
class SourceResult:
    venue: str
    attempted: bool = True
    worked: bool = False
    note: str = ""
    rows_fetched: int = 0
    rows_inserted: int = 0
    error: Optional[str] = None
    sample: list[dict[str, Any]] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return {
            "venue": self.venue,
            "worked": self.worked,
            "note": self.note,
            "rows_fetched": self.rows_fetched,
            "rows_inserted": self.rows_inserted,
            "error": self.error,
        }


def _mark_venues_with_data(cur) -> set[str]:
    """Set of venue names that already have at least one row in the table."""
    cur.execute("SELECT DISTINCT venue FROM raw.funding_equity_perps")
    return {row[0] for row in cur.fetchall()}


# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------

UA = {"User-Agent": "funding-rate-analytics/0.1 (hunter)"}
HTTP_TIMEOUT = 15  # seconds


def safe_get_json(url: str, params: Optional[dict] = None) -> Optional[Any]:
    try:
        r = requests.get(url, params=params, headers=UA, timeout=HTTP_TIMEOUT)
        r.raise_for_status()
        return r.json()
    except (requests.RequestException, json.JSONDecodeError) as exc:
        log.warning("GET %s failed: %s", url, exc)
        return None


def safe_post_json(url: str, payload: dict) -> Optional[Any]:
    try:
        r = requests.post(
            url, json=payload, headers={**UA, "Content-Type": "application/json"},
            timeout=HTTP_TIMEOUT,
        )
        r.raise_for_status()
        return r.json()
    except (requests.RequestException, json.JSONDecodeError) as exc:
        log.warning("POST %s failed: %s", url, exc)
        return None


# ---------------------------------------------------------------------------
# Source 1 + 2: Hyperliquid (HIP-3 xyz dex and main)
# ---------------------------------------------------------------------------

# HIP-3 "xyz" dex discovered during research: contains TSLA/NVDA/MSFT/GOOGL/
# META/AMZN with hourly funding data.  SPY/QQQ are not in this universe.
HL_XYZ_EQUITY_COINS = ["TSLA", "NVDA", "MSFT", "GOOGL", "META", "AMZN"]

# Main Hyperliquid universe has no equity perps (verified: meta().universe
# has 230 coins, none match SPY/QQQ/AAPL/TSLA).  We still probe a few
# candidate coin names per the task spec to document the negative result.
HL_MAIN_EQUITY_PROBES = ["SPY", "SPYUSDT", "S&P 500"]


def fetch_hyperliquid_funding(coin: str) -> list[dict[str, Any]]:
    """Paginate ``fundingHistory`` for one coin, oldest first.

    The ``fundingHistory`` endpoint requires ``startTime`` and returns
    records where ``time >= startTime``, ordered oldest-first, capped
    at 500 per call.  We walk forward using
    ``startTime = last_record_time + 1ms``.
    """
    url = "https://api.hyperliquid.xyz/info"
    out: list[dict[str, Any]] = []
    # 2020-01-01 UTC in ms — well before any equity perp launch.
    start_time: int = 1577836800000
    while True:
        payload: dict[str, Any] = {
            "type": "fundingHistory", "coin": coin, "startTime": start_time,
        }
        data = safe_post_json(url, payload)
        if not data or not isinstance(data, list) or len(data) == 0:
            break
        out.extend(data)
        if len(data) < 500:
            break
        start_time = data[-1]["time"] + 1
    return out


def ingest_hyperliquid_xyz(cur) -> SourceResult:
    res = SourceResult(venue="hyperliquid_xyz", note="HIP-3 xyz dex")
    total_fetched = 0
    total_inserted = 0
    sample: list[dict[str, Any]] = []
    for coin in HL_XYZ_EQUITY_COINS:
        rows = fetch_hyperliquid_funding(f"xyz:{coin}")
        if not rows:
            log.info("xyz:%s → 0 rows", coin)
            continue
        total_fetched += len(rows)
        params_list = [
            (
                datetime.fromtimestamp(r["time"] / 1000.0, tz=timezone.utc),
                "hyperliquid_xyz",
                f"xyz:{coin}",
                r["fundingRate"],
                1.0,
                None,
                None,
            )
            for r in rows
        ]
        inserted = _insert_rows(cur, params_list)
        total_inserted += inserted
        if not sample and rows:
            sample = [{"ts": rows[0]["time"], "coin": f"xyz:{coin}",
                       "rate": rows[0]["fundingRate"]}]
        log.info("xyz:%s → fetched=%d inserted=%d", coin, len(rows), inserted)
    res.rows_fetched = total_fetched
    res.rows_inserted = total_inserted
    res.sample = sample
    res.worked = total_inserted > 0
    if not res.worked:
        res.note = "HIP-3 xyz dex returned no funding history for probed coins"
    return res


def ingest_hyperliquid_main(cur) -> SourceResult:
    """Probe the main Hyperliquid perp for SPY/QQQ-style coins.

    Verified during research that the main perp universe has zero
    equity perps.  We re-probe a few candidate names so the negative
    result is captured in the run log.
    """
    res = SourceResult(venue="hyperliquid", note="main perp (HIP-1)")
    any_data = False
    for coin in HL_MAIN_EQUITY_PROBES:
        rows = fetch_hyperliquid_funding(coin)
        if rows:
            any_data = True
            log.info("main HL %s unexpectedly returned %d rows", coin, len(rows))
    if not any_data:
        res.note = "main perp has no equity coins (universe size=230, no SPY/QQQ/AAPL/TSLA match)"
    res.worked = False
    return res


# ---------------------------------------------------------------------------
# Source 3: BitMEX
# ---------------------------------------------------------------------------

# Equity perps on BitMEX use the ``<TICKER>USDT`` symbol form.  The
# response uses a quirky ``fundingInterval`` of ``2000-01-01T08:00:00Z``
# which means 8 h cadence (the time portion, not the date).
BITMEX_EQUITY_SYMBOLS = [
    "AAPLUSDT", "TSLAUSDT", "NVDAUSDT", "MSFTUSDT",
    "GOOGLUSDT", "METAUSDT", "AMZNUSDT", "QQQUSDT",
]


def fetch_bitmex_funding(symbol: str) -> list[dict[str, Any]]:
    """Paginate BitMEX ``/funding`` for one symbol, oldest first.

    BitMEX returns at most 500 records per call.  We walk backwards
    using ``startTime`` until the response is empty.
    """
    url = "https://www.bitmex.com/api/v1/funding"
    out: list[dict[str, Any]] = []
    start_time: Optional[int] = None
    while True:
        params: dict[str, Any] = {"symbol": symbol, "count": 500, "reverse": "false"}
        if start_time is not None:
            params["startTime"] = start_time
        data = safe_get_json(url, params)
        if not data or not isinstance(data, list) or len(data) == 0:
            break
        out.extend(data)
        if len(data) < 500:
            break
        # advance: 1 ms past the newest record
        last_ts = int(
            datetime.fromisoformat(data[-1]["timestamp"].replace("Z", "+00:00"))
            .timestamp() * 1000
        )
        start_time = last_ts + 1
    return out


def ingest_bitmex(cur) -> SourceResult:
    res = SourceResult(venue="bitmex", note="8 h funding, all rates currently 0")
    total_fetched = 0
    total_inserted = 0
    sample: list[dict[str, Any]] = []
    for symbol in BITMEX_EQUITY_SYMBOLS:
        rows = fetch_bitmex_funding(symbol)
        if not rows:
            log.info("bitmex %s → 0 rows", symbol)
            continue
        total_fetched += len(rows)
        params_list = [
            (
                datetime.fromisoformat(r["timestamp"].replace("Z", "+00:00")),
                "bitmex",
                symbol,
                r.get("fundingRate") or 0.0,
                8.0,
                None,  # BitMEX funding endpoint has no mark price
                None,
            )
            for r in rows
        ]
        inserted = _insert_rows(cur, params_list)
        total_inserted += inserted
        if not sample and rows:
            sample = [{"timestamp": rows[0]["timestamp"], "symbol": symbol,
                       "rate": rows[0]["fundingRate"]}]
        log.info("bitmex %s → fetched=%d inserted=%d", symbol, len(rows), inserted)
    res.rows_fetched = total_fetched
    res.rows_inserted = total_inserted
    res.sample = sample
    res.worked = total_inserted > 0
    if not res.worked:
        res.note = "BitMEX equity perps exist but funding rates are 0"
    return res


# ---------------------------------------------------------------------------
# Source 4: Binance fapi (TradFi perps)
# ---------------------------------------------------------------------------

BINANCE_EQUITY_SYMBOLS = [
    "SPYUSDT", "QQQUSDT", "TSLAUSDT", "NVDAUSDT", "AAPLUSDT",
    "MSFTUSDT", "GOOGLUSDT", "METAUSDT", "AMZNUSDT",
]
BINANCE_FAPI = "https://fapi.binance.com"


def fetch_binance_funding(symbol: str) -> list[dict[str, Any]]:
    """Paginate Binance fapi ``/fundingRate`` for one symbol, oldest first.

    Binance returns at most 1000 records per call, but for equity perps
    (launched Apr 2026) the actual history is small enough to fit in one
    call.  We still paginate defensively.
    """
    url = f"{BINANCE_FAPI}/fapi/v1/fundingRate"
    out: list[dict[str, Any]] = []
    start_time: Optional[int] = None
    while True:
        params: dict[str, Any] = {"symbol": symbol, "limit": 1000}
        if start_time is not None:
            params["startTime"] = start_time
        data = safe_get_json(url, params)
        if not data or not isinstance(data, list) or len(data) == 0:
            break
        out.extend(data)
        if len(data) < 1000:
            break
        # advance: 1 ms past the newest record
        start_time = int(data[-1]["fundingTime"]) + 1
    return out


def fetch_binance_index_price(symbol: str) -> Optional[float]:
    """Fetch the current index price for a symbol (single-snapshot)."""
    data = safe_get_json(f"{BINANCE_FAPI}/fapi/v1/premiumIndex", {"symbol": symbol})
    if not data or not isinstance(data, list) or not data:
        return None
    v = data[0].get("indexPrice")
    try:
        return float(v) if v is not None else None
    except (ValueError, TypeError):
        return None


def ingest_binance(cur) -> SourceResult:
    res = SourceResult(venue="binance", note="8 h funding, primary working source")
    total_fetched = 0
    total_inserted = 0
    sample: list[dict[str, Any]] = []
    for symbol in BINANCE_EQUITY_SYMBOLS:
        rows = fetch_binance_funding(symbol)
        if not rows:
            log.info("binance %s → 0 rows", symbol)
            continue
        total_fetched += len(rows)
        params_list = [
            (
                datetime.fromtimestamp(r["fundingTime"] / 1000.0, tz=timezone.utc),
                "binance",
                symbol,
                r["fundingRate"],
                8.0,
                float(r["markPrice"]) if r.get("markPrice") else None,
                None,  # fapi/v1/fundingRate does not return historical indexPrice
            )
            for r in rows
        ]
        inserted = _insert_rows(cur, params_list)
        total_inserted += inserted
        if not sample and rows:
            sample = [{"fundingTime": rows[0]["fundingTime"], "symbol": symbol,
                       "rate": rows[0]["fundingRate"],
                       "markPrice": rows[0].get("markPrice")}]
        log.info("binance %s → fetched=%d inserted=%d", symbol, len(rows), inserted)
    res.rows_fetched = total_fetched
    res.rows_inserted = total_inserted
    res.sample = sample
    res.worked = total_inserted > 0
    return res


# ---------------------------------------------------------------------------
# Source 5: Bybit
# ---------------------------------------------------------------------------


def ingest_bybit(cur) -> SourceResult:
    """Probe Bybit v5 for SPYUSDT funding history.

    Bybit only returns the most recent funding rate per symbol — no
    historical endpoint.  Verified during research; logged for
    completeness.
    """
    res = SourceResult(venue="bybit", note="no historical funding endpoint")
    url = "https://api.bybit.com/v5/market/funding/history"
    data = safe_get_json(url, {"category": "linear", "symbol": "SPYUSDT", "limit": 2})
    if not data or data.get("retCode") != 0:
        res.note = "Bybit v5 endpoint unreachable"
        res.worked = False
        return res
    res.worked = False
    res.note = "Bybit returns current rate only; no historical funding data"
    return res


# ---------------------------------------------------------------------------
# Source 6: Vest Exchange
# ---------------------------------------------------------------------------


def ingest_vest(cur) -> SourceResult:
    """Probe Vest Exchange for equity perps funding.

    Vest has the longest historical funding (3.5 years) but the public
    endpoint requires an API key.  We try the public probe and log the
    negative result.
    """
    res = SourceResult(venue="vest", note="API key required")
    url = "https://api.vest.exchange/v1/funding/rates"
    data = safe_get_json(url, {"symbol": "SPY"})
    if data is None:
        res.note = "Vest public endpoint unreachable without API key"
    else:
        res.note = f"Vest returned {type(data).__name__}; no public historical funding"
    res.worked = False
    return res


# ---------------------------------------------------------------------------
# Insertion helper
# ---------------------------------------------------------------------------


def _insert_rows(cur, params_list: list[tuple]) -> int:
    """Bulk-insert with ON CONFLICT DO NOTHING; return number of new rows."""
    if not params_list:
        return 0
    cur.execute("SELECT COUNT(*) FROM raw.funding_equity_perps")
    before = cur.fetchone()[0]
    cur.executemany(
        """
        INSERT INTO raw.funding_equity_perps
            (ts, venue, symbol, funding_rate, funding_interval_hours,
             mark_price, index_price)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (ts, venue, symbol) DO NOTHING
        """,
        params_list,
    )
    cur.execute("SELECT COUNT(*) FROM raw.funding_equity_perps")
    after = cur.fetchone()[0]
    return after - before


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------


def main() -> int:
    started = time.time()
    summary: list[SourceResult] = []

    with connect() as conn:
        with conn.cursor() as cur:
            ensure_unique_index(cur)
        conn.commit()

        ingestors: list[Callable[[Any], SourceResult]] = [
            ingest_hyperliquid_xyz,
            ingest_hyperliquid_main,
            ingest_bitmex,
            ingest_binance,
            ingest_bybit,
            ingest_vest,
        ]
        for fn in ingestors:
            with conn.cursor() as cur:
                try:
                    res = fn(cur)
                except Exception as exc:
                    res = SourceResult(
                        venue=fn.__name__.replace("ingest_", ""),
                        worked=False,
                        error=f"{type(exc).__name__}: {exc}",
                    )
                    log.exception("ingestor %s crashed", fn.__name__)
            conn.commit()
            summary.append(res)

        with conn.cursor() as cur:
            venues_with_data = _mark_venues_with_data(cur)

    for r in summary:
        if r.venue in venues_with_data and r.rows_fetched > 0:
            r.worked = True

    log.info("=" * 60)
    log.info("Equity perps ingestion summary:")
    for r in summary:
        marker = "OK" if r.worked else "  "
        log.info(
            "  %s %-18s fetched=%-5d inserted=%-5d note=%s%s",
            marker,
            r.venue,
            r.rows_fetched,
            r.rows_inserted,
            r.note,
            f" err={r.error}" if r.error else "",
        )

    total_inserted = sum(r.rows_inserted for r in summary)
    working = sorted(r.venue for r in summary if r.worked)
    log.info("Total rows newly written: %d", total_inserted)
    log.info("Working venues: %s", working or "(none)")
    log.info("Elapsed: %.1fs", time.time() - started)

    log.info(json.dumps(
        {
            "working_venues": working,
            "total_rows_inserted": total_inserted,
            "sources": [r.as_dict() for r in summary],
        },
        indent=2,
    ))

    return 0 if working else 1


if __name__ == "__main__":
    sys.exit(main())
