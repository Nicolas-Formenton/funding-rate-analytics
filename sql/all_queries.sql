-- =============================================================================
-- ALL QUERIES — Funding Rate Analytics
-- Generated: 2026-06-16
-- Total queries: 51
-- Dashboards: Funding Rate Overview, Cross-Venue Spread, Equity vs Crypto Perps, Annualized Yield
-- Source tables: marts.mart_daily_funding, marts.mart_hourly_funding, marts.mart_venue_comparison
-- =============================================================================

-- =============================================================================
-- DASHBOARD: funding rate overview
-- =============================================================================

-- -----------------------------------------------------------------------------
-- FILE: funding-rate-overview/01_daily_funding_by_venue.sql
-- -----------------------------------------------------------------------------
-- Purpose: Average daily funding rate by venue for last 12 months
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: venue, symbol, date, avg_rate_bps
--
-- funding-rate-overview/01_daily_funding_by_venue.sql
-- Shows the daily average funding rate in basis points for each venue,
-- filtered to the last 12 months. Used as the primary time-series chart
-- on the Funding Rate Overview dashboard.

SELECT
    venue,
    symbol,
    date,
    avg_rate_bps
FROM marts.mart_daily_funding
WHERE date >= CURRENT_DATE - INTERVAL '12 months'
ORDER BY date DESC, venue, symbol;


-- -----------------------------------------------------------------------------
-- FILE: funding-rate-overview/02_daily_funding_by_symbol.sql
-- -----------------------------------------------------------------------------
-- Purpose: Average daily funding rate by symbol for last 12 months
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: symbol, date, avg_rate_bps
--
-- funding-rate-overview/02_daily_funding_by_symbol.sql
-- Aggregates daily funding rates across all venues per symbol.
-- Lets users track how a specific symbol's funding rate evolves over time
-- regardless of which venue it trades on.

SELECT
    symbol,
    date,
    AVG(avg_rate_bps) AS avg_rate_bps
FROM marts.mart_daily_funding
WHERE date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY symbol, date
ORDER BY date DESC, symbol;


-- -----------------------------------------------------------------------------
-- FILE: funding-rate-overview/03_top10_highest_funding_days.sql
-- -----------------------------------------------------------------------------
-- Purpose: Top 10 highest funding rate days across all venues and symbols
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: date, venue, symbol, avg_rate_bps, asset_class
--
-- funding-rate-overview/03_top10_highest_funding_days.sql
-- Identifies the most extreme positive funding events.
-- Useful for spotting when shorts were paying the most and
-- when funding rate spikes occurred.

SELECT
    date,
    venue,
    symbol,
    avg_rate_bps,
    asset_class
FROM marts.mart_daily_funding
ORDER BY avg_rate_bps DESC
LIMIT 10;


-- -----------------------------------------------------------------------------
-- FILE: funding-rate-overview/04_summary_stats_by_venue.sql
-- -----------------------------------------------------------------------------
-- Purpose: Summary statistics (avg, median, p5, p95) by venue
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: venue, avg_rate_bps, median_rate_bps, p5_rate_bps, p95_rate_bps, observation_count
--
-- funding-rate-overview/04_summary_stats_by_venue.sql
-- Provides a statistical profile for each venue.
-- The percentile breakdown shows the distribution shape and
-- helps identify which venues have wider funding rate spreads.

