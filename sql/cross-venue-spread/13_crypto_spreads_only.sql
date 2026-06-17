-- Purpose: Cross-venue spreads for crypto symbols only
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, symbol, venue_long, venue_short, spread_bps, arb_apy_pct
--
-- cross-venue-spread/13_crypto_spreads_only.sql
-- Filters the venue comparison mart to crypto symbols.
-- Crypto perps trade 24/7 across all venues, so spreads here
-- reflect pure market microstructure differences rather than
-- structural factors like oracle freezes.

SELECT
    date,
    symbol,
    venue_long,
    venue_short,
    spread_bps,
    ROUND(spread_bps / 100.0, 2) AS arb_apy_pct
FROM marts.mart_venue_comparison
WHERE asset_class = 'crypto'
ORDER BY date DESC, spread_bps DESC;
