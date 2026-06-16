-- Purpose: Highest annualized yield opportunities
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: date, venue, symbol, asset_class, daily_annualized_yield_pct, avg_rate_bps
--
-- annualized-yield/04_top_yield_opportunities.sql
-- Ranks the top annualized yield observations across all venues and symbols.
-- These are the days where holding a long position would have earned
-- the most in funding payments.

SELECT
    date,
    venue,
    symbol,
    asset_class,
    daily_annualized_yield_pct,
    avg_rate_bps
FROM marts.mart_daily_funding
ORDER BY daily_annualized_yield_pct DESC
LIMIT 50;
