-- Purpose: Monthly comparison of crypto vs equity funding rates
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: year_month, asset_class, avg_rate_bps, median_rate_bps, std_dev_bps, observation_count
--
-- equity-vs-crypto-perps/13_asset_class_monthly_comparison.sql
-- Side-by-side monthly comparison of crypto and equity funding rates.
-- Reveals whether the gap between asset classes is stable, widening,
-- or narrowing over time.

SELECT
    TO_CHAR(DATE_TRUNC('month', date), 'YYYY-MM') AS year_month,
    asset_class,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    COUNT(*) AS observation_count
FROM marts.mart_daily_funding
GROUP BY DATE_TRUNC('month', date), asset_class
ORDER BY year_month DESC, asset_class;
