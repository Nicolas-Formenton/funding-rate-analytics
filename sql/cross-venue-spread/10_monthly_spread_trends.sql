-- Purpose: Monthly evolution of cross-venue spreads
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: year_month, avg_spread_bps, max_spread_bps, venue_long, venue_short
--
-- cross-venue-spread/10_monthly_spread_trends.sql
-- Aggregates spreads into monthly buckets per venue pair.
-- Shows whether arb opportunities are expanding or contracting
-- over time as markets mature.

SELECT
    TO_CHAR(DATE_TRUNC('month', date), 'YYYY-MM') AS year_month,
    venue_long,
    venue_short,
    ROUND(AVG(spread_bps), 4) AS avg_spread_bps,
    ROUND(MAX(spread_bps), 4) AS max_spread_bps,
    COUNT(*) AS observation_count
FROM marts.mart_venue_comparison
GROUP BY DATE_TRUNC('month', date), venue_long, venue_short
ORDER BY year_month DESC, venue_long, venue_short;
