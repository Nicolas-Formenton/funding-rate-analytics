-- Purpose: Rolling 30-day yield volatility by venue
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: date, venue, rolling_yield_stddev_30d, rolling_yield_avg_30d
--
-- annualized-yield/02_yield_volatility.sql
-- Measures how stable the annualized yield is over a 30-day window.
-- High volatility means the yield is unreliable as a persistent income source.
-- Low volatility with positive yield is the ideal carry trade setup.

SELECT
    date,
    venue,
    ROUND(STDDEV(daily_annualized_yield_pct) OVER w, 4) AS rolling_yield_stddev_30d,
    ROUND(AVG(daily_annualized_yield_pct) OVER w, 4) AS rolling_yield_avg_30d
FROM marts.mart_daily_funding
WINDOW w AS (
    PARTITION BY venue
    ORDER BY date
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
)
ORDER BY date DESC, venue;
