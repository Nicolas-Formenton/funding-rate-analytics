#!/usr/bin/env python3
"""Generate 4 Deepnote dashboard notebooks using nbformat."""
import nbformat
from nbformat.v4 import new_notebook, new_code_cell

# ─── Common setup cell (shared across all notebooks) ───────────────────────────
SETUP_CELL = """\
!pip install plotly pandas requests nbformat -q

import requests
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from datetime import datetime, timedelta

API_URL = 'https://djtnqbvkhqftmtnsityx.supabase.co/rest/v1/'
API_KEY = 'sb_publishable_NnOjc1iJWmA7j418h79mEg_AHh9h49u'
HEADERS = {'apikey': API_KEY, 'Authorization': f'Bearer {API_KEY}'}

def query_supabase(endpoint, select='*', filters=None, limit=10000):
    \"\"\"Query Supabase REST API with filters.\"\"\"
    params = {}
    if select: params['select'] = select
    if filters:
        for k, v in filters.items():
            params[k] = f'eq.{v}'
    if limit: params['limit'] = limit
    r = requests.get(f'{API_URL}{endpoint}', headers=HEADERS, params=params)
    if r.status_code == 200:
        return pd.DataFrame(r.json())
    else:
        print(f'Error {r.status_code}: {r.text[:200]}')
        return pd.DataFrame()"""


def make_notebook(cells: list[str]) -> nbformat.NotebookNode:
    """Create a notebook with metadata and the given code cells."""
    nb = new_notebook()
    nb.metadata.kernelspec = {
        "display_name": "Python 3",
        "language": "python",
        "name": "python3",
    }
    nb.metadata.language_info = {
        "name": "python",
        "version": "3.11.0",
    }
    for src in cells:
        nb.cells.append(new_code_cell(src))
    return nb


