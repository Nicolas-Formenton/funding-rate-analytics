-- Purpose: Rolling 30-day average spread by venue pair
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, venue_long, venue_short, rolling_avg_spread_30d
--
-- cross-venue-spread/05_rolling_30d_avg_spread.sql
-- Smooths daily cross-venue spreads with a 30-day rolling average.
-- Reveals persistent structural spreads vs transient spikes.

SELECT
    date,
    venue_long,
    venue_short,
    ROUND(AVG(spread_bps) OVER (
        PARTITION BY venue_long, venue_short
        ORDER BY date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 4) AS rolling_avg_spread_30d
FROM marts.mart_venue_comparison
ORDER BY date DESC, venue_long, venue_short;
