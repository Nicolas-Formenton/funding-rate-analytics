-- Purpose: Funding rate volatility by venue (30-day rolling standard deviation)
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: date, venue, rolling_stddev_30d, rolling_avg_30d
--
-- funding-rate-overview/10_funding_rate_volatility.sql
-- Computes a 30-day rolling standard deviation of funding rates per venue.
-- High volatility signals unstable funding regimes, which matters
-- for strategies that hold positions across funding intervals.

SELECT
    date,
    venue,
    ROUND(STDDEV(avg_rate_bps) OVER w, 4) AS rolling_stddev_30d,
    ROUND(AVG(avg_rate_bps) OVER w, 4) AS rolling_avg_30d
FROM marts.mart_daily_funding
WINDOW w AS (
    PARTITION BY venue
    ORDER BY date
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
)
ORDER BY date DESC, venue;
