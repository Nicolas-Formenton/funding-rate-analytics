# Task 2 — Data Source Validation Evidence

> Date: 2026-06-16
> Command: `node doctor.mjs --json` would not apply; manual endpoint validation.

---

## Results Summary

### Endpoint 1: Binance data.vision (historical funding rate ZIPs)
```
$ curl -sI "https://data.binance.vision/data/futures/um/monthly/fundingRate/BTCUSDT/BTCUSDT-fundingRate-2020-01.zip"
→ HTTP/2 200
→ content-type: binary/octet-stream
→ content-length: 825
→ last-modified: Tue, 09 May 2023 22:02:30 GMT
→ file type: Zip archive data, at least v2.0 to extract, compression method=deflate
```
**Verdict: CONFIRMED** — Monthly ZIP accessible. Also confirmed 2024-12 (808 bytes).

**Unexpected:** Daily ZIP at `BTCUSDT-fundingRate-2025-06-01.zip` returns 404. Use monthly pattern only.

### Endpoint 2: Binance REST API (fapi/v1/fundingRate)
```
$ curl -s "https://fapi.binance.com/fapi/v1/fundingRate?symbol=BTCUSDT&limit=1"
→ [{"symbol":"BTCUSDT","fundingTime":1781625600001,"fundingRate":"0.00000246","markPrice":"65841.90000000"}]
```
**Verdict: CONFIRMED** — JSON with `fundingRate` key present. Rolling ~33 day window (2026-05-14 → 2026-06-16). Max 100 records per call.

### Endpoint 3: Deribit API (public/get_funding_rate_history)
```
$ curl -s -X POST ... -d '{"jsonrpc":"2.0","method":"public/get_funding_rate_history",...}'
→ {"jsonrpc":"2.0","id":1,"result":[...24 records in 24 hours...]}
```
**Verdict: CONFIRMED** — Hourly data from 2020-01-01 01:00 UTC to present. Best historical depth.

**Key insight:** Deribit returns `interest_8h`/`interest_1h` not raw `fundingRate`. Transformation needed to normalize across exchanges.

### Endpoint 4: BitMEX API (funding)
```
$ curl -s "https://www.bitmex.com/api/v1/funding?symbol=.SPYPERP&count=5"
→ []  (empty)
```
```
$ curl -s "https://www.bitmex.com/api/v1/funding?symbol=XBTUSD&count=3"
→ [{"timestamp":"...","symbol":"XBTUSD","fundingRate":-0.000189,...}]
```
**Verdict: PARTIAL** — .SPYPERP empty (equity perps delisted/renamed). XBTUSD works with funding data at 8h intervals. 22 instruments available.

### Endpoint 5a: AlgoTick S3
```
$ python3 -c "import duckdb; ... SELECT * FROM 's3://algotick-data-lake/states/funding/exchange=hyperliquid/coin=BTC/*.parquet' LIMIT 1"
→ HTTP Error: HTTP GET error reading 's3://algotick-data-lake/states/funding/exchange=hyperliquid/coin=BTC'
  NoSuchBucket: The specified bucket does not exist
```
**Verdict: BLOCKED** — Bucket does not exist.

### Endpoint 5b: Hyperliquid API (fallback)
```
$ curl -s -X POST "https://api.hyperliquid.xyz/info" -d '{"type":"fundingHistory",...}'
→ [{"coin":"BTC","fundingRate":"0.0000125","premium":"-0.000024636","time":1748649600016},...]
```
**Verdict: CONFIRMED** — Hourly funding data available. Native API works as fallback.

### Endpoint 6: Binance premiumIndex
```
$ curl -s "https://fapi.binance.com/fapi/v1/premiumIndex?symbol=BTCUSDT"
→ {"symbol":"BTCUSDT","markPrice":"65753.00000000","indexPrice":"65779.14630435",...}
```
**Verdict: CONFIRMED** — Returns mark price, index price, last funding rate. Single-tick snapshot (not historical).

---

## Files Written

| File | Status |
|------|--------|
| `docs/data-source-validation.md` | ✅ Written (8 tables + summary) |
| `.omo/evidence/task-2-validation.md` | ✅ Written (this file) |
| `issues.md` | No issues to report (no file exists, no critical blocks) |

## Task Complete
- [x] 5 endpoints tested + documented with URL, status, date range, format, row count
- [x] Binance data.vision returns 200 for BTCUSDT funding rate ZIP
- [x] Binance API returns JSON with fundingRate key
- [x] Deribit API returns JSON with funding data (hourly, since 2020)
- [x] BitMEX equity perps tested (empty, XBTUSD works)
- [x] AlgoTick S3 blocked, Hyperliquid fallback documented
- [x] Binance premiumIndex tested and confirmed
