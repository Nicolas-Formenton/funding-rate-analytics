-- Purpose: Equity weekend funding premium percentage
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: symbol, venue, weekday_avg_bps, weekend_avg_bps, weekend_premium_pct
--
-- equity-vs-crypto-perps/08_weekend_premium_analysis.sql
-- Quantifies the weekend funding premium for equity perps.
-- The premium is calculated as (weekend_avg - weekday_avg) / abs(weekday_avg) * 100.
-- A positive premium means funding rates are higher on weekends,
-- consistent with the oracle freeze hypothesis.

SELECT
    symbol,
    venue,
    ROUND(AVG(CASE WHEN is_weekend = false THEN avg_rate_bps END), 4) AS weekday_avg_bps,
    ROUND(AVG(CASE WHEN is_weekend = true THEN avg_rate_bps END), 4) AS weekend_avg_bps,
    ROUND(
        100.0 * (
            AVG(CASE WHEN is_weekend = true THEN avg_rate_bps END)
            - AVG(CASE WHEN is_weekend = false THEN avg_rate_bps END)
        ) / NULLIF(ABS(AVG(CASE WHEN is_weekend = false THEN avg_rate_bps END)), 0),
        2
    ) AS weekend_premium_pct
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
GROUP BY symbol, venue
HAVING COUNT(CASE WHEN is_weekend = true THEN 1 END) > 0
   AND COUNT(CASE WHEN is_weekend = false THEN 1 END) > 0
ORDER BY weekend_premium_pct DESC NULLS LAST;
