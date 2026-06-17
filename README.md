# Historical Funding Rate Analytics — Crypto + Equity Perpetual Futures

End-to-end data analytics on **260,961 funding rate observations** from **5 perpetual futures venues** across crypto and equity markets, built with **PostgreSQL, dbt, and Deepnote**.

This portfolio showcases four interactive BI dashboards backed by a dbt data pipeline, plus a Hex research report testing hypotheses about funding rate behavior.

---

## Dashboards

| # | Dashboard | SQL Queries | Focus |
|---|-----------|-------------|-------|
| 1 | **Funding Rate Overview** | 12 | Rate trends by venue/symbol, top events, volatility, distribution |
| 2 | **Cross-Venue Spread Analysis** | 14 | Arbitrage detection, correlation matrix, spread over time |
| 3 | **Equity vs Crypto Perps** | 13 | Weekend oracle freeze, hourly patterns, regulatory comparison |
| 4 | **Annualized Yield Analysis** | 12 | Cumulative yield, risk-return, seasonality, negative funding |

> **Live dashboards**: [Deepnote project](https://deepnote.com/workspace/Exploratory-Analysis-fb5d0c52-59fc-4f39-950c-94709466c5d9/project/Funding-Rate-Analytics-ba935e29-1cf6-4f1d-ac3a-9218b41f71dd) — 4 interactive dashboards with Plotly charts
> **Research report**: Hex report URL (TBD)

---

## Data Pipeline Architecture

```
Binance data.vision (CSV, 2020-today)
Hyperliquid API (hourly, 2023-today)
Deribit API (8h, 2019-today)                    Deepnote        Hex
Equity Perps APIs (Binance/HL-xyz/BitMEX)          ↑               ↑
        │                                            │               │
        ├──────────────┬──────────────┬──────────────┤               │
        ↓              ↓              ↓              │               │
PostgreSQL `raw` schema (4 tables, 260,961 rows)    │               │
   ├── funding_binance (20,392)                     │               │
   ├── funding_hyperliquid (79,776)                  │               │
   ├── funding_deribit (124,970)                     │               │
   └── funding_equity_perps (35,823)                 │               │
        │                                            │               │
        ↓                                            │               │
dbt `staging` (1 view: stg_funding_events)          │               │
   └── Normalized annualized rates, asset_class      │               │
        │                                            │               │
        ↓                                            │               │
dbt `marts` (3 tables)                              │               │
   ├── mart_hourly_funding (260,956 rows)            │               │
   ├── mart_daily_funding (18,437 rows)              │               │
   └── mart_venue_comparison (11,273 rows)           │               │
        │                                            │               │
        ├────────────────────────────────────────────┤               │
        ↓                                            ↓               ↓
4 Deepnote Dashboards                          Hex Research Report
(51 SQL queries, Plotly charts)            (hypothesis testing, stats)
```

**Key tables & row counts** (live snapshot from PostgreSQL):

| Table | Rows |
|-------|------|
| `raw.funding_binance` | 20,392 |
| `raw.funding_hyperliquid` | 79,776 |
| `raw.funding_deribit` | 124,970 |
| `raw.funding_equity_perps` | 35,823 |
| `staging.stg_funding_events` | 260,961 |
| `marts.mart_hourly_funding` | 260,956 |
| `marts.mart_daily_funding` | 18,437 |
| `marts.mart_venue_comparison` | 11,273 |

**Asset coverage:**

| Asset Class | Venues | Symbols | Earliest | Latest |
|-------------|--------|---------|----------|--------|
| **Crypto** | 3 (binance, hyperliquid, deribit) | 6 | Apr 2019 | Jun 2026 |
| **Equity** | 3 (binance, hyperliquid_xyz, bitmex) | 15 | Nov 2025 | Jun 2026 |

---

## Tech Stack

- **PostgreSQL 16** — Docker container with 3 schemas: `raw`, `staging`, `marts`
- **dbt 1.12** — staging views (rate normalization) + 3 mart tables (hourly, daily, venue comparison)
- **Deepnote** — interactive BI dashboards with SQL blocks + Plotly visualizations + input filters
- **Hex** — published research report with SQL + Python statistical testing
- **Python 3** — ingestion scripts (Binance, Hyperliquid, Deribit, equity perps) + pytest
- **Docker Compose** — local PostgreSQL + PGAdmin

---

## Project Structure

```
.
├── dashboards/                      # Deepnote project (cloud) — see URL above
├── sql/                             # 51 native SQL queries, grouped by dashboard
│   ├── funding-rate-overview/       # 12 queries
│   ├── cross-venue-spread/          # 14 queries
│   ├── equity-vs-crypto-perps/      # 13 queries
│   └── annualized-yield/            # 12 queries
│   └── all_queries.sql              # concatenated mega file
├── dbt/
│   └── models/
│       ├── staging/
│       │   ├── stg_funding_events.sql   # UNION ALL + normalization
│       │   └── schema.yml               # tests
│       └── marts/
│           ├── mart_hourly_funding.sql
│           ├── mart_daily_funding.sql
│           ├── mart_venue_comparison.sql
│           └── schema.yml               # tests
├── scripts/                         # Ingestion scripts
│   ├── load_binance.py              # data.binance.vision → raw.funding_binance
│   ├── load_hyperliquid.py          # HL API → raw.funding_hyperliquid
│   ├── load_deribit.py              # Deribit JSON-RPC → raw.funding_deribit
│   ├── load_equity_perps.py         # 3 sources → raw.funding_equity_perps
│   └── push_to_supabase.py          # Local PG → Supabase for portfolio sharing
├── src/extracted/                   # Adapted from Delta Hedge (with attribution)
│   ├── rate_normalizer.py
│   ├── spread_calculator.py
│   └── apy_formula.py
├── data/
│   ├── raw/                         # Raw downloaded files (gitignored)
│   └── sample/                      # Sample data for repo portability (4 files)
├── schemas/                         # Reference DDL (raw, staging, marts)
├── docs/
│   ├── data-source-validation.md
│   ├── normalization-rules.md
│   └── supabase-setup.md
├── reports/
├── tests/                           # pytest — 7 test files
├── docker-compose.yml
├── requirements.txt
├── ACKNOWLEDGMENTS.md
├── LICENSE                          # MIT
└── README.md
```

---

## What the Numbers Mean

The PostgreSQL database and dbt models capture these key metrics:

- **260,961 funding events** across 5 venues and 21 symbols, spanning 7 years of crypto data + 8 months of equity perp data
- **Cross-venue arbitrage**: 4,686 of 11,273 daily comparisons show positive cross-venue spread. Funding rates are NOT uniform across exchanges
- **Weekend oracle freeze**: Equity perpetuals show fundamentally different funding behavior on weekends compared to crypto perpetuals (24/7 markets)
- **Annualized yields**: Funding rates as annualized percentages, allowing direct comparison across venues with different funding intervals (hourly, 8h, continuous)
- **Negative funding rates**: 60,860 events show negative average rates (bps). Short positions paying longs, common during bearish sentiment

---

## Equity Perps — A Separate Analytical Category

Equity perpetual futures are a **new asset class** (since Oct/Nov 2025), introduced by:

- **Hyperliquid HIP-3** (xyz. S&P 500, Nasdaq components: TSLA, NVDA, MSFT, GOOGL, META, AMZN)
- **Binance TradFi Perps** (SPYUSDT, QQQUSDT, AAPLUSDT, +6 more)
- **BitMEX Equity Perps** (listed Dec 2025, zero funding rates as of June 2026)

Unlike crypto perps (24/7 markets), equity perps exhibit a **weekend oracle freeze**. The spot index stops updating at Friday close, but the perp keeps trading on sentiment. This creates a unique funding rate dynamic that this project is among the first to analyze systematically.

---

## How to Run

```bash
# 1. Start PostgreSQL + PGAdmin
docker compose up -d

# 2. Install Python dependencies
pip3 install -r requirements.txt --break-system-packages

# 3. Load historical data (each script is idempotent)
python scripts/load_binance.py       # ~2 min
python scripts/load_hyperliquid.py    # ~3 min
python scripts/load_deribit.py        # ~2 min
python scripts/load_equity_perps.py   # ~2 min

# 4. Run dbt pipeline
cd dbt
dbt deps
dbt run      # ~1s, 4 models
dbt test     # 24 tests

# 5. Push to Supabase (for portfolio sharing)
# Set SUPABASE_URL env var first
python scripts/push_to_supabase.py

# 6. Open Deepnote dashboards and Hex report
# See dashboard URLs at top of this README
```

---

## Data Sources

| Venue | Source | Period | Symbols | Format |
|-------|--------|--------|---------|--------|
| **Binance** | data.binance.vision | Jan 2020 → present | BTCUSDT, ETHUSDT, SOLUSDT | CSV (monthly ZIP) |
| **Hyperliquid** | api.hyperliquid.xyz | May 2023 → present | BTC, ETH, SOL | JSON (REST) |
| **Deribit** | deribit.com API | Apr 2019 → present | BTC, ETH-PERPETUAL | JSON-RPC |
| **Hyperliquid xyz** (HIP-3) | api.hyperliquid.xyz | Nov 2025 → present | TSLA, NVDA, MSFT, GOOGL, META, AMZN | JSON (REST) |
| **Binance TradFi** | fapi.binance.com | Apr 2026 → present | SPYUSDT, QQQUSDT, AAPLUSDT, +6 more | JSON (REST) |
| **BitMEX** | bitmex.com API | Dec 2025 → present | 8 equity symbols | JSON (REST) |

---

## License

- **Code in this repo**: MIT. See [LICENSE](LICENSE)
- **Binance data**: Accessed under Binance Terms of Use
- **Hyperliquid/Deribit data**: Public API data

---

## Acknowledgments

This project reuses funding rate normalization and arbitrage logic from **Delta Hedge** ([github.com/Nicolas-Formenton/delta-hedge](https://github.com/Nicolas-Formenton/delta-hedge)), a multi-exchange delta-neutral trading dashboard (MIT, Copyright 2025 Nicolas Formenton).

See [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md) for full credits.
