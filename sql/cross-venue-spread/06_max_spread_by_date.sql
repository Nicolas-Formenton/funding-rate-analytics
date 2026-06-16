-- Purpose: Daily maximum cross-venue spread across all venue pairs
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, max_spread_bps, venue_long, venue_short, symbol
--
-- cross-venue-spread/06_max_spread_by_date.sql
-- For each day, finds the single largest funding rate spread
-- across all venue pairs and symbols. Highlights the best
-- arb opportunity available on any given day.

SELECT
    date,
    MAX(spread_bps) AS max_spread_bps,
    (ARRAY_AGG(venue_long ORDER BY spread_bps DESC))[1] AS venue_long,
    (ARRAY_AGG(venue_short ORDER BY spread_bps DESC))[1] AS venue_short,
    (ARRAY_AGG(symbol ORDER BY spread_bps DESC))[1] AS symbol
FROM marts.mart_venue_comparison
GROUP BY date
ORDER BY date DESC;
