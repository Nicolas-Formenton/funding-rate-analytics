-- Purpose: All crypto perpetuals summary overview
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: symbol, venue, avg_rate_bps, median_rate_bps, std_dev_bps, total_days, first_date, last_date
--
-- funding-rate-overview/09_crypto_perps_overview.sql
-- Filters to crypto asset class only and provides a per-symbol,
-- per-venue summary. Lets users quickly see which crypto perps
-- have the highest sustained funding rates.

SELECT
    symbol,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    COUNT(DISTINCT date) AS total_days,
    MIN(date) AS first_date,
    MAX(date) AS last_date
FROM marts.mart_daily_funding
WHERE asset_class = 'crypto'
GROUP BY symbol, venue
ORDER BY avg_rate_bps DESC;
