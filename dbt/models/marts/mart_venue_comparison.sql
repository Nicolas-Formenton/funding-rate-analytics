WITH daily AS (
    SELECT * FROM {{ ref('mart_daily_funding') }}
),
binance AS (
    SELECT date, symbol, asset_class, avg_rate_bps
    FROM daily WHERE venue = 'binance'
),
hyperliquid AS (
    SELECT date, symbol, asset_class, avg_rate_bps
    FROM daily WHERE venue = 'hyperliquid'
),
deribit AS (
    SELECT date, symbol, asset_class, avg_rate_bps
    FROM daily WHERE venue = 'deribit'
)
SELECT
    COALESCE(b.date, h.date, d.date) AS date,
    COALESCE(b.symbol, h.symbol, d.symbol) AS symbol,
    COALESCE(b.asset_class, h.asset_class, d.asset_class) AS asset_class,
    b.avg_rate_bps AS binance_rate_bps,
    h.avg_rate_bps AS hyperliquid_rate_bps,
    d.avg_rate_bps AS deribit_rate_bps,
    GREATEST(
        COALESCE(ABS(b.avg_rate_bps - h.avg_rate_bps), 0),
        COALESCE(ABS(b.avg_rate_bps - d.avg_rate_bps), 0),
        COALESCE(ABS(h.avg_rate_bps - d.avg_rate_bps), 0)
    ) AS max_cross_spread_bps,
    CASE
        WHEN ABS(COALESCE(b.avg_rate_bps, 0) - COALESCE(h.avg_rate_bps, 0))
            >= GREATEST(
                COALESCE(ABS(b.avg_rate_bps - d.avg_rate_bps), 0),
                COALESCE(ABS(h.avg_rate_bps - d.avg_rate_bps), 0)
            )
            THEN 'binance-hyperliquid'
        WHEN ABS(COALESCE(b.avg_rate_bps, 0) - COALESCE(d.avg_rate_bps, 0))
            >= COALESCE(ABS(h.avg_rate_bps - d.avg_rate_bps), 0)
            THEN 'binance-deribit'
        ELSE 'hyperliquid-deribit'
    END AS arb_venue_pair,
    0 AS arb_apy_pct
FROM binance b
FULL OUTER JOIN hyperliquid h
    ON b.date = h.date AND b.symbol = h.symbol
FULL OUTER JOIN deribit d
    ON COALESCE(b.date, h.date) = d.date
    AND COALESCE(b.symbol, h.symbol) = d.symbol
