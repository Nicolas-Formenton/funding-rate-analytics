-- Purpose: Yearly yield aggregates by venue
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: year, venue, avg_yield_pct, max_yield_pct, min_yield_pct, total_days
--
-- annualized-yield/06_yearly_yield_summary.sql
-- Rolls up annualized yield into yearly summaries per venue.
-- Shows how yield regimes shift year over year and whether
-- certain venues consistently offer better returns.

SELECT
    EXTRACT(YEAR FROM date)::int AS year,
    venue,
    ROUND(AVG(daily_annualized_yield_pct), 4) AS avg_yield_pct,
    ROUND(MAX(daily_annualized_yield_pct), 4) AS max_yield_pct,
    ROUND(MIN(daily_annualized_yield_pct), 4) AS min_yield_pct,
    COUNT(DISTINCT date) AS total_days
FROM marts.mart_daily_funding
GROUP BY EXTRACT(YEAR FROM date), venue
ORDER BY year DESC, venue;
