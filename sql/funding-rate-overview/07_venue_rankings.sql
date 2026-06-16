-- Purpose: Venue comparison ranked by average funding rate
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: venue_rank, venue, avg_rate_bps, total_symbols, total_days, first_date, last_date
--
-- funding-rate-overview/07_venue_rankings.sql
-- Ranks venues by their overall average funding rate.
-- Includes coverage metadata so users can see how many symbols
-- and days of data each venue contributes.

SELECT
    RANK() OVER (ORDER BY AVG(avg_rate_bps) DESC) AS venue_rank,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    COUNT(DISTINCT symbol) AS total_symbols,
    COUNT(DISTINCT date) AS total_days,
    MIN(date) AS first_date,
    MAX(date) AS last_date
FROM marts.mart_daily_funding
GROUP BY venue
ORDER BY venue_rank;
