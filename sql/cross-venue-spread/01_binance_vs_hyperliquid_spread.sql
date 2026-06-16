-- Purpose: Binance vs Hyperliquid funding rate spread over time
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, symbol, binance_rate_bps, hyperliquid_rate_bps, spread_bps
--
-- cross-venue-spread/01_binance_vs_hyperliquid_spread.sql
-- Tracks the funding rate differential between Binance and Hyperliquid
-- for each shared symbol over time. Positive spread means Hyperliquid
-- pays more than Binance.

SELECT
    date,
    symbol,
    MAX(CASE WHEN venue = 'binance' THEN avg_rate_bps END) AS binance_rate_bps,
    MAX(CASE WHEN venue = 'hyperliquid' THEN avg_rate_bps END) AS hyperliquid_rate_bps,
    MAX(CASE WHEN venue = 'hyperliquid' THEN avg_rate_bps END)
      - MAX(CASE WHEN venue = 'binance' THEN avg_rate_bps END) AS spread_bps
FROM marts.mart_daily_funding
WHERE venue IN ('binance', 'hyperliquid')
GROUP BY date, symbol
HAVING COUNT(DISTINCT venue) = 2
ORDER BY date DESC, symbol;
