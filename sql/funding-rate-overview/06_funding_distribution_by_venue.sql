-- Purpose: Histogram data for funding rate distribution by venue
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: venue, rate_bucket, observation_count, pct_of_venue
--
-- funding-rate-overview/06_funding_distribution_by_venue.sql
-- Bins funding rates into 1 bp-wide buckets for histogram visualization.
-- Shows how rates cluster around zero and how fat the tails are
-- for each venue.

WITH bounds AS (
    SELECT
        FLOOR(MIN(avg_rate_bps)) AS min_bucket,
        CEIL(MAX(avg_rate_bps)) AS max_bucket
    FROM marts.mart_daily_funding
),
bucketed AS (
    SELECT
        venue,
        FLOOR(avg_rate_bps)::int AS rate_bucket,
        COUNT(*) AS observation_count
    FROM marts.mart_daily_funding
    GROUP BY venue, FLOOR(avg_rate_bps)::int
)
SELECT
    venue,
    rate_bucket,
    observation_count,
    ROUND(100.0 * observation_count / SUM(observation_count) OVER (PARTITION BY venue), 2) AS pct_of_venue
FROM bucketed
ORDER BY venue, rate_bucket;
