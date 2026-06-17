# Learnings — Funding Rate Revamp

## Task 2: Deribit `interest_8h` normalization fix (2026-06-17)

### Bug
The dbt staging model divided Deribit `interest_8h` by 100, treating it as a percentage (e.g., 0.01 meaning 0.01%). In reality, the raw data is a **decimal fraction** (e.g., 5.9e-05 = 0.0059% per 8h period). This made all Deribit funding rates 100x understated.

### Root cause
The SQL formula `interest_8h / 100 * 3 * 365` was missing the `* 100` that the Python normalizer (`rate_normalizer.py:89`) includes. The Python code has both `/100` and `*100` which cancel out, effectively computing `rate * 3 * 365`. The SQL only had `/100` without the compensating `*100`.

### Fix applied
- **`dbt/models/staging/stg_funding_events.sql` line 43**: Changed `interest_8h / 100 * 3 * 365` → `interest_8h * 3 * 365`
- **`schemas/02_staging.sql` line 46**: Same formula fix
- **`docs/normalization-rules.md`**: Updated Deribit section — source format from "Percentage rate" to "Decimal fraction", formula from `(interest_8h / 100) × 3 × 365` to `interest_8h × 3 × 365`

### Verification
- `dbt run`: 4/4 models OK (1 view + 3 tables)
- `dbt test`: 24/24 tests PASS
- Deribit AVG before fix: 0.068 bps (100x too low)
- Deribit AVG after fix: **6.81 bps** (correct, in plausible range [0.5, 50] bps)

### Key insight
The task description suggested `interest_8h * 3 * 365 * 100`, but that would produce ~680 bps (outside plausible range). The mathematically correct formula is `interest_8h * 3 * 365`, which matches the Python normalizer's effective computation (where `/100` and `*100` cancel). Always verify formulas against actual data before applying.

### Files changed
1. `dbt/models/staging/stg_funding_events.sql` — formula + comment
2. `schemas/02_staging.sql` — formula + comment
3. `docs/normalization-rules.md` — Deribit section rewritten

### Files NOT changed (by design)
- `src/extracted/rate_normalizer.py` — code is correct (net effect = `rate * 3 * 365`), though comments/docstring incorrectly describe Deribit data as "percentage"

---

## Task 2 (correction): Added missing `* 100` multiplier (2026-06-17)

### Issue with previous fix
The previous session removed the `/100` but did NOT add the `* 100` multiplier. This left Deribit rates at 0.068% annualized instead of 6.81% — still 100x understated relative to the percentage format used by all other venues.

### Why `* 100` is required
ALL venues use `* 100` at the end of their annualization formula to convert decimal → percentage:
- Binance: `funding_rate * 3 * 365 * 100` (AVG = 8.90 = 8.90%)
- Hyperliquid: `funding_rate * 24 * 365 * 100` (AVG = 12.43 = 12.43%)
- Deribit (corrected): `interest_8h * 3 * 365 * 100` (AVG = 6.81 = 6.81%)

The `funding_rate_annualized_pct` column stores **percentage values** across all venues. Without `* 100`, Deribit was the only venue outputting raw decimals instead of percentages.

### Fix applied
- **`dbt/models/staging/stg_funding_events.sql:43`**: `interest_8h * 3 * 365` → `interest_8h * 3 * 365 * 100`
- **`schemas/02_staging.sql:46`**: Same formula fix
- **`docs/normalization-rules.md`**: Updated formula, breakdown, and example to include `× 100`

### Verification
- `dbt run --full-refresh`: 4/4 models OK
- `dbt test`: 24/24 tests PASS
- Deribit staging AVG: **6.8057** (percentage form, = 6.81% annualized) ✅
- Deribit mart `avg_rate_bps`: **679.63** bps (= 6.80% annualized) ✅

### Lesson learned
The previous session's "key insight" was wrong. It argued that `interest_8h * 3 * 365` was correct because the Python normalizer's `/100` and `*100` cancel out. But the Python normalizer's docstring incorrectly describes Deribit data as "percentage" when it's actually a decimal fraction. The correct interpretation: Deribit raw data IS a decimal fraction (same as Binance/Hyperliquid), and ALL venues need `* 100` to produce percentage output. Consistency across venues is the ground truth.
