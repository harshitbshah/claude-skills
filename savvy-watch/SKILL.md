---
name: savvy-watch
description: Fetch holdings and recent trades for all 4 tracked SavvyTrader portfolios. Shows tabular output and flags new trades + holdings changes since the last run.
---

# savvy-watch

Fetch and display holdings + trades for all 4 tracked SavvyTrader portfolios in a compact tabular format. Diffs against the last run to surface what's changed.

---

## Tracked portfolios

| ID   | Handle         | Name                          | Holdings type |
|------|----------------|-------------------------------|---------------|
| 5298 | TraderJac      | Jacquelyn's Portfolio         | % only        |
| 1228 | Dillon_Valdez  | BluSuits Growth Investing     | % only        |
| 454  | austinl        | Austin Lieberman Growth Curve | % only        |
| 4899 | Couch_Investor | Couch Investing               | Full (qty + $)|

---

## State file

Path: `~/.claude/skills/savvy-watch/state.json`

Shape:
```json
{
  "last_run": "2026-04-28",
  "portfolios": {
    "5298": [{"symbol": "WEAT", "alloc_pct": 13.0}, ...],
    "1228": [...],
    "454":  [...],
    "4899": [{"symbol": "NBIS", "alloc_pct": 15.5, "qty": 520}, ...]
  }
}
```

If missing → treat `last_run` as null and `portfolios` as empty (first run, no diff).

---

## Steps

### 1. Load state

Read `~/.claude/skills/savvy-watch/state.json`. Note `last_run` date and previous holdings snapshots per portfolio.

### 2. Fetch all 4 portfolios

Call `mcp__savvytrader__get_portfolio_summary` for each portfolio **sequentially** (the MCP client is a singleton — parallel calls hit a shared token state). Use default `trades_limit: 20`. Pass `username` and `slug` to get live performance figures.

| portfolio_id | username | slug |
|---|---|---|
| 5298 | TraderJac | jacquelyn-portfolio |
| 1228 | Dillon_Valdez | blusuits-growth-investing-portfolio |
| 454 | austinl | tgc |
| 4899 | Couch_Investor | couch-investing |

For each portfolio, split the returned trades into three buckets:
- **actual_trades** — `type` is `buy` or `sell`
- **comments** — `type` is `comment`, has a non-empty `comment` field
- **today_trades** — any actual trade where `date` == today's date

### 3. Today's activity (print first, before per-portfolio sections)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TODAY  2026-04-29
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TraderJac       BUY CORN $18.80 · BUY UNH $368.79 · SELL UNH $367.70 · +7 more
Dillon_Valdez   no trades
austinl         no trades
Couch_Investor  no trades
```

- One line per portfolio, compact inline format: `TYPE SYMBOL $PRICE` separated by ` · `
- If more than 4 trades, show first 4 then `· +N more`
- If no trades today for any portfolio → print `No trades today across all portfolios.`

### 4. Display each portfolio

For each portfolio print this block:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TraderJac — Jacquelyn's Portfolio  (ID: 5298)
Value: pct-only  |  Total gain: +0.5%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

HOLDINGS                          [changes vs last run]
Symbol    Alloc%    Gain%   Value
------    ------    -----   -----
WEAT       13.0%    -1.2%
DBA        15.8%    +0.7%
CASH       24.3%

TRADES  (20 of 68 actual trades shown, ★ = since last run)
Date         Type   Symbol    Price
----------   ----   ------    -----
★2026-04-29  BUY    CORN    $ 18.80
★2026-04-29  SELL   UNH     $367.70

COMMENTS & NEWSLETTERS  (2 since last run)
2026-04-17  DOCN  "DigitalOcean still gets framed like a smaller, cheaper AWS..."
2026-03-25  YSS   "THE MACRO TAILWIND — WHY SPACE IS THE DECADE'S DEFINING..."
```

**Holdings table rules:**
- Show `Value` column only for Couch Investor (ID 4899, full data). Omit for others.
- `Gain%` uses `+`/`-` prefix.
- Append a change tag after the row for positions that differ from last run:
  - `[NEW]` — symbol not in previous snapshot
  - `[EXITED]` — symbol in previous snapshot but not current (print as a separate row in brackets)
  - `[+2.1%]` or `[-1.8%]` — alloc changed by ≥ 1.5 percentage points vs last run

**Trades table rules:**
- Show only actual buy/sell trades (exclude `comment` type entries).
- Show at most 20. Header shows total actual trades retrieved.
- Prefix rows since `last_run` with `★`.
- Omit the comment column from the trades table entirely (comments have their own section).

**Comments & newsletters section rules:**
- Only show if there are any `comment`-type entries in the fetched trades.
- Header shows count since `last_run`. Show all of them (not capped at 20).
- Show date, symbol, and the first 120 chars of the comment text in quotes.
- Prefix entries since `last_run` with `★`.
- If no comments in fetched data → omit this section entirely.

### 5. Diff summary (after all 4 portfolios)

Print a single cross-portfolio summary block:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHANGES SINCE 2026-04-28
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TraderJac     10 new trades · 0 new comments  |  DBA +3.8%  CORN [NEW]
Dillon_Valdez  3 new trades · 1 new comment   |  no holdings change
austinl        0 new trades · 0 new comments  |  no holdings change
Couch_Investor 1 new trade  · 0 new comments  |  SOFI +4.2%
```

If it's the first run (no state), skip the diff and print: `First run — no previous state to compare.`

### 5. Refresh vault doc

Path: `~/Documents/Vault/SavvyTrader Portfolios.md`

Rewrite the holdings table for each portfolio using the freshly fetched data. Keep all static fields (URL, Strategy, Performance) unchanged — only update `Last updated` and the `### Holdings` table. Sort holdings rows by alloc% descending; Cash always last.

**Table format per portfolio type:**

Pct-only portfolios (TraderJac ID 5298, Dillon_Valdez ID 1228, austinl ID 454):
```markdown
| Symbol | Alloc | Gain |
|--------|-------|------|
| WEAT | 13.0% | -1.2% |
| CASH | 24.3% | — |
```

Full-data portfolio (Couch_Investor ID 4899):
```markdown
| Symbol | Shares | Avg Cost | Price | Value | Alloc | Return |
|--------|--------|----------|-------|-------|-------|--------|
| NBIS | 520 | $47.26 | $135.51 | $70,465 | 15.5% | +187% |
| CASH | — | — | — | $15,265 | 3.4% | — |
```

Field mapping from the API response:
- `Shares` ← `qty`
- `Avg Cost` ← `pricePerShare` from raw holdings (average cost basis)
- `Price` ← `currentPricePerShare` from raw holdings
- `Value` ← `value` (only in full-data portfolios)
- `Alloc` ← `alloc_pct`
- `Gain`/`Return` ← `gain_pct`

Update `Last updated: YYYY-MM-DD` at the top of the file to today's date.

Write the file directly — do not create a backup.

### 6. Save state

Write `~/.claude/skills/savvy-watch/state.json` with:
- `last_run`: today's date (YYYY-MM-DD)
- `portfolios`: for each portfolio ID, the current holdings as `[{symbol, alloc_pct, qty (if available)}]`

---

## Error handling

- If a portfolio call returns `{"error": ...}` → print `⚠️ [Portfolio Name]: <error message>` and continue with the others.
- If the MCP server is not responding (auth expired) → print `⚠️ SavvyTrader MCP unavailable — run savvytrader-login to refresh auth.` and stop.
