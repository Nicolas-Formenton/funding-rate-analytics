-- Purpose: Yield breakdown by symbol
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: symbol, asset_class, avg_annualized_yield_pct, median_yield_pct, max_yield_pct, min_yield_pct, total_days
--
-- annualized-yield/05_yield_by_symbol.sql
-- Aggregates annualized yield statistics per symbol across all venues.
-- Shows which symbols consistently offer the best funding yield
-- and how stable that yield is over time.

SELECT
    symbol,
    asset_class,
    ROUND(AVG(daily_annualized_yield_pct), 4) AS avg_annualized_yield_pct,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY daily_annualized_yield_pct), 4) AS median_yield_pct,
    ROUND(MAX(daily_annualized_yield_pct), 4) AS max_yield_pct,
    ROUND(MIN(daily_annualized_yield_pct), 4) AS min_yield_pct,
    COUNT(DISTINCT date) AS total_days
FROM marts.mart_daily_funding
GROUP BY symbol, asset_class
ORDER BY avg_annualized_yield_pct DESC;
