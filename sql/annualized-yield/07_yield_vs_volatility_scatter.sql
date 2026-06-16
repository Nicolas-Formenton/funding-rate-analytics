-- Purpose: Risk-return scatter data (yield vs volatility)
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: venue, symbol, asset_class, avg_yield_pct, yield_stddev_pct, sharpe_like_ratio
--
-- annualized-yield/07_yield_vs_volatility_scatter.sql
-- For each venue-symbol pair, computes average yield and yield volatility.
-- The Sharpe-like ratio (avg / stddev) helps identify the best
-- risk-adjusted yield opportunities. High yield with low volatility
-- is the sweet spot for carry strategies.

SELECT
    venue,
    symbol,
    asset_class,
    ROUND(AVG(daily_annualized_yield_pct), 4) AS avg_yield_pct,
    ROUND(STDDEV(daily_annualized_yield_pct), 4) AS yield_stddev_pct,
    ROUND(
        AVG(daily_annualized_yield_pct) / NULLIF(STDDEV(daily_annualized_yield_pct), 0),
        4
    ) AS sharpe_like_ratio
FROM marts.mart_daily_funding
GROUP BY venue, symbol, asset_class
HAVING COUNT(*) > 10
ORDER BY sharpe_like_ratio DESC NULLS LAST;
