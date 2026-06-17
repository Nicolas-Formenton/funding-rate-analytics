-- Long-format cross-venue comparison: one row per date/symbol/venue_pair
-- venue_long  = venue with lower funding rate (go long here)
-- venue_short = venue with higher funding rate (go short here)
-- spread_bps  = absolute spread in basis points
-- arb_apy_pct = spread converted to percentage (bps / 100)

WITH daily AS (
    SELECT * FROM {{ ref('mart_daily_funding') }}
),

-- Normalize symbols across venues: strip USDT suffix so BTCUSDT/BTC both become BTC
normalized AS (
    SELECT
        date,
        REPLACE(symbol, 'USDT', '') AS symbol,
        venue,
        asset_class,
        avg_rate_bps
    FROM daily
    WHERE avg_rate_bps IS NOT NULL
),

-- Generate all unique venue pairs (self-join, venue_a < venue_b to avoid duplicates)
pairs AS (
    SELECT
        a.date,
        a.symbol,
        COALESCE(a.asset_class, b.asset_class) AS asset_class,
        -- venue_long = lower rate (go long), venue_short = higher rate (go short)
        CASE WHEN a.avg_rate_bps <= b.avg_rate_bps THEN a.venue ELSE b.venue END AS venue_long,
        CASE WHEN a.avg_rate_bps >  b.avg_rate_bps THEN a.venue ELSE b.venue END AS venue_short,
        LEAST(a.avg_rate_bps, b.avg_rate_bps)  AS long_rate_bps,
        GREATEST(a.avg_rate_bps, b.avg_rate_bps) AS short_rate_bps,
        ABS(a.avg_rate_bps - b.avg_rate_bps)   AS spread_bps
    FROM normalized a
    JOIN normalized b
        ON  a.date   = b.date
        AND a.symbol  = b.symbol
        AND a.venue   < b.venue   -- alphabetical dedup: each pair appears once
)

SELECT
    date,
    symbol,
    asset_class,
    venue_long,
    venue_short,
    long_rate_bps,
    short_rate_bps,
    ROUND(spread_bps, 4)           AS spread_bps,
    ROUND(spread_bps / 100.0, 2)  AS arb_apy_pct
FROM pairs