SELECT
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    ROUND(PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS p5_rate_bps,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS p95_rate_bps,
    COUNT(*) AS observation_count
FROM marts.mart_daily_funding
GROUP BY venue
ORDER BY avg_rate_bps DESC;


-- -----------------------------------------------------------------------------
-- FILE: funding-rate-overview/05_monthly_funding_trend.sql
-- -----------------------------------------------------------------------------
-- Purpose: Monthly average funding rate by venue
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: year_month, venue, avg_rate_bps, observation_count
--
-- funding-rate-overview/05_monthly_funding_trend.sql
-- Aggregates daily rates into monthly buckets per venue.
-- Smooths out daily noise to reveal medium-term trends
-- in funding rate behavior across exchanges.

SELECT
    TO_CHAR(DATE_TRUNC('month', date), 'YYYY-MM') AS year_month,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    COUNT(*) AS observation_count
FROM marts.mart_daily_funding
GROUP BY DATE_TRUNC('month', date), venue
ORDER BY year_month DESC, venue;


-- -----------------------------------------------------------------------------
-- FILE: funding-rate-overview/06_funding_distribution_by_venue.sql
-- -----------------------------------------------------------------------------
-- Purpose: Histogram data for funding rate distribution by venue
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: venue, rate_bucket, observation_count, pct_of_venue
--
-- funding-rate-overview/06_funding_distribution_by_venue.sql
-- Bins funding rates into 1 bp-wide buckets for histogram visualization.
-- Shows how rates cluster around zero and how fat the tails are
-- for each venue.

WITH bounds AS (
    SELECT
        FLOOR(MIN(avg_rate_bps)) AS min_bucket,
        CEIL(MAX(avg_rate_bps)) AS max_bucket
    FROM marts.mart_daily_funding
),
bucketed AS (
    SELECT
        venue,
        FLOOR(avg_rate_bps)::int AS rate_bucket,
        COUNT(*) AS observation_count
    FROM marts.mart_daily_funding
    GROUP BY venue, FLOOR(avg_rate_bps)::int
)
SELECT
    venue,
    rate_bucket,
    observation_count,
    ROUND(100.0 * observation_count / SUM(observation_count) OVER (PARTITION BY venue), 2) AS pct_of_venue
FROM bucketed
ORDER BY venue, rate_bucket;


-- -----------------------------------------------------------------------------
-- FILE: funding-rate-overview/07_venue_rankings.sql
-- -----------------------------------------------------------------------------
-- Purpose: Venue comparison ranked by average funding rate
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: venue_rank, venue, avg_rate_bps, total_symbols, total_days, first_date, last_date
--
-- funding-rate-overview/07_venue_rankings.sql
-- Ranks venues by their overall average funding rate.
-- Includes coverage metadata so users can see how many symbols
-- and days of data each venue contributes.

SELECT
    RANK() OVER (ORDER BY AVG(avg_rate_bps) DESC) AS venue_rank,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    COUNT(DISTINCT symbol) AS total_symbols,
    COUNT(DISTINCT date) AS total_days,
    MIN(date) AS first_date,
    MAX(date) AS last_date
FROM marts.mart_daily_funding
GROUP BY venue
ORDER BY venue_rank;


-- -----------------------------------------------------------------------------
-- FILE: funding-rate-overview/08_yearly_summary.sql
-- -----------------------------------------------------------------------------
-- Purpose: Yearly aggregates by venue
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: year, venue, avg_rate_bps, max_rate_bps, min_rate_bps, total_days
--
-- funding-rate-overview/08_yearly_summary.sql
-- Rolls up daily funding data into yearly summaries per venue.
-- Gives a high-level view of how funding rate regimes shift year over year.

SELECT
    EXTRACT(YEAR FROM date)::int AS year,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(MAX(avg_rate_bps), 4) AS max_rate_bps,
    ROUND(MIN(avg_rate_bps), 4) AS min_rate_bps,
    COUNT(DISTINCT date) AS total_days
FROM marts.mart_daily_funding
GROUP BY EXTRACT(YEAR FROM date), venue
ORDER BY year DESC, venue;


-- -----------------------------------------------------------------------------
-- FILE: funding-rate-overview/09_crypto_perps_overview.sql
-- -----------------------------------------------------------------------------
-- Purpose: All crypto perpetuals summary overview
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: symbol, venue, avg_rate_bps, median_rate_bps, std_dev_bps, total_days, first_date, last_date
--
-- funding-rate-overview/09_crypto_perps_overview.sql
-- Filters to crypto asset class only and provides a per-symbol,
-- per-venue summary. Lets users quickly see which crypto perps
-- have the highest sustained funding rates.

SELECT
    symbol,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    COUNT(DISTINCT date) AS total_days,
    MIN(date) AS first_date,
    MAX(date) AS last_date
FROM marts.mart_daily_funding
WHERE asset_class = 'crypto'
GROUP BY symbol, venue
ORDER BY avg_rate_bps DESC;


-- -----------------------------------------------------------------------------
-- FILE: funding-rate-overview/10_funding_rate_volatility.sql
-- -----------------------------------------------------------------------------
-- Purpose: Funding rate volatility by venue (30-day rolling standard deviation)
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: date, venue, rolling_stddev_30d, rolling_avg_30d
--
-- funding-rate-overview/10_funding_rate_volatility.sql
-- Computes a 30-day rolling standard deviation of funding rates per venue.
-- High volatility signals unstable funding regimes, which matters
-- for strategies that hold positions across funding intervals.

SELECT
    date,
    venue,
    ROUND(STDDEV(avg_rate_bps) OVER w, 4) AS rolling_stddev_30d,
    ROUND(AVG(avg_rate_bps) OVER w, 4) AS rolling_avg_30d
FROM marts.mart_daily_funding
WINDOW w AS (
    PARTITION BY venue
    ORDER BY date
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
)
ORDER BY date DESC, venue;


-- -----------------------------------------------------------------------------
-- FILE: funding-rate-overview/11_extreme_funding_events.sql
-- -----------------------------------------------------------------------------
-- Purpose: Extreme funding events where rate falls outside 2-sigma band
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: date, venue, symbol, avg_rate_bps, venue_mean, venue_stddev, z_score
--
-- funding-rate-overview/11_extreme_funding_events.sql
-- Flags daily rates that deviate more than 2 standard deviations
-- from the venue-level mean. These are statistical outliers that
-- often correspond to squeezes, liquidation cascades, or data anomalies.

WITH venue_stats AS (
    SELECT
        venue,
        AVG(avg_rate_bps) AS venue_mean,
        STDDEV(avg_rate_bps) AS venue_stddev
    FROM marts.mart_daily_funding
    GROUP BY venue
)
SELECT
    f.date,
    f.venue,
    f.symbol,
    f.avg_rate_bps,
    ROUND(s.venue_mean, 4) AS venue_mean,
    ROUND(s.venue_stddev, 4) AS venue_stddev,
    ROUND((f.avg_rate_bps - s.venue_mean) / NULLIF(s.venue_stddev, 0), 2) AS z_score
FROM marts.mart_daily_funding f
JOIN venue_stats s ON f.venue = s.venue
WHERE ABS(f.avg_rate_bps - s.venue_mean) > 2 * s.venue_stddev
ORDER BY ABS((f.avg_rate_bps - s.venue_mean) / NULLIF(s.venue_stddev, 0)) DESC;


-- -----------------------------------------------------------------------------
-- FILE: funding-rate-overview/12_asset_class_comparison.sql
-- -----------------------------------------------------------------------------
-- Purpose: Crypto vs equity asset class summary statistics
-- Dashboard: Funding Rate Overview
-- Source: marts.mart_daily_funding
-- Columns: asset_class, avg_rate_bps, median_rate_bps, p5_rate_bps, p95_rate_bps, std_dev_bps, total_observations
--
-- funding-rate-overview/12_asset_class_comparison.sql
-- Compares the overall funding rate distribution between crypto and equity perps.
-- Answers the question: do equity perps systematically pay more or less
-- than crypto perps?

SELECT
    asset_class,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    ROUND(PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS p5_rate_bps,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS p95_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    COUNT(*) AS total_observations
FROM marts.mart_daily_funding
GROUP BY asset_class
ORDER BY asset_class;


-- =============================================================================
-- DASHBOARD: cross venue spread
-- =============================================================================

-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/01_binance_vs_hyperliquid_spread.sql
-- -----------------------------------------------------------------------------
-- Purpose: Binance vs Hyperliquid funding rate spread over time
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, symbol, binance_rate_bps, hyperliquid_rate_bps, spread_bps
--
-- cross-venue-spread/01_binance_vs_hyperliquid_spread.sql
-- Tracks the funding rate differential between Binance and Hyperliquid
-- for each shared symbol over time. Positive spread means Hyperliquid
-- pays more than Binance.

SELECT
    date,
    symbol,
    MAX(CASE WHEN venue = 'binance' THEN avg_rate_bps END) AS binance_rate_bps,
    MAX(CASE WHEN venue = 'hyperliquid' THEN avg_rate_bps END) AS hyperliquid_rate_bps,
    MAX(CASE WHEN venue = 'hyperliquid' THEN avg_rate_bps END)
      - MAX(CASE WHEN venue = 'binance' THEN avg_rate_bps END) AS spread_bps
FROM marts.mart_daily_funding
WHERE venue IN ('binance', 'hyperliquid')
GROUP BY date, symbol
HAVING COUNT(DISTINCT venue) = 2
ORDER BY date DESC, symbol;


-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/02_binance_vs_deribit_spread.sql
-- -----------------------------------------------------------------------------
-- Purpose: Binance vs Deribit funding rate spread over time
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, symbol, binance_rate_bps, deribit_rate_bps, spread_bps
--
-- cross-venue-spread/02_binance_vs_deribit_spread.sql
-- Tracks the funding rate differential between Binance and Deribit.
-- Deribit is options-focused, so this spread reveals how perps pricing
-- diverges between a generalist and a specialist venue.

SELECT
    date,
    symbol,
    MAX(CASE WHEN venue = 'binance' THEN avg_rate_bps END) AS binance_rate_bps,
    MAX(CASE WHEN venue = 'deribit' THEN avg_rate_bps END) AS deribit_rate_bps,
    MAX(CASE WHEN venue = 'deribit' THEN avg_rate_bps END)
      - MAX(CASE WHEN venue = 'binance' THEN avg_rate_bps END) AS spread_bps
FROM marts.mart_daily_funding
WHERE venue IN ('binance', 'deribit')
GROUP BY date, symbol
HAVING COUNT(DISTINCT venue) = 2
ORDER BY date DESC, symbol;


-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/03_arb_opportunities.sql
-- -----------------------------------------------------------------------------
-- Purpose: Arbitrage opportunities where annualized arb APY exceeds 10%
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, symbol, venue_long, venue_short, spread_bps, arb_apy_pct
--
-- cross-venue-spread/03_arb_opportunities.sql
-- Identifies days where the cross-venue funding rate spread
-- annualizes to more than 10%. These are actionable funding rate
-- arbitrage windows: long funding on the cheaper venue, short on the expensive one.

SELECT
    date,
    symbol,
    venue_long,
    venue_short,
    spread_bps,
    ROUND(spread_bps * 3.65, 2) AS arb_apy_pct
FROM marts.mart_venue_comparison
WHERE spread_bps * 3.65 > 10.0
ORDER BY arb_apy_pct DESC, date DESC;


-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/04_correlation_matrix.sql
-- -----------------------------------------------------------------------------
-- Purpose: Funding rate correlation matrix across venues
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_daily_funding
-- Columns: venue_a, venue_b, correlation, shared_symbols, shared_days
--
-- cross-venue-spread/04_correlation_matrix.sql
-- Computes pairwise Pearson correlation of daily funding rates
-- between all venue pairs. High correlation means venues move together;
-- low correlation means more arb opportunity.

WITH venue_pairs AS (
    SELECT DISTINCT
        LEAST(a.venue, b.venue) AS venue_a,
        GREATEST(a.venue, b.venue) AS venue_b
    FROM marts.mart_daily_funding a
    JOIN marts.mart_daily_funding b
        ON a.symbol = b.symbol AND a.date = b.date AND a.venue < b.venue
)
SELECT
    vp.venue_a,
    vp.venue_b,
    ROUND(CORR(a.avg_rate_bps, b.avg_rate_bps), 4) AS correlation,
    COUNT(DISTINCT a.symbol) AS shared_symbols,
    COUNT(*) AS shared_days
FROM venue_pairs vp
JOIN marts.mart_daily_funding a
    ON a.venue = vp.venue_a
JOIN marts.mart_daily_funding b
    ON b.venue = vp.venue_b AND b.symbol = a.symbol AND b.date = a.date
GROUP BY vp.venue_a, vp.venue_b
ORDER BY correlation DESC;


-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/05_rolling_30d_avg_spread.sql
-- -----------------------------------------------------------------------------
-- Purpose: Rolling 30-day average spread by venue pair
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, venue_long, venue_short, rolling_avg_spread_30d
--
-- cross-venue-spread/05_rolling_30d_avg_spread.sql
-- Smooths daily cross-venue spreads with a 30-day rolling average.
-- Reveals persistent structural spreads vs transient spikes.

SELECT
    date,
    venue_long,
    venue_short,
    ROUND(AVG(spread_bps) OVER (
        PARTITION BY venue_long, venue_short
        ORDER BY date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 4) AS rolling_avg_spread_30d
FROM marts.mart_venue_comparison
ORDER BY date DESC, venue_long, venue_short;


-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/06_max_spread_by_date.sql
-- -----------------------------------------------------------------------------
-- Purpose: Daily maximum cross-venue spread across all venue pairs
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, max_spread_bps, venue_long, venue_short, symbol
--
-- cross-venue-spread/06_max_spread_by_date.sql
-- For each day, finds the single largest funding rate spread
-- across all venue pairs and symbols. Highlights the best
-- arb opportunity available on any given day.

SELECT
    date,
    MAX(spread_bps) AS max_spread_bps,
    (ARRAY_AGG(venue_long ORDER BY spread_bps DESC))[1] AS venue_long,
    (ARRAY_AGG(venue_short ORDER BY spread_bps DESC))[1] AS venue_short,
    (ARRAY_AGG(symbol ORDER BY spread_bps DESC))[1] AS symbol
FROM marts.mart_venue_comparison
GROUP BY date
ORDER BY date DESC;


-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/07_spread_distribution.sql
-- -----------------------------------------------------------------------------
-- Purpose: Histogram of cross-venue spread values
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: spread_bucket, observation_count, pct_of_total
--
-- cross-venue-spread/07_spread_distribution.sql
-- Bins spread values into 1 bp-wide buckets to show the distribution shape.
-- Most spreads should cluster near zero; the tails show how often
-- large arb opportunities appear.

WITH bucketed AS (
    SELECT
        FLOOR(spread_bps)::int AS spread_bucket,
        COUNT(*) AS observation_count
    FROM marts.mart_venue_comparison
    GROUP BY FLOOR(spread_bps)::int
),
total AS (
    SELECT SUM(observation_count) AS grand_total FROM bucketed
)
SELECT
    spread_bucket,
    observation_count,
    ROUND(100.0 * observation_count / grand_total, 2) AS pct_of_total
FROM bucketed, total
ORDER BY spread_bucket;


-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/08_venue_pair_rankings.sql
-- -----------------------------------------------------------------------------
-- Purpose: Venue pair rankings by average spread
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: pair_rank, venue_long, venue_short, avg_spread_bps, max_spread_bps, observation_count
--
-- cross-venue-spread/08_venue_pair_rankings.sql
-- Ranks all venue pairs by their average funding rate spread.
-- The top pairs are the most structurally mispriced and
-- offer the best persistent arb opportunities.

SELECT
    RANK() OVER (ORDER BY AVG(spread_bps) DESC) AS pair_rank,
    venue_long,
    venue_short,
    ROUND(AVG(spread_bps), 4) AS avg_spread_bps,
    ROUND(MAX(spread_bps), 4) AS max_spread_bps,
    COUNT(*) AS observation_count
FROM marts.mart_venue_comparison
GROUP BY venue_long, venue_short
ORDER BY pair_rank;


-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/09_weekly_spread_patterns.sql
-- -----------------------------------------------------------------------------
-- Purpose: Day-of-week spread patterns
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: day_of_week, day_name, avg_spread_bps, median_spread_bps, observation_count
--
-- cross-venue-spread/09_weekly_spread_patterns.sql
-- Checks whether cross-venue spreads behave differently on specific days.
-- Weekends might show wider spreads for equity perps due to oracle freezes,
-- while crypto perps should be more uniform across the week.

SELECT
    EXTRACT(DOW FROM date)::int AS day_of_week,
    CASE EXTRACT(DOW FROM date)::int
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    ROUND(AVG(spread_bps), 4) AS avg_spread_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY spread_bps), 4) AS median_spread_bps,
    COUNT(*) AS observation_count
FROM marts.mart_venue_comparison
GROUP BY EXTRACT(DOW FROM date)::int
ORDER BY day_of_week;


-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/10_monthly_spread_trends.sql
-- -----------------------------------------------------------------------------
-- Purpose: Monthly evolution of cross-venue spreads
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: year_month, avg_spread_bps, max_spread_bps, venue_long, venue_short
--
-- cross-venue-spread/10_monthly_spread_trends.sql
-- Aggregates spreads into monthly buckets per venue pair.
-- Shows whether arb opportunities are expanding or contracting
-- over time as markets mature.

SELECT
    TO_CHAR(DATE_TRUNC('month', date), 'YYYY-MM') AS year_month,
    venue_long,
    venue_short,
    ROUND(AVG(spread_bps), 4) AS avg_spread_bps,
    ROUND(MAX(spread_bps), 4) AS max_spread_bps,
    COUNT(*) AS observation_count
FROM marts.mart_venue_comparison
GROUP BY DATE_TRUNC('month', date), venue_long, venue_short
ORDER BY year_month DESC, venue_long, venue_short;


-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/11_top_arb_days.sql
-- -----------------------------------------------------------------------------
-- Purpose: Top 20 arbitrage opportunity days by annualized APY
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, symbol, venue_long, venue_short, spread_bps, arb_apy_pct
--
-- cross-venue-spread/11_top_arb_days.sql
-- Ranks the best 20 days for cross-venue funding rate arbitrage.
-- Annualizes the daily spread to show the equivalent APY
-- if the opportunity persisted for a full year.

SELECT
    date,
    symbol,
    venue_long,
    venue_short,
    spread_bps,
    ROUND(spread_bps * 3.65, 2) AS arb_apy_pct
FROM marts.mart_venue_comparison
ORDER BY arb_apy_pct DESC
LIMIT 20;


-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/12_hyperliquid_vs_deribit_spread.sql
-- -----------------------------------------------------------------------------
-- Purpose: Hyperliquid vs Deribit funding rate spread over time
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, symbol, hyperliquid_rate_bps, deribit_rate_bps, spread_bps
--
-- cross-venue-spread/12_hyperliquid_vs_deribit_spread.sql
-- Compares funding rates between Hyperliquid (a DEX) and Deribit
-- (an options-focused CEX). Interesting because these venues
-- have very different market microstructures.

SELECT
    date,
    symbol,
    MAX(CASE WHEN venue = 'hyperliquid' THEN avg_rate_bps END) AS hyperliquid_rate_bps,
    MAX(CASE WHEN venue = 'deribit' THEN avg_rate_bps END) AS deribit_rate_bps,
    MAX(CASE WHEN venue = 'hyperliquid' THEN avg_rate_bps END)
      - MAX(CASE WHEN venue = 'deribit' THEN avg_rate_bps END) AS spread_bps
FROM marts.mart_daily_funding
WHERE venue IN ('hyperliquid', 'deribit')
GROUP BY date, symbol
HAVING COUNT(DISTINCT venue) = 2
ORDER BY date DESC, symbol;


-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/13_crypto_spreads_only.sql
-- -----------------------------------------------------------------------------
-- Purpose: Cross-venue spreads for crypto symbols only
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: date, symbol, venue_long, venue_short, spread_bps, arb_apy_pct
--
-- cross-venue-spread/13_crypto_spreads_only.sql
-- Filters the venue comparison mart to crypto symbols.
-- Crypto perps trade 24/7 across all venues, so spreads here
-- reflect pure market microstructure differences rather than
-- structural factors like oracle freezes.

SELECT
    date,
    symbol,
    venue_long,
    venue_short,
    spread_bps,
    ROUND(spread_bps * 3.65, 2) AS arb_apy_pct
FROM marts.mart_venue_comparison
WHERE asset_class = 'crypto'
ORDER BY date DESC, spread_bps DESC;


-- -----------------------------------------------------------------------------
-- FILE: cross-venue-spread/14_spread_vs_volatility.sql
-- -----------------------------------------------------------------------------
-- Purpose: Spread vs funding rate volatility scatter data
-- Dashboard: Cross-Venue Spread
-- Source: marts.mart_venue_comparison
-- Columns: symbol, venue_long, venue_short, avg_spread_bps, spread_stddev, avg_rate_bps, rate_stddev
--
-- cross-venue-spread/14_spread_vs_volatility.sql
-- For each venue pair and symbol, computes both the average spread
-- and the volatility of both the spread and the underlying rates.
-- Used as scatter plot data to explore whether more volatile symbols
-- have wider cross-venue spreads.

SELECT
    symbol,
    venue_long,
    venue_short,
    ROUND(AVG(spread_bps), 4) AS avg_spread_bps,
    ROUND(STDDEV(spread_bps), 4) AS spread_stddev,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS rate_stddev
FROM marts.mart_venue_comparison
GROUP BY symbol, venue_long, venue_short
ORDER BY avg_spread_bps DESC;


-- =============================================================================
-- DASHBOARD: equity vs crypto perps
-- =============================================================================

-- -----------------------------------------------------------------------------
-- FILE: equity-vs-crypto-perps/01_equity_funding_over_time.sql
-- -----------------------------------------------------------------------------
-- Purpose: Equity perps funding rate history over time
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: date, symbol, venue, avg_rate_bps
--
-- equity-vs-crypto-perps/01_equity_funding_over_time.sql
-- Time series of funding rates for equity perpetual contracts.
-- Equity perps are a newer product class and this query tracks
-- how their funding rates have evolved since launch.

SELECT
    date,
    symbol,
    venue,
    avg_rate_bps
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
ORDER BY date DESC, symbol, venue;


-- -----------------------------------------------------------------------------
-- FILE: equity-vs-crypto-perps/02_weekend_vs_weekday_equity.sql
-- -----------------------------------------------------------------------------
-- Purpose: Weekend vs weekday funding rates for equity perps (oracle freeze effect)
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: is_weekend, venue, avg_rate_bps, median_rate_bps, std_dev_bps, observation_count
--
-- equity-vs-crypto-perps/02_weekend_vs_weekday_equity.sql
-- Equity perps rely on oracle price feeds that freeze on weekends
-- when traditional markets are closed. This query compares weekend
-- vs weekday funding rates to measure the oracle freeze impact.
-- Expect wider spreads and more extreme rates on weekends.

SELECT
    is_weekend,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    COUNT(*) AS observation_count
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
GROUP BY is_weekend, venue
ORDER BY venue, is_weekend;


-- -----------------------------------------------------------------------------
-- FILE: equity-vs-crypto-perps/03_weekend_vs_weekday_crypto.sql
-- -----------------------------------------------------------------------------
-- Purpose: Weekend vs weekday funding rates for crypto perps (control group)
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: is_weekend, venue, avg_rate_bps, median_rate_bps, std_dev_bps, observation_count
--
-- equity-vs-crypto-perps/03_weekend_vs_weekday_crypto.sql
-- Control group for the weekend analysis. Crypto markets trade 24/7
-- so there should be no structural weekend effect. Any weekend
-- difference here is noise, which helps calibrate what's significant
-- in the equity perps weekend analysis.

SELECT
    is_weekend,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    COUNT(*) AS observation_count
FROM marts.mart_daily_funding
WHERE asset_class = 'crypto'
GROUP BY is_weekend, venue
ORDER BY venue, is_weekend;


-- -----------------------------------------------------------------------------
-- FILE: equity-vs-crypto-perps/04_hourly_funding_patterns.sql
-- -----------------------------------------------------------------------------
-- Purpose: Hourly funding patterns comparing crypto (continuous) vs equity (weekend gap)
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_hourly_funding
-- Columns: hour_of_day, asset_class, avg_rate_bps, observation_count
--
-- equity-vs-crypto-perps/04_hourly_funding_patterns.sql
-- Compares hourly funding rate patterns between crypto and equity perps.
-- Crypto perps should show relatively uniform hourly rates (24/7 market).
-- Equity perps may show gaps or anomalies around market close/open hours
-- and especially on weekends when oracles freeze.

SELECT
    EXTRACT(HOUR FROM timestamp) AS hour_of_day,
    asset_class,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    COUNT(*) AS observation_count
FROM marts.mart_hourly_funding
GROUP BY EXTRACT(HOUR FROM timestamp), asset_class
ORDER BY hour_of_day, asset_class;


-- -----------------------------------------------------------------------------
-- FILE: equity-vs-crypto-perps/05_equity_venue_comparison.sql
-- -----------------------------------------------------------------------------
-- Purpose: Equity perps venue comparison (Binance vs BitMEX vs Hyperliquid XYZ)
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: venue, avg_rate_bps, median_rate_bps, std_dev_bps, total_symbols, total_days
--
-- equity-vs-crypto-perps/05_equity_venue_comparison.sql
-- Compares how different venues price equity perpetual funding.
-- Hyperliquid XYZ, Binance, and BitMEX all offer equity perps
-- but with different oracle mechanisms and liquidity profiles.

SELECT
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    COUNT(DISTINCT symbol) AS total_symbols,
    COUNT(DISTINCT date) AS total_days
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
GROUP BY venue
ORDER BY avg_rate_bps DESC;


-- -----------------------------------------------------------------------------
-- FILE: equity-vs-crypto-perps/06_equity_symbol_ranking.sql
-- -----------------------------------------------------------------------------
-- Purpose: Equity symbols ranked by average funding rate
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: symbol_rank, symbol, avg_rate_bps, median_rate_bps, venues_count, total_days
--
-- equity-vs-crypto-perps/06_equity_symbol_ranking.sql
-- Ranks equity perpetual symbols by their average funding rate.
-- Shows which stocks have the most persistent funding rate pressure,
-- which correlates with short interest and borrow cost dynamics.

SELECT
    RANK() OVER (ORDER BY AVG(avg_rate_bps) DESC) AS symbol_rank,
    symbol,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    COUNT(DISTINCT venue) AS venues_count,
    COUNT(DISTINCT date) AS total_days
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
GROUP BY symbol
ORDER BY symbol_rank;


-- -----------------------------------------------------------------------------
-- FILE: equity-vs-crypto-perps/07_crypto_vs_equity_scatter.sql
-- -----------------------------------------------------------------------------
-- Purpose: Scatter plot data comparing crypto vs equity funding rates
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: date, symbol, asset_class, avg_rate_bps
--
-- equity-vs-crypto-perps/07_crypto_vs_equity_scatter.sql
-- Provides raw data points for a scatter plot comparing the funding rate
-- distributions of crypto and equity perps. Each row is one daily observation.
-- The visualization should show whether equity perps cluster at different
-- rate levels than crypto perps.

SELECT
    date,
    symbol,
    asset_class,
    avg_rate_bps
FROM marts.mart_daily_funding
ORDER BY asset_class, date;


-- -----------------------------------------------------------------------------
-- FILE: equity-vs-crypto-perps/08_weekend_premium_analysis.sql
-- -----------------------------------------------------------------------------
-- Purpose: Equity weekend funding premium percentage
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: symbol, venue, weekday_avg_bps, weekend_avg_bps, weekend_premium_pct
--
-- equity-vs-crypto-perps/08_weekend_premium_analysis.sql
-- Quantifies the weekend funding premium for equity perps.
-- The premium is calculated as (weekend_avg - weekday_avg) / abs(weekday_avg) * 100.
-- A positive premium means funding rates are higher on weekends,
-- consistent with the oracle freeze hypothesis.

SELECT
    symbol,
    venue,
    ROUND(AVG(CASE WHEN is_weekend = false THEN avg_rate_bps END), 4) AS weekday_avg_bps,
    ROUND(AVG(CASE WHEN is_weekend = true THEN avg_rate_bps END), 4) AS weekend_avg_bps,
    ROUND(
        100.0 * (
            AVG(CASE WHEN is_weekend = true THEN avg_rate_bps END)
            - AVG(CASE WHEN is_weekend = false THEN avg_rate_bps END)
        ) / NULLIF(ABS(AVG(CASE WHEN is_weekend = false THEN avg_rate_bps END)), 0),
        2
    ) AS weekend_premium_pct
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
GROUP BY symbol, venue
HAVING COUNT(CASE WHEN is_weekend = true THEN 1 END) > 0
   AND COUNT(CASE WHEN is_weekend = false THEN 1 END) > 0
ORDER BY weekend_premium_pct DESC NULLS LAST;


-- -----------------------------------------------------------------------------
-- FILE: equity-vs-crypto-perps/09_equity_funding_volatility.sql
-- -----------------------------------------------------------------------------
-- Purpose: Funding rate volatility by equity symbol
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: symbol, venue, avg_rate_bps, std_dev_bps, cv_pct, max_rate_bps, min_rate_bps
--
-- equity-vs-crypto-perps/09_equity_funding_volatility.sql
-- Measures how volatile funding rates are for each equity symbol.
-- High coefficient of variation (CV) means the funding rate is unstable,
-- which matters for strategies that hold positions across multiple
-- funding intervals.

SELECT
    symbol,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    ROUND(100.0 * STDDEV(avg_rate_bps) / NULLIF(ABS(AVG(avg_rate_bps)), 0), 2) AS cv_pct,
    ROUND(MAX(avg_rate_bps), 4) AS max_rate_bps,
    ROUND(MIN(avg_rate_bps), 4) AS min_rate_bps
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
GROUP BY symbol, venue
ORDER BY std_dev_bps DESC;


-- -----------------------------------------------------------------------------
-- FILE: equity-vs-crypto-perps/10_equity_data_coverage.sql
-- -----------------------------------------------------------------------------
-- Purpose: Data availability by venue and symbol for equity perps
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: venue, symbol, first_date, last_date, total_days, total_weekdays, total_weekends, coverage_pct
--
-- equity-vs-crypto-perps/10_equity_data_coverage.sql
-- Audits data completeness for equity perpetual symbols across venues.
-- Shows date ranges, day counts, and what percentage of possible days
-- have data. Helps identify gaps in the dataset.

SELECT
    venue,
    symbol,
    MIN(date) AS first_date,
    MAX(date) AS last_date,
    COUNT(DISTINCT date) AS total_days,
    COUNT(DISTINCT date) FILTER (WHERE is_weekend = false) AS total_weekdays,
    COUNT(DISTINCT date) FILTER (WHERE is_weekend = true) AS total_weekends,
    ROUND(
        100.0 * COUNT(DISTINCT date)
        / NULLIF(MAX(date) - MIN(date) + 1, 0),
        2
    ) AS coverage_pct
FROM marts.mart_daily_funding
WHERE asset_class = 'equity'
GROUP BY venue, symbol
ORDER BY venue, total_days DESC;


-- -----------------------------------------------------------------------------
-- FILE: equity-vs-crypto-perps/11_hourly_weekend_gap.sql
-- -----------------------------------------------------------------------------
-- Purpose: Hourly granularity weekend gap detection for equity perps
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_hourly_funding
-- Columns: date, hour_of_day, asset_class, venue, avg_rate_bps, rate_change_from_prev_hour
--
-- equity-vs-crypto-perps/11_hourly_weekend_gap.sql
-- Detects funding rate gaps at hourly granularity around weekend transitions.
-- For equity perps, the oracle freeze should cause a visible discontinuity
-- between Friday evening and Monday morning rates. Crypto perps should
-- show no such gap.

SELECT
    DATE(timestamp) AS date,
    EXTRACT(HOUR FROM timestamp)::int AS hour_of_day,
    asset_class,
    venue,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(
        AVG(avg_rate_bps) - LAG(AVG(avg_rate_bps)) OVER (
            PARTITION BY asset_class, venue
            ORDER BY DATE(timestamp), EXTRACT(HOUR FROM timestamp)
        ),
        4
    ) AS rate_change_from_prev_hour
FROM marts.mart_hourly_funding
WHERE EXTRACT(DOW FROM timestamp) IN (0, 5, 6)
GROUP BY DATE(timestamp), EXTRACT(HOUR FROM timestamp), asset_class, venue
ORDER BY DATE(timestamp), hour_of_day, asset_class, venue;


-- -----------------------------------------------------------------------------
-- FILE: equity-vs-crypto-perps/12_equity_perps_summary_stats.sql
-- -----------------------------------------------------------------------------
-- Purpose: Summary statistics for equity perpetual category
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: metric, value
--
-- equity-vs-crypto-perps/12_equity_perps_summary_stats.sql
-- Key summary statistics for the equity perps category in a pivoted format.
-- Provides a quick dashboard-ready snapshot of the equity perps market:
-- total symbols, average rate, extreme values, and data coverage.

SELECT 'total_symbols' AS metric, COUNT(DISTINCT symbol)::text AS value FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'total_venues', COUNT(DISTINCT venue)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'total_observations', COUNT(*)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'avg_rate_bps', ROUND(AVG(avg_rate_bps), 4)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'median_rate_bps', ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'max_rate_bps', ROUND(MAX(avg_rate_bps), 4)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'min_rate_bps', ROUND(MIN(avg_rate_bps), 4)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'std_dev_bps', ROUND(STDDEV(avg_rate_bps), 4)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'date_range_start', MIN(date)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'date_range_end', MAX(date)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity'
UNION ALL
SELECT 'weekend_pct', ROUND(100.0 * COUNT(*) FILTER (WHERE is_weekend = true) / COUNT(*), 2)::text FROM marts.mart_daily_funding WHERE asset_class = 'equity';


-- -----------------------------------------------------------------------------
-- FILE: equity-vs-crypto-perps/13_asset_class_monthly_comparison.sql
-- -----------------------------------------------------------------------------
-- Purpose: Monthly comparison of crypto vs equity funding rates
-- Dashboard: Equity vs Crypto Perps
-- Source: marts.mart_daily_funding
-- Columns: year_month, asset_class, avg_rate_bps, median_rate_bps, std_dev_bps, observation_count
--
-- equity-vs-crypto-perps/13_asset_class_monthly_comparison.sql
-- Side-by-side monthly comparison of crypto and equity funding rates.
-- Reveals whether the gap between asset classes is stable, widening,
-- or narrowing over time.

SELECT
    TO_CHAR(DATE_TRUNC('month', date), 'YYYY-MM') AS year_month,
    asset_class,
    ROUND(AVG(avg_rate_bps), 4) AS avg_rate_bps,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY avg_rate_bps), 4) AS median_rate_bps,
    ROUND(STDDEV(avg_rate_bps), 4) AS std_dev_bps,
    COUNT(*) AS observation_count
