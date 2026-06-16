-- Purpose: Average daily funding rate by venue for last 12 months
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: venue, symbol, date, avg_rate_bps
--
-- funding-rate-overview/01_daily_funding_by_venue.sql
-- Shows the daily average funding rate in basis points for each venue,
-- filtered to the last 12 months. Used as the primary time-series chart
-- on the Funding Rate Overview dashboard.

SELECT
    venue,
    symbol,
    date,
    avg_rate_bps
FROM marts.mart_daily_funding
WHERE date >= CURRENT_DATE - INTERVAL '12 months'
ORDER BY date DESC, venue, symbol;
