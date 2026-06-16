# Funding Rate Normalization Rules

This document describes how funding rates from different venues are normalized to a common annualized percentage format for comparison.

## Overview

Each venue reports funding rates in different formats and intervals. To enable cross-venue analysis, all rates are normalized to **annualized percentage rates (APR)** in the staging layer.

## Normalization Formulas

### Binance (8-hour intervals, decimal format)

**Source format:** Decimal rate (e.g., 0.0001 = 0.01%)  
**Interval:** 8 hours (3 times per day)

**Formula:**
```
funding_rate_annualized_pct = funding_rate × 3 × 365 × 100
```

**Breakdown:**
- `× 3` — Convert 8-hour rate to daily rate (24h / 8h = 3 intervals per day)
- `× 365` — Convert daily rate to annual rate
- `× 100` — Convert decimal to percentage

**Example:**
- Input: `0.0001` (0.01% per 8h)
- Output: `0.0001 × 3 × 365 × 100 = 10.95%` APR

---

### Hyperliquid (hourly intervals, decimal format)

**Source format:** Decimal rate (e.g., 0.00005 = 0.005%)  
**Interval:** 1 hour (24 times per day)

**Formula:**
```
funding_rate_annualized_pct = funding_rate × 24 × 365 × 100
```

**Breakdown:**
- `× 24` — Convert hourly rate to daily rate (24h / 1h = 24 intervals per day)
- `× 365` — Convert daily rate to annual rate
- `× 100` — Convert decimal to percentage

**Example:**
- Input: `0.00005` (0.005% per hour)
- Output: `0.00005 × 24 × 365 × 100 = 4.38%` APR

---

### Deribit (8-hour intervals, percentage format)

**Source format:** Percentage rate (e.g., 0.01 = 0.01%)  
**Interval:** 8 hours (3 times per day)

**Formula:**
```
funding_rate_annualized_pct = (interest_8h / 100) × 3 × 365
```

**Breakdown:**
- `/ 100` — Convert percentage to decimal
- `× 3` — Convert 8-hour rate to daily rate (24h / 8h = 3 intervals per day)
- `× 365` — Convert daily rate to annual rate

**Example:**
- Input: `0.01` (0.01% per 8h)
- Output: `(0.01 / 100) × 3 × 365 = 0.1095%` APR

---

### Equity Perps (variable intervals, decimal format)

**Source format:** Decimal rate (e.g., 0.0002 = 0.02%)  
**Interval:** Variable (specified in `funding_interval_hours`)

**Formula:**
```
funding_rate_annualized_pct = funding_rate × (24 / interval_hours) × 365 × 100
```

**Breakdown:**
- `× (24 / interval_hours)` — Convert interval rate to daily rate
- `× 365` — Convert daily rate to annual rate
- `× 100` — Convert decimal to percentage

**Example:**
- Input: `0.0002` (0.02% per 4h interval)
- Output: `0.0002 × (24 / 4) × 365 × 100 = 43.8%` APR

---

## Premium Calculation

For venues that provide both mark price and index price, we calculate the premium in basis points:

**Formula:**
```
premium_bps = (mark_price - index_price) / index_price × 10000
```

**Breakdown:**
- `(mark_price - index_price) / index_price` — Calculate relative premium as decimal
- `× 10000` — Convert to basis points (1 bps = 0.01%)

**Example:**
- Mark price: `$50,100`
- Index price: `$50,000`
- Output: `(50100 - 50000) / 50000 × 10000 = 20 bps`

---

## Asset Classification

The staging layer adds an `asset_class` discriminator column:

- **crypto** — Cryptocurrency perpetual futures (BTC, ETH, SOL, etc.)
- **equity** — Equity perpetual futures (stock perps)

This allows filtering and aggregation by asset class in downstream marts.

---

## Negative Funding Rates

**Important:** Negative funding rates are valid and represent shorts paying longs. The schema tests allow rates in the range `-500%` to `+500%` APR to accommodate extreme market conditions.

Do NOT filter out negative rates — they are signal, not errors.
