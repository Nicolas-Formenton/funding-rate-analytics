-- Purpose: Day-of-week spread patterns
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: day_of_week, day_name, avg_spread_bps, median_spread_bps, observation_count
--
-- cross-venue-spread/09_weekly_spread_patterns.sql
-- Checks whether cross-venue spreads behave differently on specific days.
-- Weekends might show wider spreads for equity perps due to oracle freezes,
-- while crypto perps should be more uniform across the week.

SELECT
    EXTRACT(DOW FROM date)::int AS day_of_week,
    CASE EXTRACT(DOW FROM date)::int
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    ROUND(AVG(spread_bps), 4) AS avg_spread_bps,
    ROUND((PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY spread_bps))::numeric, 4) AS median_spread_bps,
    COUNT(*) AS observation_count
FROM marts.mart_venue_comparison
GROUP BY EXTRACT(DOW FROM date)::int
ORDER BY day_of_week;
