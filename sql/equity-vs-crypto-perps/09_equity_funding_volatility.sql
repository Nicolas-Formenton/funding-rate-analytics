-- Purpose: Funding rate volatility by equity symbol
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: symbol, venue, avg_rate_bps, std_dev_bps, cv_pct, max_rate_bps, min_rate_bps
--
-- equity-vs-crypto-perps/09_equity_funding_volatility.sql
-- Measures how volatile funding rates are for each equity symbol.
-- High coefficient of variation (CV) means the funding rate is unstable,
-- which matters for strategies that hold positions across multiple
-- funding intervals.

SELECT
    symbol,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    ROUND(100.0 * STDDEV(avg_rate_bps) / NULLIF(ABS(AVG(avg_rate_bps)), 0), 2) AS cv_pct,
    ROUND(MAX(avg_rate_bps), 4) AS max_rate_bps,
    ROUND(MIN(avg_rate_bps), 4) AS min_rate_bps
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
GROUP BY symbol, venue
ORDER BY std_dev_bps DESC;
