-- Purpose: Histogram of cross-venue spread values
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: spread_bucket, observation_count, pct_of_total
--
-- cross-venue-spread/07_spread_distribution.sql
-- Bins spread values into 1 bp-wide buckets to show the distribution shape.
-- Most spreads should cluster near zero; the tails show how often
-- large arb opportunities appear.

WITH bucketed AS (
    SELECT
        FLOOR(spread_bps)::int AS spread_bucket,
        COUNT(*) AS observation_count
    FROM marts.mart_venue_comparison
    GROUP BY FLOOR(spread_bps)::int
),
total AS (
    SELECT SUM(observation_count) AS grand_total FROM bucketed
)
SELECT
    spread_bucket,
    observation_count,
    ROUND(100.0 * observation_count / grand_total, 2) AS pct_of_total
FROM bucketed, total
ORDER BY spread_bucket;
