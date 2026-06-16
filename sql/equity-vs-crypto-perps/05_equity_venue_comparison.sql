-- Purpose: Equity perps venue comparison (Binance vs BitMEX vs Hyperliquid XYZ)
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: venue, avg_rate_bps, median_rate_bps, std_dev_bps, total_symbols, total_days
--
-- equity-vs-crypto-perps/05_equity_venue_comparison.sql
-- Compares how different venues price equity perpetual funding.
-- Hyperliquid XYZ, Binance, and BitMEX all offer equity perps
-- but with different oracle mechanisms and liquidity profiles.

SELECT
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    COUNT(DISTINCT symbol) AS total_symbols,
    COUNT(DISTINCT date) AS total_days
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
GROUP BY venue
ORDER BY avg_rate_bps DESC;
