CREATE SCHEMA IF NOT EXISTS raw;

-- Binance: 8h funding intervals, decimal rate, ms timestamps
CREATE TABLE raw.funding_binance (
    id SERIAL PRIMARY KEY,
    ts TIMESTAMPTZ NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    funding_rate NUMERIC(12,8),
    funding_time_ms BIGINT,
    mark_price NUMERIC(18,4),
    index_price NUMERIC(18,4)
);

-- Hyperliquid: hourly funding, decimal rate, funding velocity
CREATE TABLE raw.funding_hyperliquid (
    id SERIAL PRIMARY KEY,
    ts TIMESTAMPTZ NOT NULL,
    coin VARCHAR(10) NOT NULL,
    funding_rate NUMERIC(12,8),
    funding_velocity NUMERIC(14,6),
    mark_price NUMERIC(18,4),
    open_interest NUMERIC(18,4)
);

-- Deribit: 8h interest, percentage format
CREATE TABLE raw.funding_deribit (
    id SERIAL PRIMARY KEY,
    ts TIMESTAMPTZ NOT NULL,
    instrument_name VARCHAR(30) NOT NULL,
    interest_8h NUMERIC(12,8),
    interest_1h NUMERIC(12,8),
    mark_price NUMERIC(18,4),
    index_price NUMERIC(18,4)
);

-- Equity perps: mixed venues, variable intervals
CREATE TABLE raw.funding_equity_perps (
    id SERIAL PRIMARY KEY,
    ts TIMESTAMPTZ NOT NULL,
    venue VARCHAR(20) NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    funding_rate NUMERIC(12,8),
    funding_interval_hours NUMERIC(6,2),
    mark_price NUMERIC(18,4),
    index_price NUMERIC(18,4)
);
