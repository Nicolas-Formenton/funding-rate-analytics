SELECT
    venue,
    symbol,
    asset_class,
    DATE_TRUNC('hour', interval_start) AS hour_start,
    AVG(funding_rate_annualized_pct) * 100 AS avg_rate_bps,
    MIN(funding_rate_annualized_pct) * 100 AS min_rate_bps,
    MAX(funding_rate_annualized_pct) * 100 AS max_rate_bps,
    STDDEV(funding_rate_annualized_pct) * 100 AS rate_stddev,
    COUNT(*) AS sample_count,
    AVG(premium_bps) AS avg_premium_bps,
    AVG(mark_price) AS avg_mark_price,
    AVG(index_price) AS avg_index_price
FROM "funding_rates"."staging_staging"."stg_funding_events"
WHERE funding_rate_annualized_pct IS NOT NULL
GROUP BY 1, 2, 3, 4