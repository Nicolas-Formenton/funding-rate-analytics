-- Purpose: Summary statistics for equity perpetual category
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: metric, value
--
-- equity-vs-crypto-perps/12_equity_perps_summary_stats.sql
-- Key summary statistics for the equity perps category in a pivoted format.
-- Provides a quick dashboard-ready snapshot of the equity perps market:
-- total symbols, average rate, extreme values, and data coverage.

SELECT 'total_symbols' AS metric, COUNT(DISTINCT symbol)::text AS value FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'total_venues', COUNT(DISTINCT venue)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'total_observations', COUNT(*)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'avg_rate_bps', ROUND(AVG(avg_rate_bps), 4)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'median_rate_bps', ROUND((PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps))::numeric, 4)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'max_rate_bps', ROUND(MAX(avg_rate_bps), 4)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'min_rate_bps', ROUND(MIN(avg_rate_bps), 4)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'std_dev_bps', ROUND(STDDEV(avg_rate_bps), 4)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'date_range_start', MIN(date)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'date_range_end', MAX(date)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'weekend_pct', ROUND(100.0 * COUNT(*) FILTER (WHERE is_weekend = true) / COUNT(*), 2)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity';