FROM marts.mart_daily_funding
GROUP BY DATE_TRUNC('month', date), asset_class
ORDER BY year_month DESC, asset_class;


-- =============================================================================
-- DASHBOARD: annualized yield
-- =============================================================================

-- -----------------------------------------------------------------------------
-- FILE: annualized-yield/01_yield_by_venue_over_time.sql
-- -----------------------------------------------------------------------------
-- Purpose: Annualized yield over time by venue
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: date, venue, daily_annualized_yield_pct
--
-- annualized-yield/01_yield_by_venue_over_time.sql
-- Time series of daily annualized yield for each venue.
-- Annualized yield converts the 8-hour funding rate into a yearly percentage,
-- making it easy to compare against traditional yield benchmarks.

SELECT
    date,
    venue,
    daily_annualized_yield_pct
FROM marts.mart_daily_funding
ORDER BY date DESC, venue;


-- -----------------------------------------------------------------------------
-- FILE: annualized-yield/02_yield_volatility.sql
-- -----------------------------------------------------------------------------
-- Purpose: Rolling 30-day yield volatility by venue
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: date, venue, rolling_yield_stddev_30d, rolling_yield_avg_30d
--
-- annualized-yield/02_yield_volatility.sql
-- Measures how stable the annualized yield is over a 30-day window.
-- High volatility means the yield is unreliable as a persistent income source.
-- Low volatility with positive yield is the ideal carry trade setup.

