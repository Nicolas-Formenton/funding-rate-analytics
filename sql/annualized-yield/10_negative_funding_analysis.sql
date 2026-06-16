-- Purpose: Analysis of negative funding periods (shorters pay longs)
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: venue, symbol, asset_class, negative_days, total_days, negative_pct, avg_negative_rate_bps
--
-- annualized-yield/10_negative_funding_analysis.sql
-- Identifies when funding rates go negative, meaning shorts pay longs.
-- For a long-only funding strategy, negative rates are losses.
-- This query shows how often and how severely rates turn negative
-- by venue and symbol.

SELECT
    venue,
    symbol,
    asset_class,
    COUNT(*) FILTER (WHERE avg_rate_bps < 0) AS negative_days,
    COUNT(*) AS total_days,
    ROUND(100.0 * COUNT(*) FILTER (WHERE avg_rate_bps < 0) / COUNT(*), 2) AS negative_pct,
    ROUND(AVG(CASE WHEN avg_rate_bps < 0 THEN avg_rate_bps END), 4) AS avg_negative_rate_bps,
    ROUND(MIN(avg_rate_bps), 4) AS worst_negative_bps
FROM marts.mart_daily_funding
GROUP BY venue, symbol, asset_class
HAVING COUNT(*) FILTER (WHERE avg_rate_bps < 0) > 0
ORDER BY negative_pct DESC;
