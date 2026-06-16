-- Purpose: Weekend vs weekday funding rates for equity perps (oracle freeze effect)
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: is_weekend, venue, avg_rate_bps, median_rate_bps, std_dev_bps, observation_count
--
-- equity-vs-crypto-perps/02_weekend_vs_weekday_equity.sql
-- Equity perps rely on oracle price feeds that freeze on weekends
-- when traditional markets are closed. This query compares weekend
-- vs weekday funding rates to measure the oracle freeze impact.
-- Expect wider spreads and more extreme rates on weekends.

SELECT
    is_weekend,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    COUNT(*) AS observation_count
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
GROUP BY is_weekend, venue
ORDER BY venue, is_weekend;
