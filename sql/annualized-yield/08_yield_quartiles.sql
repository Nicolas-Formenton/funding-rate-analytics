-- Purpose: Yield distribution quartiles by venue
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: venue, q1_yield_pct, q2_yield_pct, q3_yield_pct, q4_yield_pct, iqr_pct
--
-- annualized-yield/08_yield_quartiles.sql
-- Computes quartile boundaries for annualized yield per venue.
-- The interquartile range (IQR) shows how concentrated yields are.
-- A narrow IQR means the venue offers predictable returns.

SELECT
    venue,
    ROUND((PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY daily_annualized_yield_pct))::numeric, 4) AS q1_yield_pct,
    ROUND((PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY daily_annualized_yield_pct))::numeric, 4) AS q2_yield_pct,
    ROUND((PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY daily_annualized_yield_pct))::numeric, 4) AS q3_yield_pct,
    ROUND((PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY daily_annualized_yield_pct))::numeric, 4) AS q4_yield_pct,
    ROUND((PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY daily_annualized_yield_pct) - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY daily_annualized_yield_pct))::numeric, 4) AS iqr_pct
FROM marts.mart_daily_funding
GROUP BY venue
ORDER BY q2_yield_pct DESC;
