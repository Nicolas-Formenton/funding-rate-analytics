Task 20: README — Olist-Style Portfolio Narrative
===================================================
Date: 2026-06-16
Status: COMPLETED

OUTPUT FILE
-----------
/Users/nformenton/Dev/funding-rate-analytics/README.md

DB QUERY RESULTS (exact row counts from PostgreSQL)
----------------------------------------------------
raw.funding_binance:         20,392
raw.funding_hyperliquid:     79,776
raw.funding_deribit:        124,970
raw.funding_equity_perps:    35,823
staging.stg_funding_events: 260,961  (view, UNION ALL of raw)
marts.mart_hourly_funding:  260,956
marts.mart_daily_funding:    18,437
marts.mart_venue_comparison: 11,273

ASSET COVERAGE (from marts.mart_daily_funding)
-----------------------------------------------
Crypto: 6 symbols, 3 venues (binance, hyperliquid, deribit), Apr 2019 – Jun 2026
Equity: 15 symbols, 3 venues (binance, bitmex, hyperliquid_xyz), Nov 2025 – Jun 2026

VENUE BREAKDOWN
---------------
binance/crypto:         3 symbols, Jan 2020 – May 2026
deribit/crypto:         2 symbols, Apr 2019 – Jun 2026
hyperliquid/crypto:     3 symbols, May 2023 – Jun 2026
binance/equity:         9 symbols, Apr 2026 – Jun 2026
bitmex/equity:          8 symbols, Dec 2025 – Jun 2026
hyperliquid_xyz/equity: 6 symbols, Nov 2025 – Jun 2026

DERIVED STATS
-------------
Total distinct symbols:  21
Total distinct venues:   5
Negative funding events: 60,860 (avg_rate_bps < 0)
Positive spread days:    4,686 of 11,273 (max_cross_spread_bps > 0)
SQL queries total:       51 (12 + 14 + 13 + 12)
dbt models:              4 (1 view + 3 tables)
dbt tests:               24

ACTIONS TAKEN
-------------
1. Ran dbt deps + dbt run to materialize staging/marts tables (were not yet built)
2. Queried PostgreSQL for exact row counts across all 8 tables
3. Queried asset coverage by asset_class and venue
4. Queried derived stats (negative events, positive spreads)
5. Read Olist README pattern for narrative structure reference
6. Inspected actual project directory structure (sql/, scripts/, src/, dbt/, tests/, docs/, schemas/, data/)
7. Wrote comprehensive README.md following Olist narrative:
   hook → dashboards → pipeline → tables → tech → structure → what-numbers-mean → equity-perps → how-to → sources → license → acknowledgments

NOTES
-----
- dbt custom schema config creates staging_staging/staging_marts in PG, but README uses logical names staging/marts (matching dbt_project.yml model config)
- Deepnote and Hex URLs marked as TBD (user hasn't published yet)
- All [N] placeholders replaced with exact DB values
- No em dashes used (anti-AI-slop rule)
- Headline: 260,961 funding rate observations from 5 perpetual futures venues
