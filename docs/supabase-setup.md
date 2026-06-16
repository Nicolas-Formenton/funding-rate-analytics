# Supabase Setup Guide

Push your local Docker PostgreSQL funding rate data to a hosted Supabase
Postgres instance for sharing dashboards and collaborating.

---

## Prerequisites

- Local Docker PG running with funding rate data loaded
- `psql` and `pg_dump` installed on your machine
  - macOS: `brew install libpq`
  - Linux: `apt install postgresql-client`
  - Verify: `psql --version && pg_dump --version`
- Python 3.8+ (for the push script)
- A Supabase account (free tier is sufficient)

---

## Step 1: Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign up / log in.
2. Click **New project**.
3. Fill in:
   - **Name**: `funding-rate-analytics`
   - **Database Password**: generate a strong one (save it somewhere safe).
   - **Region**: pick the one closest to you (e.g. `US East (N. Virginia)`).
   - **Pricing Plan**: Free tier is fine — 500 MB storage, 2 projects.
4. Wait ~2 minutes for the project to provision.

---

## Step 2: Get the Connection String

1. In your Supabase project dashboard, go to:
   **Project Settings** (gear icon) → **Database** → **Connection string**.
2. Find the **URI** section.
3. Copy the connection string. It looks like:

   ```
   postgresql://postgres.[project-ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres
   ```

4. The **Session pooler** port `6543` is the right one for connection pooling.
5. Replace `[password]` with the database password you set in Step 1.

---

## Step 3: Set the Environment Variable

```bash
export SUPABASE_URL="postgresql://postgres.xxxxx:your-password@aws-0-us-east-1.pooler.supabase.com:6543/postgres"
```

To persist it, add the line to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
echo 'export SUPABASE_URL="postgresql://postgres.xxxxx:your-password@aws-0-us-east-1.pooler.supabase.com:6543/postgres"' >> ~/.zshrc
```

---

## Step 4: Push the Data

From the project root:

```bash
python scripts/push_to_supabase.py
```

The script will:

1. **Query local row counts** — shows how many rows per table.
2. **Push DDL** — creates schemas (`raw`, `staging`, `marts`) and all tables/views on Supabase.
3. **Push data** — pipes table data into Supabase via `pg_dump | psql`.
4. **Verify** — compares row counts between local and remote.

**Expected output:**

```
============================================================
  Push local Docker PG → Supabase
============================================================

[0/4] Gathering local row counts...
    raw.funding_binance: 88,320 rows
    raw.funding_hyperliquid: 87,552 rows
    raw.funding_deribit: 43,776 rows
    raw.funding_equity_perps: 41,472 rows
    staging.stg_funding_events: 261,120 rows (view)
    marts.mart_hourly_funding: 96,000 rows
    marts.mart_daily_funding: 96,000 rows
    marts.mart_venue_comparison: 96,000 rows
    Total: ~550K rows

[1/4] Pushing DDL (3 schemas)...
  → raw tables DDL
  → staging views DDL
  → marts tables DDL
  ✓ DDL pushed (0.8s)

[2/4] Pushing data (550K rows)...
  → raw data
  → marts data
  ✓ Data pushed (12.3s)

[3/4] Verifying data integrity...
    ✓ raw.funding_binance: local=88320  remote=88320
    ✓ raw.funding_hyperliquid: local=87552  remote=87552
    ✓ raw.funding_deribit: local=43776  remote=43776
    ✓ raw.funding_equity_perps: local=41472  remote=41472
    ✓ marts.mart_hourly_funding: local=96000  remote=96000
    ✓ marts.mart_daily_funding: local=96000  remote=96000
    ✓ marts.mart_venue_comparison: local=96000  remote=96000

[4/4] ✓ Push complete — all counts match!
```

---

## Step 5: Verify in Supabase Dashboard

1. Go to your Supabase project → **Table Editor**.
2. You should see schemas `raw`, `staging`, and `marts` in the schema dropdown.
3. Click into any table to preview rows.
4. Optionally run a test query in **SQL Editor**:

   ```sql
   SELECT venue, COUNT(*) as cnt
   FROM marts.mart_daily_funding
   GROUP BY venue;
   ```

---

## Usage in Deepnote

When connecting from Deepnote, use the same connection string:

- **Host**: `aws-0-[region].pooler.supabase.com`
- **Port**: `6543`
- **Database**: `postgres`
- **User**: `postgres.[project-ref]`
- **Password**: your database password

---

## Troubleshooting

| Symptom | Likely Fix |
|---------|------------|
| `pg_dump: command not found` | Install PostgreSQL client tools (`brew install libpq` on macOS) |
| `psql: could not connect to Supabase` | Check `SUPABASE_URL` is set correctly. Verify your IP is not blocked (Supabase free tier includes network restrictions) |
| `ssl not enabled` | Append `?sslmode=require` to the connection string |
| Relation already exists | Run `DROP SCHEMA raw CASCADE; DROP SCHEMA staging CASCADE; DROP SCHEMA marts CASCADE;` in Supabase SQL Editor to reset, then re-run the push script |
| Push hangs / slow | Supabase free tier has connection limits. The session pooler (port `6543`) handles this better than the direct connection (port `5432`) |
| Exceeded free tier storage | Check usage in Project Settings → Usage. If over 500MB, upgrade or clean old data |

---

## Estimated Usage

| Item | Value |
|------|-------|
| Row count | ~550K (raw + marts) |
| Estimated storage | ~50–100 MB |
| Supabase free tier limit | 500 MB |
| Schemas pushed | `raw`, `staging` (view), `marts` |
| Tables with data | 4 raw + 3 marts = 7 tables |

Well within the free tier — you have room to grow.
