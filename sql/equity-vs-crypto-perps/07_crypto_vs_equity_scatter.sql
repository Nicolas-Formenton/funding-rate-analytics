-- Purpose: Scatter plot data comparing crypto vs equity funding rates
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: date, symbol, asset_class, avg_rate_bps
--
-- equity-vs-crypto-perps/07_crypto_vs_equity_scatter.sql
-- Provides raw data points for a scatter plot comparing the funding rate
-- distributions of crypto and equity perps. Each row is one daily observation.
-- The visualization should show whether equity perps cluster at different
-- rate levels than crypto perps.

SELECT
    date,
    symbol,
    asset_class,
    avg_rate_bps
FROM marts.mart_daily_funding
ORDER BY asset_class, date;
