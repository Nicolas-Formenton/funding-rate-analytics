-- Purpose: Equity symbols ranked by average funding rate
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: symbol_rank, symbol, avg_rate_bps, median_rate_bps, venues_count, total_days
--
-- equity-vs-crypto-perps/06_equity_symbol_ranking.sql
-- Ranks equity perpetual symbols by their average funding rate.
-- Shows which stocks have the most persistent funding rate pressure,
-- which correlates with short interest and borrow cost dynamics.

SELECT
    RANK() OVER (ORDER BY AVG(avg_rate_bps) DESC) AS symbol_rank,
    symbol,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    COUNT(DISTINCT venue) AS venues_count,
    COUNT(DISTINCT date) AS total_days
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
GROUP BY symbol
ORDER BY symbol_rank;