SELECT
    date,
    venue,
    ROUND(STDDEV(daily_annualized_yield_pct) OVER w, 4) AS rolling_yield_stddev_30d,
    ROUND(AVG(daily_annualized_yield_pct) OVER w, 4) AS rolling_yield_avg_30d
FROM marts.mart_daily_funding
WINDOW w AS (
    PARTITION BY venue
    ORDER BY date
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
)
ORDER BY date DESC, venue;


-- -----------------------------------------------------------------------------
-- FILE: annualized-yield/03_cumulative_yield.sql
-- -----------------------------------------------------------------------------
-- Purpose: Cumulative funding yield if held for 1 year
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: venue, symbol, cumulative_yield_pct, days_held, avg_daily_yield_pct
--
-- annualized-yield/03_cumulative_yield.sql
-- Computes the cumulative funding yield for each venue-symbol pair
-- over the full available data window. Shows what a holder would have
-- earned (or paid) in funding if they maintained the position
-- from the first to the last available date.

SELECT
    venue,
    symbol,
    ROUND(SUM(avg_rate_bps) / 100.0, 4) AS cumulative_yield_pct,
    COUNT(DISTINCT date) AS days_held,
    ROUND(AVG(avg_rate_bps) / 100.0, 4) AS avg_daily_yield_pct
