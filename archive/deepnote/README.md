# Deepnote Notebooks — Archived

This directory contains the original Deepnote notebook-based dashboards that powered the Funding Rate Analytics project.

## Contents

| File | Description |
|------|-------------|
| `dashboard_1_overview.ipynb` | Funding Rate Overview — rate trends by venue/symbol, top events, volatility, distribution |
| `dashboard_2_spread.ipynb` | Cross-Venue Spread Analysis — arbitrage detection, correlation matrix, spread over time |
| `dashboard_3_equity.ipynb` | Equity vs Crypto Perps — weekend oracle freeze, hourly patterns, regulatory comparison |
| `dashboard_4_yield.ipynb` | Annualized Yield Analysis — cumulative yield, risk-return, seasonality, negative funding |
| `generate_notebooks.py` | Script that generated the above notebooks programmatically |

## Context

These notebooks were developed in [Deepnote](https://deepnote.com) as interactive BI dashboards with SQL blocks and Plotly visualizations. They have been **superseded by Apache Superset** dashboards, which provide:

- Self-hosted, always-on dashboards (no cloud dependency)
- Native SQL IDE with saved query library
- Rich chart library (including time-series, heatmaps, distributions)
- Scheduled refresh and alerting capabilities
- Embedded chart support for portfolio sharing

## Migration

The 51 SQL queries that powered these dashboards remain in `sql/` and are fully compatible with Superset's SQL Lab. The Superset dashboards serve the same analytical content with improved reliability and lower latency.

All credit for the original analytical design belongs to the Deepnote implementation.
