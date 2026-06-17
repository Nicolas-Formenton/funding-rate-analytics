CREATE SCHEMA IF NOT EXISTS marts;

-- mart_hourly_funding: hourly aggregates
CREATE TABLE marts.mart_hourly_funding (
    id SERIAL PRIMARY KEY,
    venue VARCHAR(20) NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    asset_class VARCHAR(10) NOT NULL,
    hour_start TIMESTAMPTZ NOT NULL,
    avg_rate_bps NUMERIC(12,4),
    min_rate_bps NUMERIC(12,4),
    max_rate_bps NUMERIC(12,4),
    rate_stddev NUMERIC(12,4),
    sample_count INTEGER,
    avg_premium_bps NUMERIC(12,4),
    avg_mark_price NUMERIC(18,4),
    avg_index_price NUMERIC(18,4)
);

-- mart_daily_funding: daily aggregates
CREATE TABLE marts.mart_daily_funding (
    id SERIAL PRIMARY KEY,
    venue VARCHAR(20) NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    asset_class VARCHAR(10) NOT NULL,
    date DATE NOT NULL,
    avg_rate_bps NUMERIC(12,4),
    min_rate_bps NUMERIC(12,4),
    max_rate_bps NUMERIC(12,4),
    rate_volatility NUMERIC(12,4),
    avg_premium_bps NUMERIC(12,4),
    is_weekend BOOLEAN,
    daily_annualized_yield_pct NUMERIC(12,4)
);

-- mart_venue_comparison: cross-venue spread (long format, one row per venue pair)
CREATE TABLE marts.mart_venue_comparison (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    asset_class VARCHAR(10) NOT NULL,
    venue_long VARCHAR(20) NOT NULL,
    venue_short VARCHAR(20) NOT NULL,
    long_rate_bps NUMERIC(12,4),
    short_rate_bps NUMERIC(12,4),
    spread_bps NUMERIC(12,4),
    arb_apy_pct NUMERIC(12,4)
);
