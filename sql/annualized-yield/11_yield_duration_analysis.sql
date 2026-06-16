-- Purpose: Duration analysis of high-yield periods
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: venue, symbol, streak_start, streak_end, streak_length_days, avg_yield_during_streak_pct
--
-- annualized-yield/11_yield_duration_analysis.sql
-- Identifies consecutive-day streaks where annualized yield exceeded 20%.
-- Shows how long high-yield regimes persist before reverting.
-- Important for sizing positions: a 30-day streak is very different
-- from a 3-day spike.

WITH flagged AS (
    SELECT
        date,
        venue,
        symbol,
        daily_annualized_yield_pct,
        CASE WHEN daily_annualized_yield_pct > 20.0 THEN 1 ELSE 0 END AS is_high_yield,
        ROW_NUMBER() OVER (PARTITION BY venue, symbol ORDER BY date) AS rn
    FROM marts.mart_daily_funding
),
grouped AS (
    SELECT
        date,
        venue,
        symbol,
        daily_annualized_yield_pct,
        rn - SUM(is_high_yield) OVER (PARTITION BY venue, symbol ORDER BY date ROWS UNBOUNDED PRECEDING) AS grp
    FROM flagged
    WHERE is_high_yield = 1
)
SELECT
    venue,
    symbol,
    MIN(date) AS streak_start,
    MAX(date) AS streak_end,
    COUNT(*) AS streak_length_days,
    ROUND(AVG(daily_annualized_yield_pct), 4) AS avg_yield_during_streak_pct
FROM grouped
GROUP BY venue, symbol, grp
HAVING COUNT(*) >= 3
ORDER BY streak_length_days DESC, avg_yield_during_streak_pct DESC;
