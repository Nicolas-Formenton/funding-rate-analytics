-- Binance: 8h, decimal rate
SELECT
    'binance' AS venue,
    symbol,
    CASE WHEN symbol IN ('BTCUSDT','ETHUSDT','SOLUSDT') THEN 'crypto' ELSE 'equity' END AS asset_class,
    ts AS interval_start,
    8 AS interval_hours,
    funding_rate AS funding_rate_raw,
    funding_rate * 3 * 365 * 100 AS funding_rate_annualized_pct,
    mark_price,
    index_price,
    CASE WHEN index_price > 0 THEN (mark_price - index_price) / index_price * 10000 ELSE NULL END AS premium_bps,
    NOW() AS _loaded_at
FROM raw.funding_binance

UNION ALL

-- Hyperliquid: hourly, decimal rate
SELECT
    'hyperliquid' AS venue,
    coin AS symbol,
    'crypto' AS asset_class,
    ts AS interval_start,
    1 AS interval_hours,
    funding_rate AS funding_rate_raw,
    funding_rate * 24 * 365 * 100 AS funding_rate_annualized_pct,
    mark_price,
    NULL AS index_price,
    NULL AS premium_bps,
    NOW() AS _loaded_at
FROM raw.funding_hyperliquid

UNION ALL

-- Deribit: 8h, percentage interest
SELECT
    'deribit' AS venue,
    REPLACE(instrument_name, '-PERPETUAL', '') || 'USDT' AS symbol,
    'crypto' AS asset_class,
    ts AS interval_start,
    8 AS interval_hours,
    interest_8h AS funding_rate_raw,
    interest_8h / 100 * 3 * 365 AS funding_rate_annualized_pct,
    mark_price,
    index_price,
    CASE WHEN index_price > 0 THEN (mark_price - index_price) / index_price * 10000 ELSE NULL END AS premium_bps,
    NOW() AS _loaded_at
FROM raw.funding_deribit

UNION ALL

-- Equity perps: variable intervals
SELECT
    venue,
    symbol,
    'equity' AS asset_class,
    ts AS interval_start,
    funding_interval_hours,
    funding_rate AS funding_rate_raw,
    CASE
        WHEN funding_interval_hours > 0
        THEN funding_rate * (24.0 / funding_interval_hours) * 365 * 100
        ELSE NULL
    END AS funding_rate_annualized_pct,
    mark_price,
    index_price,
    CASE WHEN index_price > 0 THEN (mark_price - index_price) / index_price * 10000 ELSE NULL END AS premium_bps,
    NOW() AS _loaded_at
FROM raw.funding_equity_perps