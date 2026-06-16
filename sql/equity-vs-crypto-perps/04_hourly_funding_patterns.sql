-- Purpose: Hourly funding patterns comparing crypto (continuous) vs equity (weekend gap)
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_hourly_funding
-- Columns: hour_of_day, asset_class, avg_rate_bps, observation_count
--
-- equity-vs-crypto-perps/04_hourly_funding_patterns.sql
-- Compares hourly funding rate patterns between crypto and equity perps.
-- Crypto perps should show relatively uniform hourly rates (24/7 market).
-- Equity perps may show gaps or anomalies around market close/open hours
-- and especially on weekends when oracles freeze.

SELECT
    EXTRACT(HOUR FROM timestamp) AS hour_of_day,
    asset_class,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    COUNT(*) AS observation_count
FROM marts.mart_hourly_funding
GROUP BY EXTRACT(HOUR FROM timestamp), asset_class
ORDER BY hour_of_day, asset_class;
