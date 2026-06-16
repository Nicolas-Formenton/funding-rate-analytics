-- Purpose: Monthly seasonality patterns in annualized yield
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: month_num, month_name, avg_yield_pct, median_yield_pct, observation_count
--
-- annualized-yield/12_yield_seasonality.sql
-- Checks whether annualized yield has monthly seasonality.
-- Some months might consistently offer better funding yields
-- due to market cycles, options expiration patterns, or
-- quarterly funding events.

SELECT
    EXTRACT(MONTH FROM date)::int AS month_num,
    TO_CHAR(DATE_TRUNC('month', date), 'Month') AS month_name,
    ROUND(AVG(daily_annualized_yield_pct), 4) AS avg_yield_pct,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY daily_annualized_yield_pct), 4) AS median_yield_pct,
    COUNT(*) AS observation_count
FROM marts.mart_daily_funding
GROUP BY EXTRACT(MONTH FROM date), TO_CHAR(DATE_TRUNC('month', date), 'Month')
ORDER BY month_num;
