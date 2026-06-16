-- Purpose: Summary statistics (avg, median, p5, p95) by venue
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: venue, avg_rate_bps, median_rate_bps, p5_rate_bps, p95_rate_bps, observation_count
--
-- funding-rate-overview/04_summary_stats_by_venue.sql
-- Provides a statistical profile for each venue.
-- The percentile breakdown shows the distribution shape and
-- helps identify which venues have wider funding rate spreads.

SELECT
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    ROUND(PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS p5_rate_bps,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS p95_rate_bps,
    COUNT(*) AS observation_count
FROM marts.mart_daily_funding
GROUP BY venue
ORDER BY avg_rate_bps DESC;