FROM marts.mart_daily_funding
GROUP BY venue, symbol
ORDER BY cumulative_yield_pct DESC;


-- -----------------------------------------------------------------------------
-- FILE: annualized-yield/04_top_yield_opportunities.sql
-- -----------------------------------------------------------------------------
-- Purpose: Highest annualized yield opportunities
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: date, venue, symbol, asset_class, daily_annualized_yield_pct, avg_rate_bps
--
-- annualized-yield/04_top_yield_opportunities.sql
-- Ranks the top annualized yield observations across all venues and symbols.
-- These are the days where holding a long position would have earned
-- the most in funding payments.

SELECT
    date,
    venue,
    symbol,
    asset_class,
    daily_annualized_yield_pct,
    avg_rate_bps
FROM marts.mart_daily_funding
ORDER BY daily_annualized_yield_pct DESC
LIMIT 50;


-- -----------------------------------------------------------------------------
-- FILE: annualized-yield/05_yield_by_symbol.sql
-- -----------------------------------------------------------------------------
-- Purpose: Yield breakdown by symbol
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: symbol, asset_class, avg_annualized_yield_pct, median_yield_pct, max_yield_pct, min_yield_pct, total_days
--
-- annualized-yield/05_yield_by_symbol.sql
-- Aggregates annualized yield statistics per symbol across all venues.
-- Shows which symbols consistently offer the best funding yield
-- and how stable that yield is over time.

