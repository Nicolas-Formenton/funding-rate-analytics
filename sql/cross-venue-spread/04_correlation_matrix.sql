-- Purpose: Funding rate correlation matrix across venues
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_daily_funding
-- Columns: venue_a, venue_b, correlation, shared_symbols, shared_days
--
-- cross-venue-spread/04_correlation_matrix.sql
-- Computes pairwise Pearson correlation of daily funding rates
-- between all venue pairs. High correlation means venues move together;
-- low correlation means more arb opportunity.

WITH venue_pairs AS (
    SELECT DISTINCT
        LEAST(a.venue, b.venue) AS venue_a,
        GREATEST(a.venue, b.venue) AS venue_b
    FROM marts.mart_daily_funding a
    JOIN marts.mart_daily_funding b
        ON a.symbol = b.symbol AND a.date = b.date AND a.venue < b.venue
)
SELECT
    vp.venue_a,
    vp.venue_b,
    ROUND(CORR(a.avg_rate_bps, b.avg_rate_bps)::numeric, 4) AS correlation,
    COUNT(DISTINCT a.symbol) AS shared_symbols,
    COUNT(*) AS shared_days
FROM venue_pairs vp
JOIN marts.mart_daily_funding a
    ON a.venue = vp.venue_a
JOIN marts.mart_daily_funding b
    ON b.venue = vp.venue_b AND b.symbol = a.symbol AND b.date = a.date
GROUP BY vp.venue_a, vp.venue_b
ORDER BY correlation DESC;
