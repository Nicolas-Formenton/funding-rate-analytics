-- Purpose: Spread vs funding rate volatility scatter data
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: symbol, venue_long, venue_short, avg_spread_bps, spread_stddev, avg_rate_bps, rate_stddev
--
-- cross-venue-spread/14_spread_vs_volatility.sql
-- For each venue pair and symbol, computes both the average spread
-- and the volatility of both the spread and the underlying rates.
-- Used as scatter plot data to explore whether more volatile symbols
-- have wider cross-venue spreads.

SELECT
    symbol,
    venue_long,
    venue_short,
    ROUND(AVG(spread_bps), 4) AS avg_spread_bps,
    ROUND(STDDEV(spread_bps), 4) AS spread_stddev,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS rate_stddev
FROM marts.mart_venue_comparison
GROUP BY symbol, venue_long, venue_short
ORDER BY avg_spread_bps DESC;
