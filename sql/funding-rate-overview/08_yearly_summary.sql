-- Purpose: Yearly aggregates by venue
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: year, venue, avg_rate_bps, max_rate_bps, min_rate_bps, total_days
--
-- funding-rate-overview/08_yearly_summary.sql
-- Rolls up daily funding data into yearly summaries per venue.
-- Gives a high-level view of how funding rate regimes shift year over year.

SELECT
    EXTRACT(YEAR FROM date)::int AS year,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(MAX(avg_rate_bps), 4) AS max_rate_bps,
    ROUND(MIN(avg_rate_bps), 4) AS min_rate_bps,
    COUNT(DISTINCT date) AS total_days
FROM marts.mart_daily_funding
GROUP BY EXTRACT(YEAR FROM date), venue
ORDER BY year DESC, venue;
