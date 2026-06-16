-- Purpose: Cumulative funding yield if held for 1 year
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: venue, symbol, cumulative_yield_pct, days_held, avg_daily_yield_pct
--
-- annualized-yield/03_cumulative_yield.sql
-- Computes the cumulative funding yield for each venue-symbol pair
-- over the full available data window. Shows what a holder would have
-- earned (or paid) in funding if they maintained the position
-- from the first to the last available date.

SELECT
    venue,
    symbol,
    ROUND(SUM(avg_rate_bps) / 100.0, 4) AS cumulative_yield_pct,
    COUNT(DISTINCT date) AS days_held,
    ROUND(AVG(avg_rate_bps) / 100.0, 4) AS avg_daily_yield_pct
FROM marts.mart_daily_funding
GROUP BY venue, symbol
ORDER BY cumulative_yield_pct DESC;