SELECT
    symbol,
    asset_class,
    ROUND(AVG(daily_annualized_yield_pct), 4) AS avg_annualized_yield_pct,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY daily_annualized_yield_pct), 4) AS median_yield_pct,
    ROUND(MAX(daily_annualized_yield_pct), 4) AS max_yield_pct,
    ROUND(MIN(daily_annualized_yield_pct), 4) AS min_yield_pct,
    COUNT(DISTINCT date) AS total_days
FROM marts.mart_daily_funding
GROUP BY symbol, asset_class
ORDER BY avg_annualized_yield_pct DESC;


-- -----------------------------------------------------------------------------
-- FILE: annualized-yield/06_yearly_yield_summary.sql
-- -----------------------------------------------------------------------------
-- Purpose: Yearly yield aggregates by venue
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: year, venue, avg_yield_pct, max_yield_pct, min_yield_pct, total_days
--
-- annualized-yield/06_yearly_yield_summary.sql
-- Rolls up annualized yield into yearly summaries per venue.
-- Shows how yield regimes shift year over year and whether
-- certain venues consistently offer better returns.

SELECT
    EXTRACT(YEAR FROM date)::int AS year,
    venue,
    ROUND(AVG(daily_annualized_yield_pct), 4) AS avg_yield_pct,
    ROUND(MAX(daily_annualized_yield_pct), 4) AS max_yield_pct,
    ROUND(MIN(daily_annualized_yield_pct), 4) AS min_yield_pct,
    COUNT(DISTINCT date) AS total_days
