# Acknowledgments

## Code Reuse
This project reuses key analytical components from **Delta Hedge**
(https://github.com/Nicolas-Formenton/delta-hedge), a multi-exchange delta-neutral
trading dashboard for perpetual futures (MIT licensed, Copyright 2025 Nicolas Formenton).

Specifically:
- Funding rate normalization logic adapted from `data_aggregator.py`
- Cross-venue spread calculation adapted from `opportunities.py`
- Annualized APY formula adapted from `opportunities.py`

The extracted and adapted components live in `src/extracted/`.

## Data Sources

### Binance
Historical funding rate data sourced from **Binance Public Data**
(https://data.binance.vision). Data accessed under Binance's terms of use.
Covers Jan 2020 → present for BTCUSDT, ETHUSDT, SOLUSDT.

### Hyperliquid
Funding rate data sourced from the **Hyperliquid API**
(https://api.hyperliquid.xyz/info). Covers May 2023 → present for BTC, ETH, SOL.

### Deribit
Funding rate data sourced from the **Deribit API**
(https://www.deribit.com). Covers Apr 2019 → present for BTC-PERPETUAL, ETH-PERPETUAL.

### Hyperliquid xyz (HIP-3 Equity Perps)
Equity perpetual funding data sourced from Hyperliquid's HIP-3 sub-account:
`POST https://api.hyperliquid.xyz/info` with `"type":"fundingHistory"`
covering TSLA, NVDA, MSFT, GOOGL, META, AMZN from Nov 2025 → present.

### Binance TradFi Perps
Equity perpetual funding data sourced from Binance Futures API
(https://fapi.binance.com). Covers SPYUSDT, QQQUSDT, AAPLUSDT, and 6 others.

### BitMEX
Equity perpetual instrument listings from BitMEX API
(https://www.bitmex.com). Note: BitMEX equity perps trade but have zero funding
rates as of June 2026.

## Inspiration

This project's structure was inspired by the **Olist Brazilian E-Commerce**
analytics project (https://github.com/Nicolas-Formenton/ecommerce-analytics-BI),
which demonstrated the raw → staging → marts → dashboards pattern.

## Tools

- **dbt** (https://github.com/dbt-labs/dbt-core) — data transformation
- **Deepnote** (https://deepnote.com) — interactive dashboards
- **Hex** (https://hex.tech) — research report
- **PostgreSQL** — database engine
- **Docker** — containerized infrastructure
