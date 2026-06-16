-- Purpose: Equity perps funding rate history over time
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: date, symbol, venue, avg_rate_bps
--
-- equity-vs-crypto-perps/01_equity_funding_over_time.sql
-- Time series of funding rates for equity perpetual contracts.
-- Equity perps are a newer product class and this query tracks
-- how their funding rates have evolved since launch.

SELECT
    date,
    symbol,
    venue,
    avg_rate_bps
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
ORDER BY date DESC, symbol, venue;
