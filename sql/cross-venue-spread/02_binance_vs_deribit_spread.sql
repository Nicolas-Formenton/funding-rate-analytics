-- Purpose: Binance vs Deribit funding rate spread over time
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, symbol, binance_rate_bps, deribit_rate_bps, spread_bps
--
-- cross-venue-spread/02_binance_vs_deribit_spread.sql
-- Tracks the funding rate differential between Binance and Deribit.
-- Deribit is options-focused, so this spread reveals how perps pricing
-- diverges between a generalist and a specialist venue.

SELECT
    date,
    symbol,
    MAX(CASE WHEN venue = 'binance' THEN avg_rate_bps END) AS binance_rate_bps,
    MAX(CASE WHEN venue = 'deribit' THEN avg_rate_bps END) AS deribit_rate_bps,
    MAX(CASE WHEN venue = 'deribit' THEN avg_rate_bps END)
      - MAX(CASE WHEN venue = 'binance' THEN avg_rate_bps END) AS spread_bps
FROM marts.mart_daily_funding
WHERE venue IN ('binance', 'deribit')
GROUP BY date, symbol
HAVING COUNT(DISTINCT venue) = 2
ORDER BY date DESC, symbol;
