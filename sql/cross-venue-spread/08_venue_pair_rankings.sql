-- Purpose: Venue pair rankings by average spread
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: pair_rank, venue_long, venue_short, avg_spread_bps, max_spread_bps, observation_count
--
-- cross-venue-spread/08_venue_pair_rankings.sql
-- Ranks all venue pairs by their average funding rate spread.
-- The top pairs are the most structurally mispriced and
-- offer the best persistent arb opportunities.

SELECT
    RANK() OVER (ORDER BY AVG(spread_bps) DESC) AS pair_rank,
    venue_long,
    venue_short,
    ROUND(AVG(spread_bps), 4) AS avg_spread_bps,
    ROUND(MAX(spread_bps), 4) AS max_spread_bps,
    COUNT(*) AS observation_count
FROM marts.mart_venue_comparison
GROUP BY venue_long, venue_short
ORDER BY pair_rank;
