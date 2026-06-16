-- Purpose: Average daily funding rate by symbol for last 12 months
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: symbol, date, avg_rate_bps
--
-- funding-rate-overview/02_daily_funding_by_symbol.sql
-- Aggregates daily funding rates across all venues per symbol.
-- Lets users track how a specific symbol's funding rate evolves over time
-- regardless of which venue it trades on.

SELECT
    symbol,
    date,
    AVG(avg_rate_bps) AS avg_rate_bps
FROM marts.mart_daily_funding
WHERE date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY symbol, date
ORDER BY date DESC, symbol;
