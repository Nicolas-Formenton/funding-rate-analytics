# Funding Rate BI — Learnings

## Task 3: Schema Design (2026-06-16)

### Key Decisions

1. **Three-layer architecture (raw → staging → marts)**
   - Raw: venue-specific tables preserving source format
   - Staging: unified view with normalization and asset_class discriminator
   - Marts: pre-aggregated tables for analysis (hourly, daily, cross-venue)

2. **Normalization formulas**
   - Binance (8h, decimal): `rate × 3 × 365 × 100`
   - Hyperliquid (1h, decimal): `rate × 24 × 365 × 100`
   - Deribit (8h, percentage): `(interest_8h / 100) × 3 × 365`
   - Equity perps (variable): `rate × (24 / interval_hours) × 365 × 100`

3. **asset_class discriminator**
   - Added to staging view to separate crypto vs equity perps
   - Enforced via accepted_values test in dbt schema.yml
   - Critical for downstream filtering and aggregation

4. **Negative funding rates**
   - Explicitly allowed in schema tests (accepted_range: -500 to 500)
   - Negative rates = shorts paying longs (valid market signal)
   - Never filter out — they indicate market stress or short squeezes

5. **Compound key uniqueness**
   - All mart tables have unique constraints on (venue, symbol, time_bucket)
   - Prevents duplicate aggregations
   - Enforced via dbt table-level unique tests

### Technical Notes

- PostgreSQL 16 running in Docker (container: funding-rates-pg)
- psql not installed locally — use `docker exec -i funding-rates-pg psql` to execute SQL
- Staging is a VIEW (not table) — recomputes on query, ensures freshness
- Marts are TABLES — pre-aggregated for performance
- Premium calculation: `(mark - index) / index × 10000` (basis points)

### Files Created

- `schemas/01_raw.sql` — 4 raw tables (binance, hyperliquid, deribit, equity_perps)
- `schemas/02_staging.sql` — unified staging view with normalization
- `schemas/03_marts.sql` — 3 mart tables (hourly, daily, venue_comparison)
- `docs/normalization-rules.md` — detailed formulas and examples
- `dbt/models/staging/schema.yml` — 7 tests on staging view
- `dbt/models/marts/schema.yml` — 15 tests on mart tables

### Next Steps

- Task 4: Ingestion scripts (API collectors for each venue)
- Task 5: dbt models (SQL transformations for marts)
- Task 6: Dashboard (Metabase/Superset visualization)

## Task 6: Binance Historical Ingestion (2026-06-16)

### Key Decisions

1. **DELETE-per-symbol idempotency**
   - Before loading each symbol, DELETE WHERE symbol = %s
   - Simple and reliable; no metadata table needed
   - Re-running produces identical results every time

2. **Monthly ZIP strategy**
   - URL pattern: `{SYMBOL}/{SYMBOL}-fundingRate-YYYY-MM.zip`
   - ~90 rows/month at 8h funding intervals
   - Feb months: 84-87 rows (28-29 days)
   - Total data volume: ~234KB for 78 months × 3 symbols

3. **Historical coverage**
   - BTCUSDT: 2020-01 → present (77 months, 7,029 rows)
   - ETHUSDT: 2020-01 → present (77 months, 7,029 rows)
   - SOLUSDT: 2020-09 → present (69 months, 6,334 rows) — listing started later

### CSV Format

```
calc_time, funding_interval_hours, last_funding_rate
1577836800000, 8, -0.00012359
```

- calc_time: ms since epoch (UTC)
- funding_interval_hours: always 8 for Binance perps
- last_funding_rate: decimal (not percentage)
- **No mark_price or index_price** in historical ZIPs — those columns are NULL

### Technical Notes

- 404 handling: gracefully skip unavailable months (SOLUSDT pre-2020-09, current month mid-month)
- Retry logic: 3 attempts with exponential backoff
- DB config via env vars: PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD
- Full load time: ~3 min 13 sec for all 78 months × 3 symbols

### Test Coverage

- Unit: month_range, parse_csv_from_zip, download_zip (404 handling)
- Integration: row count minimums, date range, symbol coverage, idempotency
- All 11 tests passing (pytest)

### Files Created

- `scripts/load_binance.py` — idempotent Binance funding rate loader
- `tests/test_load_binance.py` — 11 pytest tests (5 unit + 6 integration)
- `.omo/evidence/task-6-binance-rows.txt` — verification evidence
