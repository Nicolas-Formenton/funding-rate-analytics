-- Purpose: Weekend vs weekday funding rates for crypto perps (control group)
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: is_weekend, venue, avg_rate_bps, median_rate_bps, std_dev_bps, observation_count
--
-- equity-vs-crypto-perps/03_weekend_vs_weekday_crypto.sql
-- Control group for the weekend analysis. Crypto markets trade 24/7
-- so there should be no structural weekend effect. Any weekend
-- difference here is noise, which helps calibrate what's significant
-- in the equity perps weekend analysis.

SELECT
    is_weekend,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND((PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps))::numeric, 4) AS median_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    COUNT(*) AS observation_count
FROM marts.mart_daily_funding
WHERE asset_class = 'crypto'
GROUP BY is_weekend, venue
ORDER BY venue, is_weekend;
