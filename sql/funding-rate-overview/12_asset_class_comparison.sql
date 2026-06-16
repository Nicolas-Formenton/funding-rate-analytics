-- Purpose: Crypto vs equity asset class summary statistics
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: asset_class, avg_rate_bps, median_rate_bps, p5_rate_bps, p95_rate_bps, std_dev_bps, total_observations
--
-- funding-rate-overview/12_asset_class_comparison.sql
-- Compares the overall funding rate distribution between crypto and equity perps.
-- Answers the question: do equity perps systematically pay more or less
-- than crypto perps?

SELECT
    asset_class,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    ROUND(PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS p5_rate_bps,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS p95_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    COUNT(*) AS total_observations
FROM marts.mart_daily_funding
GROUP BY asset_class
ORDER BY asset_class;
