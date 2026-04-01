---
name: compare-portfolio
description: Compare US portfolio holdings between Google Sheet (source of truth updated by portfolio-sync) and SavvyTrader. Flags missing tickers and quantity drift above tolerance.
---

# compare-portfolio

Compare US portfolio holdings between the Google Sheet and SavvyTrader. Surface discrepancies — missing positions or quantity drift — so sync issues are caught early.

---

## Configuration

- **Sheet ID:** `YOUR_GOOGLE_SHEET_ID`
- **Tab:** `US Portfolio`
- **Sheet columns:** Theme (A), Ticker (B), % (C), Quantity (D), Holdings (E), Conviction (F)
- **Data range:** `US Portfolio!A2:F100` — skip header row; ignore trailing rows where column B is a number or empty (totals/metadata rows)
- **Quantity tolerance:** 0.1 shares (differences below this are rounding artifacts from the sheet storing 2 decimal places)

---

## Steps

### 1. Fetch both sources in parallel

**Google Sheet:**
Run: `gws sheets spreadsheets values get --params "{\"spreadsheetId\": \"YOUR_GOOGLE_SHEET_ID\", \"range\": \"US Portfolio!A2:F100\"}"`

(Must use double-quote escaping — single quotes break on `!` in the range string)

Parse rows where column B (index 1) looks like a valid ticker (letters only, 1–5 chars). Skip rows where column B is numeric, empty, or clearly a metadata row. Extract: ticker → quantity (column D, strip commas).

**SavvyTrader:**
Call `mcp__savvytrader__get_holdings`. Extract the `holdings` array. Each entry has `symbol` and `quantity`.

### 2. Compare

- **Only in Sheet:** tickers present in sheet but not SavvyTrader
- **Only in SavvyTrader:** tickers present in SavvyTrader but not sheet
- **Quantity mismatches:** for tickers in both, `abs(sheet_qty - savvy_qty) > 0.1`
- **In sync:** everything else

### 3. Report

Print a summary in this format:

```
=== US Portfolio Comparison ===
Sheet: N tickers | SavvyTrader: N tickers

✅ All tickers present in both  (or list missing ones)

⚠️  QUANTITY MISMATCHES (diff > 0.1 shares):
  Ticker   Sheet Qty   SavvyTrader Qty   Diff   Action
  ------   ---------   ---------------   ----   ------
  META     32.05       31.998698         0.05   within rounding (< 0.1)

✅ All quantities in sync  (or show mismatch table)

Last synced: <updatedDate of most recently updated SavvyTrader holding>
```

If everything is clean, keep it short — one line per check with a ✅. Only expand into tables when there are actual issues.

If there are mismatches above tolerance, suggest the likely cause:
- Ticker only in SavvyTrader → may have been added manually there, not yet synced to sheet
- Ticker only in Sheet → position may have been closed in brokerage but sync hasn't run
- Large quantity diff → partial fill or sync ran before trade settled