FROM marts.mart_daily_funding
GROUP BY EXTRACT(YEAR FROM date), venue
ORDER BY year DESC, venue;


-- -----------------------------------------------------------------------------
-- FILE: annualized-yield/07_yield_vs_volatility_scatter.sql
-- -----------------------------------------------------------------------------
-- Purpose: Risk-return scatter data (yield vs volatility)
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: venue, symbol, asset_class, avg_yield_pct, yield_stddev_pct, sharpe_like_ratio
--
-- annualized-yield/07_yield_vs_volatility_scatter.sql
-- For each venue-symbol pair, computes average yield and yield volatility.
-- The Sharpe-like ratio (avg / stddev) helps identify the best
-- risk-adjusted yield opportunities. High yield with low volatility
-- is the sweet spot for carry strategies.

SELECT
    venue,
    symbol,
    asset_class,
    ROUND(AVG(daily_annualized_yield_pct), 4) AS avg_yield_pct,
    ROUND(STDDEV(daily_annualized_yield_pct), 4) AS yield_stddev_pct,
    ROUND(
        AVG(daily_annualized_yield_pct) / NULLIF(STDDEV(daily_annualized_yield_pct), 0),
        4
    ) AS sharpe_like_ratio
FROM marts.mart_daily_funding
GROUP BY venue, symbol, asset_class
HAVING COUNT(*) > 10
ORDER BY sharpe_like_ratio DESC NULLS LAST;