# ═══════════════════════════════════════════════════════════════════════════════
# Dashboard 1 — Funding Rate Overview
# ═══════════════════════════════════════════════════════════════════════════════
d1_cells = [
    SETUP_CELL,
    # Cell 2: Query daily funding for crypto symbols, last 12 months
    """\
# Query daily funding for crypto symbols — last 12 months
one_year_ago = (datetime.now() - timedelta(days=365)).strftime('%Y-%m-%d')

df = query_supabase(
    'daily_funding',
    select='venue,symbol,date,avg_rate_bps,asset_class',
    filters={'asset_class': 'crypto'},
    limit=50000
)

df['date'] = pd.to_datetime(df['date'])
df = df[df['date'] >= one_year_ago].copy()
df['avg_rate_bps'] = pd.to_numeric(df['avg_rate_bps'], errors='coerce')
df = df.dropna(subset=['avg_rate_bps'])

print(f"Loaded {len(df):,} rows across {df['venue'].nunique()} venues and {df['symbol'].nunique()} symbols")
print(f"Date range: {df['date'].min().date()} → {df['date'].max().date()}")
df.head()""",
    # Cell 3: Plotly line chart
    """\
# Line chart: avg funding rate over time by venue
daily_avg = df.groupby(['date', 'venue'])['avg_rate_bps'].mean().reset_index()

fig = px.line(
    daily_avg, x='date', y='avg_rate_bps', color='venue',
    title='Crypto Funding Rates by Venue (Daily Avg)',
    labels={'avg_rate_bps': 'Avg Rate (bps)', 'date': 'Date', 'venue': 'Venue'},
    template='plotly_dark'
)
fig.update_layout(height=500, hovermode='x unified')
fig.show()""",
    # Cell 4: Histogram
    """\
# Histogram: distribution of funding rates by venue
fig = px.histogram(
    df, x='avg_rate_bps', color='venue', barmode='overlay', nbins=80,
    title='Funding Rate Distribution by Venue',
    labels={'avg_rate_bps': 'Avg Rate (bps)', 'venue': 'Venue'},
    template='plotly_dark', opacity=0.6
)
fig.update_layout(height=450)
fig.show()""",
    # Cell 5: Summary stats table
    """\
# Summary statistics by venue
summary = df.groupby('venue')['avg_rate_bps'].agg(
    count='count', mean='mean', median='median',
    min='min', max='max', std='std'
).round(3).sort_values('mean', ascending=False)

summary.style.format({
    'mean': '{:.2f}', 'median': '{:.2f}', 'min': '{:.2f}',
    'max': '{:.2f}', 'std': '{:.2f}'
}).set_caption('Funding Rate Summary (bps) by Venue')""",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Dashboard 2 — Cross-Venue Spread
# ═══════════════════════════════════════════════════════════════════════════════
d2_cells = [
    SETUP_CELL,
    # Cell 2: Query venue_comparison with positive spreads
    """\
# Query venue comparison — cross-venue spreads
df = query_supabase(
    'venue_comparison',
    select='date,symbol,venue,avg_rate_bps,max_cross_spread_bps,arb_venue_pair',
    limit=50000
)

df['date'] = pd.to_datetime(df['date'])
df['avg_rate_bps'] = pd.to_numeric(df['avg_rate_bps'], errors='coerce')
df['max_cross_spread_bps'] = pd.to_numeric(df['max_cross_spread_bps'], errors='coerce')
df = df.dropna(subset=['max_cross_spread_bps'])
df_pos = df[df['max_cross_spread_bps'] > 0].copy()

print(f"Loaded {len(df_pos):,} rows with positive cross-venue spreads")
print(f"Date range: {df_pos['date'].min().date()} → {df_pos['date'].max().date()}")
df_pos.head()""",
    # Cell 3: Line chart — max_cross_spread_bps over time
    """\
# Line chart: max cross-venue spread over time by symbol
spread_daily = df_pos.groupby(['date', 'symbol'])['max_cross_spread_bps'].max().reset_index()

fig = px.line(
    spread_daily, x='date', y='max_cross_spread_bps', color='symbol',
    title='Max Cross-Venue Spread Over Time',
    labels={'max_cross_spread_bps': 'Spread (bps)', 'date': 'Date'},
    template='plotly_dark'
)
fig.update_layout(height=500, hovermode='x unified')
fig.show()""",
    # Cell 4: Heatmap — correlation matrix of rates across venues
    """\
# Heatmap: correlation matrix of avg funding rates across venues
pivot = df.pivot_table(index='date', columns='venue', values='avg_rate_bps', aggfunc='mean')
corr = pivot.corr().round(3)

fig = px.imshow(
    corr, text_auto='.2f', color_scale='RdYlGn', aspect='auto',
    title='Funding Rate Correlation Across Venues',
    template='plotly_dark'
)
fig.update_layout(height=450)
fig.show()""",
    # Cell 5: Top 10 arbitrage opportunity days
    """\
# Top 10 arbitrage opportunity days — highest cross-venue spreads
top10 = (
    df_pos.nlargest(10, 'max_cross_spread_bps')[
        ['date', 'symbol', 'venue', 'max_cross_spread_bps', 'arb_venue_pair']
    ]
    .reset_index(drop=True)
)
top10['date'] = top10['date'].dt.strftime('%Y-%m-%d')

print("Top 10 Arbitrage Opportunity Days (Highest Cross-Venue Spread)")
print("=" * 70)
top10""",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Dashboard 3 — Equity vs Crypto
# ═══════════════════════════════════════════════════════════════════════════════
d3_cells = [
    SETUP_CELL,
    # Cell 2: Query equity funding
    """\
# Query daily funding for equity perps
equity_df = query_supabase(
    'daily_funding',
    select='venue,symbol,date,avg_rate_bps,asset_class,is_weekend',
    filters={'asset_class': 'equity'},
    limit=50000
)
equity_df['date'] = pd.to_datetime(equity_df['date'])
equity_df['avg_rate_bps'] = pd.to_numeric(equity_df['avg_rate_bps'], errors='coerce')
equity_df = equity_df.dropna(subset=['avg_rate_bps'])
equity_df['is_weekend'] = equity_df['is_weekend'].astype(str).str.lower().isin(['true', '1', 't', 'yes'])

print(f"Equity perps: {len(equity_df):,} rows, symbols: {equity_df['symbol'].unique().tolist()}")
equity_df.head()""",
    # Cell 3: Query crypto funding (control group)
    """\
# Query daily funding for crypto perps (control group)
crypto_df = query_supabase(
    'daily_funding',
    select='venue,symbol,date,avg_rate_bps,asset_class,is_weekend',
    filters={'asset_class': 'crypto'},
    limit=50000
)
crypto_df['date'] = pd.to_datetime(crypto_df['date'])
crypto_df['avg_rate_bps'] = pd.to_numeric(crypto_df['avg_rate_bps'], errors='coerce')
crypto_df = crypto_df.dropna(subset=['avg_rate_bps'])
crypto_df['is_weekend'] = crypto_df['is_weekend'].astype(str).str.lower().isin(['true', '1', 't', 'yes'])

print(f"Crypto perps: {len(crypto_df):,} rows")
crypto_df.head()""",
    # Cell 4: Bar chart — weekend vs weekday by asset_class
    """\
# Bar chart: weekend vs weekday avg funding by asset class
equity_df['day_type'] = equity_df['is_weekend'].map({True: 'Weekend', False: 'Weekday'})
crypto_df['day_type'] = crypto_df['is_weekend'].map({True: 'Weekend', False: 'Weekday'})

equity_summary = equity_df.groupby('day_type')['avg_rate_bps'].mean().reset_index()
equity_summary['asset_class'] = 'Equity'
crypto_summary = crypto_df.groupby('day_type')['avg_rate_bps'].mean().reset_index()
crypto_summary['asset_class'] = 'Crypto'

combined = pd.concat([equity_summary, crypto_summary])

fig = px.bar(
    combined, x='day_type', y='avg_rate_bps', color='asset_class', barmode='group',
    title='Weekend vs Weekday Avg Funding Rate by Asset Class',
    labels={'avg_rate_bps': 'Avg Rate (bps)', 'day_type': '', 'asset_class': 'Asset Class'},
    template='plotly_dark'
)
fig.update_layout(height=400)
fig.show()""",
    # Cell 5: Dual line chart — equity vs crypto over time
    """\
# Dual line chart: equity vs crypto funding rates over time
eq_daily = equity_df.groupby('date')['avg_rate_bps'].mean().reset_index()
eq_daily['asset_class'] = 'Equity'
cr_daily = crypto_df.groupby('date')['avg_rate_bps'].mean().reset_index()
cr_daily['asset_class'] = 'Crypto'
both = pd.concat([eq_daily, cr_daily])

fig = px.line(
    both, x='date', y='avg_rate_bps', color='asset_class',
    title='Equity vs Crypto Perpetual Funding Rates Over Time',
    labels={'avg_rate_bps': 'Avg Rate (bps)', 'date': 'Date', 'asset_class': 'Asset Class'},
    template='plotly_dark'
)
fig.update_layout(height=500, hovermode='x unified')
fig.show()""",
    # Cell 6: Key finding
    """\
# Key finding: weekend premium for equity vs crypto perps
eq_weekend = equity_df[equity_df['is_weekend']]['avg_rate_bps'].mean()
eq_weekday = equity_df[~equity_df['is_weekend']]['avg_rate_bps'].mean()
cr_weekend = crypto_df[crypto_df['is_weekend']]['avg_rate_bps'].mean()
cr_weekday = crypto_df[~crypto_df['is_weekend']]['avg_rate_bps'].mean()

eq_premium = ((eq_weekend / eq_weekday) - 1) * 100 if eq_weekday != 0 else 0
cr_premium = ((cr_weekend / cr_weekday) - 1) * 100 if cr_weekday != 0 else 0

print("=" * 60)
print("KEY FINDING: Equity vs Crypto Weekend Funding Premium")
print("=" * 60)
print(f"Equity weekend avg:  {eq_weekend:.2f} bps | weekday avg: {eq_weekday:.2f} bps | premium: {eq_premium:+.1f}%")
print(f"Crypto weekend avg:  {cr_weekend:.2f} bps | weekday avg: {cr_weekday:.2f} bps | premium: {cr_premium:+.1f}%")
print()
if abs(eq_premium) > abs(cr_premium):
    print(f"→ Equity perps show {abs(eq_premium - cr_premium):.1f}% {'higher' if eq_premium > cr_premium else 'lower'} weekend funding premium vs crypto perps.")
else:
    print(f"→ Crypto perps show {abs(cr_premium - eq_premium):.1f}% {'higher' if cr_premium > eq_premium else 'lower'} weekend funding premium vs equity perps.")""",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Dashboard 4 — Annualized Yield
# ═══════════════════════════════════════════════════════════════════════════════
d4_cells = [
    SETUP_CELL,
    # Cell 2: Query all daily funding with yield data
    """\
# Query daily funding for all venues/symbols with yield data
df = query_supabase(
    'daily_funding',
    select='venue,symbol,date,avg_rate_bps,daily_annualized_yield_pct,asset_class',
    limit=50000
)

df['date'] = pd.to_datetime(df['date'])
df['avg_rate_bps'] = pd.to_numeric(df['avg_rate_bps'], errors='coerce')
df['daily_annualized_yield_pct'] = pd.to_numeric(df['daily_annualized_yield_pct'], errors='coerce')
df = df.dropna(subset=['daily_annualized_yield_pct'])

print(f"Loaded {len(df):,} rows with annualized yield data")
print(f"Venues: {df['venue'].unique().tolist()}")
print(f"Date range: {df['date'].min().date()} → {df['date'].max().date()}")
df.head()""",
    # Cell 3: Line chart — daily_annualized_yield_pct over time by venue
    """\
# Line chart: annualized yield over time by venue
yield_daily = df.groupby(['date', 'venue'])['daily_annualized_yield_pct'].mean().reset_index()

fig = px.line(
    yield_daily, x='date', y='daily_annualized_yield_pct', color='venue',
    title='Annualized Funding Yield by Venue Over Time',
    labels={'daily_annualized_yield_pct': 'Annualized Yield (%)', 'date': 'Date', 'venue': 'Venue'},
    template='plotly_dark'
)
fig.update_layout(height=500, hovermode='x unified')
fig.show()""",
    # Cell 4: Scatter — yield vs volatility by venue
    """\
# Scatter: yield vs rate volatility (std dev) by venue-symbol
scatter_df = df.groupby(['venue', 'symbol']).agg(
    avg_yield=('daily_annualized_yield_pct', 'mean'),
    yield_std=('daily_annualized_yield_pct', 'std'),
    avg_rate=('avg_rate_bps', 'mean'),
    observations=('date', 'count')
).reset_index().dropna()

fig = px.scatter(
    scatter_df, x='yield_std', y='avg_yield', color='venue', size='observations',
    hover_data=['symbol', 'avg_rate'],
    title='Yield vs Volatility by Venue-Symbol',
    labels={'yield_std': 'Yield Std Dev (%)', 'avg_yield': 'Avg Annualized Yield (%)', 'venue': 'Venue'},
    template='plotly_dark'
)
fig.update_layout(height=500)
fig.show()""",
    # Cell 5: Area chart — cumulative yield if held 1 year
    """\
# Area chart: cumulative yield if held continuously for 1 year by venue
yield_daily = df.groupby(['date', 'venue'])['daily_annualized_yield_pct'].mean().reset_index()
yield_daily = yield_daily.sort_values('date')

# Cumulative yield = sum of daily yield / 365 * 100 (convert pct to cumulative)
yield_daily['daily_yield_frac'] = yield_daily['daily_annualized_yield_pct'] / 365 / 100
yield_daily['cumulative_yield_pct'] = yield_daily.groupby('venue')['daily_yield_frac'].cumsum() * 100

fig = px.area(
    yield_daily, x='date', y='cumulative_yield_pct', color='venue',
    title='Cumulative Yield (If Held Continuously)',
    labels={'cumulative_yield_pct': 'Cumulative Yield (%)', 'date': 'Date', 'venue': 'Venue'},
    template='plotly_dark'
)
fig.update_layout(height=500, hovermode='x unified')
fig.show()""",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Write all notebooks
# ═══════════════════════════════════════════════════════════════════════════════
import os

base = os.path.dirname(os.path.abspath(__file__))

notebooks = {
    'dashboard_1_overview.ipynb': d1_cells,
    'dashboard_2_spread.ipynb': d2_cells,
    'dashboard_3_equity.ipynb': d3_cells,
    'dashboard_4_yield.ipynb': d4_cells,
}

for fname, cells in notebooks.items():
    nb = make_notebook(cells)
    path = os.path.join(base, fname)
    with open(path, 'w') as f:
        nbformat.write(nb, f)
    print(f"✓ {fname} — {len(cells)} cells")

print("\nDone. All notebooks written.")
