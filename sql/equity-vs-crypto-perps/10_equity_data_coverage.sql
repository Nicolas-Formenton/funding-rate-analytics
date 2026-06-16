-- Purpose: Data availability by venue and symbol for equity perps
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: venue, symbol, first_date, last_date, total_days, total_weekdays, total_weekends, coverage_pct
--
-- equity-vs-crypto-perps/10_equity_data_coverage.sql
-- Audits data completeness for equity perpetual symbols across venues.
-- Shows date ranges, day counts, and what percentage of possible days
-- have data. Helps identify gaps in the dataset.

SELECT
    venue,
    symbol,
    MIN(date) AS first_date,
    MAX(date) AS last_date,
    COUNT(DISTINCT date) AS total_days,
    COUNT(DISTINCT date) FILTER (WHERE is_weekend = false) AS total_weekdays,
    COUNT(DISTINCT date) FILTER (WHERE is_weekend = true) AS total_weekends,
    ROUND(
        100.0 * COUNT(DISTINCT date)
        / NULLIF(MAX(date) - MIN(date) + 1, 0),
        2
    ) AS coverage_pct
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
GROUP BY venue, symbol
ORDER BY venue, total_days DESC;
