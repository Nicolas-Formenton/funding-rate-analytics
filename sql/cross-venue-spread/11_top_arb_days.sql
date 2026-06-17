-- Purpose: Top 20 arbitrage opportunity days by annualized APY
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, symbol, venue_long, venue_short, spread_bps, arb_apy_pct
--
-- cross-venue-spread/11_top_arb_days.sql
-- Ranks the best 20 days for cross-venue funding rate arbitrage.
-- Annualizes the daily spread to show the equivalent APY
-- if the opportunity persisted for a full year.

SELECT
    date,
    symbol,
    venue_long,
    venue_short,
    spread_bps,
    ROUND(spread_bps / 100.0, 2) AS arb_apy_pct
FROM marts.mart_venue_comparison
ORDER BY arb_apy_pct DESC
LIMIT 20;
