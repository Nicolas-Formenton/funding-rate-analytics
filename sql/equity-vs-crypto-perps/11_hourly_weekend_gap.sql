-- Purpose: Hourly granularity weekend gap detection for equity perps
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_hourly_funding
-- Columns: date, hour_of_day, asset_class, venue, avg_rate_bps, rate_change_from_prev_hour
--
-- equity-vs-crypto-perps/11_hourly_weekend_gap.sql
-- Detects funding rate gaps at hourly granularity around weekend transitions.
-- For equity perps, the oracle freeze should cause a visible discontinuity
-- between Friday evening and Monday morning rates. Crypto perps should
-- show no such gap.

SELECT
    DATE(hour_start) AS date,
    EXTRACT(HOUR FROM hour_start)::int AS hour_of_day,
    asset_class,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(
        AVG(avg_rate_bps) - LAG(AVG(avg_rate_bps)) OVER (
            PARTITION BY asset_class, venue
            ORDER BY DATE(hour_start), EXTRACT(HOUR FROM hour_start)
        ),
        4
    ) AS rate_change_from_prev_hour
FROM marts.mart_hourly_funding
WHERE EXTRACT(DOW FROM hour_start) IN (0, 5, 6)
GROUP BY DATE(hour_start), EXTRACT(HOUR FROM hour_start), asset_class, venue
ORDER BY DATE(hour_start), hour_of_day, asset_class, venue;