-- -----------------------------------------------------------------------------
-- FILE: annualized-yield/08_yield_quartiles.sql
-- -----------------------------------------------------------------------------
-- Purpose: Yield distribution quartiles by venue
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: venue, q1_yield_pct, q2_yield_pct, q3_yield_pct, q4_yield_pct, iqr_pct
--
-- annualized-yield/08_yield_quartiles.sql
-- Computes quartile boundaries for annualized yield per venue.
-- The interquartile range (IQR) shows how concentrated yields are.
-- A narrow IQR means the venue offers predictable returns.

SELECT
    venue,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY daily_annualized_yield_pct), 4) AS q1_yield_pct,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY daily_annualized_yield_pct), 4) AS q2_yield_pct,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY daily_annualized_yield_pct), 4) AS q3_yield_pct,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY daily_annualized_yield_pct), 4) AS q4_yield_pct,
    ROUND(
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY daily_annualized_yield_pct)
        - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY daily_annualized_yield_pct),
        4
    ) AS iqr_pct
FROM marts.mart_daily_funding
GROUP BY venue
ORDER BY q2_yield_pct DESC;


-- -----------------------------------------------------------------------------
-- FILE: annualized-yield/09_monthly_yield_heatmap.sql
-- -----------------------------------------------------------------------------
-- Purpose: Venue x month yield heatmap matrix
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: venue, year_month, avg_yield_pct
--
-- annualized-yield/09_monthly_yield_heatmap.sql
-- Produces a venue-by-month matrix of average annualized yield.
-- Designed for heatmap visualization where rows are venues,
-- columns are months, and color intensity represents yield level.

SELECT
    venue,
    TO_CHAR(DATE_TRUNC('month', date), 'YYYY-MM') AS year_month,
    ROUND(AVG(daily_annualized_yield_pct), 4) AS avg_yield_pct
FROM marts.mart_daily_funding
GROUP BY venue, DATE_TRUNC('month', date)
ORDER BY venue, year_month;


-- -----------------------------------------------------------------------------
-- FILE: annualized-yield/10_negative_funding_analysis.sql
-- -----------------------------------------------------------------------------
-- Purpose: Analysis of negative funding periods (shorters pay longs)
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: venue, symbol, asset_class, negative_days, total_days, negative_pct, avg_negative_rate_bps
--
-- annualized-yield/10_negative_funding_analysis.sql
-- Identifies when funding rates go negative, meaning shorts pay longs.
-- For a long-only funding strategy, negative rates are losses.
-- This query shows how often and how severely rates turn negative
-- by venue and symbol.

SELECT
    venue,
    symbol,
    asset_class,
    COUNT(*) FILTER (WHERE avg_rate_bps < 0) AS negative_days,
    COUNT(*) AS total_days,
    ROUND(100.0 * COUNT(*) FILTER (WHERE avg_rate_bps < 0) / COUNT(*), 2) AS negative_pct,
    ROUND(AVG(CASE WHEN avg_rate_bps < 0 THEN avg_rate_bps END), 4) AS avg_negative_rate_bps,
    ROUND(MIN(avg_rate_bps), 4) AS worst_negative_bps
FROM marts.mart_daily_funding
GROUP BY venue, symbol, asset_class
HAVING COUNT(*) FILTER (WHERE avg_rate_bps < 0) > 0
ORDER BY negative_pct DESC;


-- -----------------------------------------------------------------------------
-- FILE: annualized-yield/11_yield_duration_analysis.sql
-- -----------------------------------------------------------------------------
-- Purpose: Duration analysis of high-yield periods
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: venue, symbol, streak_start, streak_end, streak_length_days, avg_yield_during_streak_pct
--
-- annualized-yield/11_yield_duration_analysis.sql
-- Identifies consecutive-day streaks where annualized yield exceeded 20%.
-- Shows how long high-yield regimes persist before reverting.
-- Important for sizing positions: a 30-day streak is very different
-- from a 3-day spike.

WITH flagged AS (
    SELECT
        date,
        venue,
        symbol,
        daily_annualized_yield_pct,
        CASE WHEN daily_annualized_yield_pct > 20.0 THEN 1 ELSE 0 END AS is_high_yield,
        ROW_NUMBER() OVER (PARTITION BY venue, symbol ORDER BY date) AS rn
    FROM marts.mart_daily_funding
),
grouped AS (
    SELECT
        date,
        venue,
        symbol,
        daily_annualized_yield_pct,
        rn - SUM(is_high_yield) OVER (PARTITION BY venue, symbol ORDER BY date ROWS UNBOUNDED PRECEDING) AS grp
    FROM flagged
    WHERE is_high_yield = 1
)
SELECT
    venue,
    symbol,
    MIN(date) AS streak_start,
    MAX(date) AS streak_end,
    COUNT(*) AS streak_length_days,
    ROUND(AVG(daily_annualized_yield_pct), 4) AS avg_yield_during_streak_pct
FROM grouped
GROUP BY venue, symbol, grp
HAVING COUNT(*) >= 3
ORDER BY streak_length_days DESC, avg_yield_during_streak_pct DESC;


-- -----------------------------------------------------------------------------
-- FILE: annualized-yield/12_yield_seasonality.sql
-- -----------------------------------------------------------------------------
-- Purpose: Monthly seasonality patterns in annualized yield
-- Dashboard: Annualized Yield
-- Source: marts.mart_daily_funding
-- Columns: month_num, month_name, avg_yield_pct, median_yield_pct, observation_count
--
-- annualized-yield/12_yield_seasonality.sql
-- Checks whether annualized yield has monthly seasonality.
-- Some months might consistently offer better funding yields
-- due to market cycles, options expiration patterns, or
-- quarterly funding events.

SELECT
    EXTRACT(MONTH FROM date)::int AS month_num,
    TO_CHAR(DATE_TRUNC('month', date), 'Month') AS month_name,
    ROUND(AVG(daily_annualized_yield_pct), 4) AS avg_yield_pct,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY daily_annualized_yield_pct), 4) AS median_yield_pct,
    COUNT(*) AS observation_count
FROM marts.mart_daily_funding
GROUP BY EXTRACT(MONTH FROM date), TO_CHAR(DATE_TRUNC('month', date), 'Month')
ORDER BY month_num;


