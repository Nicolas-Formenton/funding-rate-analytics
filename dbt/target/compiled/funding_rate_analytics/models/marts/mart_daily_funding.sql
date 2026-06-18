WITH daily_agg AS (
    SELECT
        venue,
        symbol,
        asset_class,
        DATE_TRUNC('day', interval_start)::DATE AS date,
        AVG(funding_rate_annualized_pct) * 100 AS avg_rate_bps,
        MIN(funding_rate_annualized_pct) * 100 AS min_rate_bps,
        MAX(funding_rate_annualized_pct) * 100 AS max_rate_bps,
        STDDEV(funding_rate_annualized_pct) * 100 AS rate_volatility,
        AVG(premium_bps) AS avg_premium_bps,
        AVG(funding_rate_annualized_pct) AS daily_annualized_yield_pct
    FROM "postgres"."staging"."stg_funding_events"
    WHERE funding_rate_annualized_pct IS NOT NULL
    GROUP BY 1, 2, 3, 4
)
SELECT
    venue,
    symbol,
    asset_class,
    date,
    avg_rate_bps,
    min_rate_bps,
    max_rate_bps,
    rate_volatility,
    avg_premium_bps,
    EXTRACT(DOW FROM date) IN (0, 6) AS is_weekend,
    daily_annualized_yield_pct
FROM daily_agg