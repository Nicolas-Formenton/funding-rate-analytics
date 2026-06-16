-- Purpose: Top 10 highest funding rate days across all venues and symbols
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: date, venue, symbol, avg_rate_bps, asset_class
--
-- funding-rate-overview/03_top10_highest_funding_days.sql
-- Identifies the most extreme positive funding events.
-- Useful for spotting when shorts were paying the most and
-- when funding rate spikes occurred.

SELECT
    date,
    venue,
    symbol,
    avg_rate_bps,
    asset_class
FROM marts.mart_daily_funding
ORDER BY avg_rate_bps DESC
LIMIT 10;
