-- Purpose: Venue x month yield heatmap matrix
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: venue, year_month, avg_yield_pct
--
-- annualized-yield/09_monthly_yield_heatmap.sql
-- Produces a venue-by-month matrix of average annualized yield.
-- Designed for heatmap visualization where rows are venues,
-- columns are months, and color intensity represents yield level.

SELECT
    venue,
    TO_CHAR(DATE_TRUNC('month', date), 'YYYY-MM') AS year_month,
    ROUND(AVG(daily_annualized_yield_pct), 4) AS avg_yield_pct
FROM marts.mart_daily_funding
GROUP BY venue, DATE_TRUNC('month', date)
ORDER BY venue, year_month;
