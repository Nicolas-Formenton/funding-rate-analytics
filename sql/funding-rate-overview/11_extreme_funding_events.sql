-- Purpose: Extreme funding events where rate falls outside 2-sigma band
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: date, venue, symbol, avg_rate_bps, venue_mean, venue_stddev, z_score
--
-- funding-rate-overview/11_extreme_funding_events.sql
-- Flags daily rates that deviate more than 2 standard deviations
-- from the venue-level mean. These are statistical outliers that
-- often correspond to squeezes, liquidation cascades, or data anomalies.

WITH venue_stats AS (
    SELECT
        venue,
        AVG(avg_rate_bps) AS venue_mean,
        STDDEV(avg_rate_bps) AS venue_stddev
    FROM marts.mart_daily_funding
    GROUP BY venue
)
SELECT
    f.date,
    f.venue,
    f.symbol,
    f.avg_rate_bps,
    ROUND(s.venue_mean, 4) AS venue_mean,
    ROUND(s.venue_stddev, 4) AS venue_stddev,
    ROUND((f.avg_rate_bps - s.venue_mean) / NULLIF(s.venue_stddev, 0), 2) AS z_score
FROM marts.mart_daily_funding f
JOIN venue_stats s ON f.venue = s.venue
WHERE ABS(f.avg_rate_bps - s.venue_mean) > 2 * s.venue_stddev
ORDER BY ABS((f.avg_rate_bps - s.venue_mean) / NULLIF(s.venue_stddev, 0)) DESC;
