-- Purpose: Arbitrage opportunities where annualized arb APY exceeds 10%
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, symbol, venue_long, venue_short, spread_bps, arb_apy_pct
--
-- cross-venue-spread/03_arb_opportunities.sql
-- Identifies days where the cross-venue funding rate spread
-- annualizes to more than 10%. These are actionable funding rate
-- arbitrage windows: long funding on the cheaper venue, short on the expensive one.

SELECT
    date,
    symbol,
    venue_long,
    venue_short,
    spread_bps,
    ROUND(spread_bps / 100.0, 2) AS arb_apy_pct
FROM marts.mart_venue_comparison
WHERE spread_bps * 3.65 > 10.0
ORDER BY arb_apy_pct DESC, date DESC;
