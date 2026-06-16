-- Purpose: Hyperliquid vs Deribit funding rate spread over time
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, symbol, hyperliquid_rate_bps, deribit_rate_bps, spread_bps
--
-- cross-venue-spread/12_hyperliquid_vs_deribit_spread.sql
-- Compares funding rates between Hyperliquid (a DEX) and Deribit
-- (an options-focused CEX). Interesting because these venues
-- have very different market microstructures.

SELECT
    date,
    symbol,
    MAX(CASE WHEN venue = 'hyperliquid' THEN avg_rate_bps END) AS hyperliquid_rate_bps,
    MAX(CASE WHEN venue = 'deribit' THEN avg_rate_bps END) AS deribit_rate_bps,
    MAX(CASE WHEN venue = 'hyperliquid' THEN avg_rate_bps END)
      - MAX(CASE WHEN venue = 'deribit' THEN avg_rate_bps END) AS spread_bps
FROM marts.mart_daily_funding
WHERE venue IN ('hyperliquid', 'deribit')
GROUP BY date, symbol
HAVING COUNT(DISTINCT venue) = 2
ORDER BY date DESC, symbol;
