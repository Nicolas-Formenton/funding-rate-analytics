-- Purpose: Monthly average funding rate by venue
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: year_month, venue, avg_rate_bps, observation_count
--
-- funding-rate-overview/05_monthly_funding_trend.sql
-- Aggregates daily rates into monthly buckets per venue.
-- Smooths out daily noise to reveal medium-term trends
-- in funding rate behavior across exchanges.

SELECT
    TO_CHAR(DATE_TRUNC('month', date), 'YYYY-MM') AS year_month,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    COUNT(*) AS observation_count
FROM marts.mart_daily_funding
GROUP BY DATE_TRUNC('month', date), venue
ORDER BY year_month DESC, venue;
