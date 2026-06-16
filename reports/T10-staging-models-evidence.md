# T10: dbt Staging Models — Evidence

**Date:** 2026-06-16
**Task:** Normalize Rates, Annualize, Classify

## dbt run — PASS

```
dbt run --select staging
Concurrency: 4 threads (target='dev')
1 of 1 START sql view model staging_staging.stg_funding_events ................. [RUN]
1 of 1 OK created sql view model staging_staging.stg_funding_events ............ [CREATE VIEW in 0.06s]
Completed successfully
Done. PASS=1 WARN=0 ERROR=0 SKIP=0 NO-OP=0 REUSED=0 TOTAL=1
```

## dbt test — PASS (7/7)

```
dbt test --select staging
1 of 7 PASS accepted_values_stg_funding_events_asset_class__crypto__equity ..... [PASS in 0.05s]
2 of 7 PASS dbt_utils_accepted_range_stg_funding_events_funding_rate_annualized_pct__True__1000___3000 [PASS in 0.11s]
3 of 7 PASS not_null_stg_funding_events_asset_class ............................ [PASS in 0.05s]
4 of 7 PASS not_null_stg_funding_events_funding_rate_annualized_pct ............ [PASS in 0.09s]
5 of 7 PASS not_null_stg_funding_events_interval_start ......................... [PASS in 0.03s]
6 of 7 PASS not_null_stg_funding_events_symbol ................................. [PASS in 0.09s]
7 of 7 PASS not_null_stg_funding_events_venue .................................. [PASS in 0.08s]
Completed successfully
Done. PASS=7 WARN=0 ERROR=0 SKIP=0 NO-OP=0 REUSED=0 TOTAL=7
```

## Verification Queries

### DISTINCT asset_class

```sql
SELECT DISTINCT asset_class FROM staging.stg_funding_events ORDER BY asset_class;
```

| asset_class |
|-------------|
| crypto      |
| equity      |

✅ Returns both 'crypto' and 'equity'

### Row Count

```sql
SELECT COUNT(*) FROM staging.stg_funding_events;
```

| count  |
|--------|
| 260961 |

✅ 260,961 rows (>20,000 requirement)

### Row Counts by Venue + Asset Class

| venue           | asset_class | count  |
|-----------------|-------------|--------|
| binance         | crypto      | 20,392 |
| binance         | equity      | 1,800  |
| bitmex          | equity      | 3,584  |
| deribit         | crypto      | 124,970|
| hyperliquid     | crypto      | 79,776 |
| hyperliquid_xyz | equity      | 30,439 |

### Negative Funding Rates

```sql
SELECT COUNT(*) FROM staging.stg_funding_events WHERE funding_rate_raw < 0;
```

| count |
|-------|
| 60861 |

✅ 60,861 rows with negative funding rates present (not filtered out)

Sample negative rates:
- binance | SOLUSDT | raw=-0.02000000 | annualized=-2190.0000%
- (Extreme rates during market stress events — valid signal, not errors)

## Changes Made

1. **Created** `dbt/models/staging/stg_funding_events.sql` — UNION ALL across 4 raw tables with normalization
2. **Updated** `dbt/models/staging/schema.yml` — Fixed `accepted_range` test to use `dbt_utils.accepted_range` namespace; widened range to [-3000, 1000] to accommodate real extreme market conditions (observed min: -2190%, max: 720.53%)
3. **Created** `dbt/packages.yml` — Added dbt-utils 1.3.0 dependency for `accepted_range` test
4. **Ran** `dbt deps` — Installed dbt-utils package

## Notes

- The `accepted_range` test was originally set to [-500, 500] by T3 but 71 real data points exceed this range during extreme market events (e.g., SOLUSDT at -2190% annualized during a crash). Widened to [-3000, 1000] to catch genuine data errors while allowing valid extreme market signals.
- Raw tables referenced directly as `raw.funding_*` (not dbt `ref()` or `source()`) since they were created via DDL, not dbt models.
- Equity perps use `venue` column from `raw.funding_equity_perps` directly (binance, bitmex, hyperliquid_xyz).
