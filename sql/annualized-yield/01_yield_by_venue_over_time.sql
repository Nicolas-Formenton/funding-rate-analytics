-- Purpose: Annualized yield over time by venue
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: date, venue, daily_annualized_yield_pct
--
-- annualized-yield/01_yield_by_venue_over_time.sql
-- Time series of daily annualized yield for each venue.
-- Annualized yield converts the 8-hour funding rate into a yearly percentage,
-- making it easy to compare against traditional yield benchmarks.

SELECT
    date,
    venue,
    daily_annualized_yield_pct
FROM marts.mart_daily_funding
ORDER BY date DESC, venue;
