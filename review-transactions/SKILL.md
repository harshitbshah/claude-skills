---
name: review-transactions
description: Review Monarch Money transactions that need categorization. Uses saved patterns to suggest categories instantly, fetches history only for unknowns, and learns from every confirmed run.
---

# review-transactions

## Long-term goal

The skill is a **learning layer**, not a permanent fixture. The intended progression:

```
unknown → learning pattern → confident pattern → Monarch rule → silent pass forever
```

Once a confident pattern is promoted to a **Monarch Transaction Rule** (created by the skill via
the "create rule" tool below after the user approves), Monarch auto-categorizes those transactions correctly on import. The skill then has
nothing to flag and the Phase 2 list shrinks toward zero over time.

Monarch native features to leverage:
- **Transaction Rules** — if description/merchant contains or equals X (no regex support), set
  category to Y (and optionally rename the merchant). Direct equivalent of a confident pattern.
  The skill creates these itself — see "Rule promotion" at the end.
- **Merchant corrections** — when you manually recategorize, Monarch offers "apply to all future
  transactions from this merchant?" Use this for one-off merchants.

The skill tracks whether each pattern has been promoted via a `monarch_rule` boolean field. At the
end of every run it lists patterns that are ready to promote and, on approval, creates the Monarch
Rules and flips the flag.

---

Two-phase transaction review:
- **Phase 1** — transactions Monarch flagged `needs_review` (always runs, no date limit)
- **Phase 2** — all transactions since `last_reviewed`, audited against patterns to catch mismatches and unknowns

---

## Monarch tools

Two MCP servers may be connected: the **official** one (`mcp__monarch__*`, OAuth) and the
**community** one (`mcp__monarch-money__*`, cookie auth). Prefer official; fall back to community
per call when the official tool isn't available or errors. Steps below use the logical names.

| Logical | Official | Community |
|---|---|---|
| get categories | `GetCategories` | `get_transaction_categories` |
| get accounts | `GetAccounts` | `get_accounts` |
| get transactions | `GetTransactions` | `get_transactions` |
| update transaction | `UpdateTransaction` | `update_transaction` |
| list rules | `ListRules` | `get_transaction_rules` |
| create rule | `CreateRule` (merchant-name criteria only) | `create_transaction_rule` |

Argument differences on the official server:
- Every call needs `intent: "organizing_finances"`.
- `GetTransactions`: filters go in a JSON string, e.g. `filters: '{"transaction_type": "All",
  "needs_review": true}'`; `start_date`/`end_date` are required (use `2020-01-01` → today for
  "no date filter"); free-text search goes in the filters JSON as `"search"`. Page with
  `offset`/`next_offset` (max `limit` 100).
- `UpdateTransaction`: `category_id` and `review_status: "reviewed"` (instead of `needs_review: false`).
- IDs (categories, accounts) are the same across both servers, so `categories-cache.json` works with either.

---

## Startup: read these files first

1. **`~/.claude/skills/review-transactions/monarch-patterns.json`** — categorization rules. If missing, treat as empty array.
2. **`~/.claude/skills/review-transactions/account-context.md`** — account structure and financial setup context. Read this to correctly classify investment account activity.
3. **`~/.claude/skills/review-transactions/state.json`** — watermark. If missing, use 30 days ago as default `last_reviewed`.
4. **`~/.claude/skills/review-transactions/categories-cache.json`** — category list. If missing, call "get categories" once and write it as `{ "categories": [ ... ] }`. Never re-fetch if it exists.

**state.json shape:**
```json
{ "last_reviewed": "2026-04-13" }
```

---

## Pattern file reference

Each pattern entry:
```json
{
  "match": "AMAZON",
  "match_type": "substring",   // "substring" | "regex" | "exact"
  "account_hint": null,        // null = any account; string = only match if account name contains this
  "category": "Shopping",
  "seen": 5,
  "overrides": 0,
  "confidence": "confident",   // "learning" | "confident" | "uncertain"
  "monarch_rule": false,       // true = a Monarch Rule exists for this; skill skips flagging it
  "last_seen": "2026-03-28",
  "note": ""
}
```

**Confidence rules:**
- `learning` — seen 1–2×, no overrides
- `confident` — seen 3+×, overrides == 0
- `uncertain` — overrides > 0 on last confirmation

**`monarch_rule` flag:**
- `false` (default) — pattern is local only; skill actively monitors these transactions
- `true` — a Monarch Rule covers this merchant/pattern. In Phase 2, if Monarch's category agrees
  with the pattern → skip silently. Only flag if Monarch **disagrees** (rule may be broken or
  overridden). Never flag these as 🟠 unknown.

**Matching logic:** For each transaction, find the first pattern where:
1. `match_type` is satisfied against the transaction description (case-insensitive)
2. `account_hint` is null OR the account name contains the hint (case-insensitive)

---

## Phase 1 — Needs Review

### 1. Fetch
Call "get transactions" with the needs-review filter. No date filter.

If none found → print "✓ No transactions need review." and proceed directly to Phase 2.

### 2. Classify each transaction

**A. Check patterns:**
- `confident` match → use it. Source = `📚 confident (seen N×)`
- `learning` match → use it as suggestion, still fetch history to cross-check. Source = `📖 learning (seen N×)`
- `uncertain` match → treat as unknown. Source = `⚠️ uncertain (overridden before)`
- No match → unknown

**B. For unknowns and learning/uncertain matches:**
Fetch last 30 transactions for same merchant/account. Use most common category. Source = `📊 from history`
If inconclusive → best guess based on merchant type. Source = `🤔 best guess`

### 3. Present table

```
── Phase 1: Needs Review ──────────────────────────────
```

| # | Date | Account | Description | Amount | Suggested Category | Source |
|---|------|---------|-------------|--------|--------------------|--------|

```
Reply with: ok · skip 2,4 · 3=Medical · cancel · skip-phase2
```

`skip-phase2` — confirm Phase 1 but skip Phase 2 this run.

### 4. Wait for confirmation, then apply

- `ok` / `apply` → apply all
- `skip N` → skip those rows
- `N=Category` → override that row's category
- `cancel` → abort everything
- `skip-phase2` → apply Phase 1, then stop before Phase 2

For each applied transaction: call "update transaction" with the category ID and mark it reviewed.

Track Phase 1 IDs that were processed — Phase 2 will skip them to avoid double-handling.

### 5. Update patterns (Phase 1)

For each applied transaction:
- **Confident/learning match, no override:** increment `seen`, update `last_seen`, recalculate confidence (seen ≥ 3 and overrides == 0 → `confident`)
- **Pattern matched but user overrode:** increment `overrides`, set confidence to `uncertain`, update `last_seen`. Add NEW pattern for the overridden category (seen: 1, confidence: `learning`, monarch_rule: false)
- **History/best-guess confirmed:** only add a pattern if Monarch's categorization is *unreliable* for this merchant — i.e. Monarch got it wrong before, or it's a merchant type known to be miscategorized. If Monarch's category is obviously correct and the merchant type is one Monarch handles reliably (e.g. investment buy/sell, standard bank transfers), skip pattern creation — a pattern that just mirrors what Monarch already does right adds no value. If adding: check if pattern exists — if yes, increment seen; if no, add new pattern (match_type: `substring`, seen: 1, confidence: `learning`, monarch_rule: false).
- **Skipped:** no pattern update

---

## Phase 2 — Pattern Audit

```
── Phase 2: Pattern Audit (since YYYY-MM-DD) ──────────
```

### 1. Fetch
Call "get transactions" with `start_date: last_reviewed`, `end_date: today`, `limit: 100` (page if more).

Exclude any transaction IDs already processed in Phase 1.

### 2. Classify and flag

For each transaction, run the pattern engine and compare against Monarch's current category:

| Situation | Action | Flag |
|-----------|--------|------|
| `confident` pattern, `monarch_rule: true`, Monarch agrees | Skip silently | — |
| `confident` pattern, `monarch_rule: true`, Monarch **disagrees** | FLAG — rule may be broken | 🔴 rule broken |
| `confident` pattern, `monarch_rule: false`, Monarch agrees | Skip silently | — |
| `confident` pattern, `monarch_rule: false`, Monarch **disagrees** | FLAG — suggest pattern's category | 🔴 mismatch |
| `learning` or `uncertain` pattern | FLAG — suggest pattern's category, verify | 🟡 low confidence |
| No pattern, Monarch assigned a category, self-evident | Skip silently | — |
| No pattern, Monarch assigned a category, not self-evident | FLAG — fetch history, suggest best category | 🟠 unknown |

**Self-evident rule:** A transaction is self-evident if Monarch's category can be confirmed directly from the description without any external context. Skip these silently — no history fetch, no flag, no pattern creation. Examples:
- Description starts with `"buy -"` and Monarch says Buy
- Description starts with `"sell -"` and Monarch says Sell
- Description contains `"ACH"`, `"transfer"`, `"wire"`, or `"ext trnsfr"` (case-insensitive) and Monarch says Transfer
- Description contains `"dividend"` and Monarch says Dividends & Capital Gains
- Description contains `"interest"` and Monarch says Interest

If self-evident but Monarch's category *disagrees* with what the description implies → treat as 🔴 mismatch and flag it.

For 🟠 unknowns: fetch history for the merchant (same as Phase 1 step 2B) to form a suggestion. If Monarch's category matches history → keep Monarch's category as suggestion (source: `📊 history confirms`). If history conflicts → suggest history's category (source: `📊 history`). If no history → suggest Monarch's category as default (source: `🤔 Monarch's guess — unverified`).

Skip transactions under $1.00 with no pattern — too noisy to be useful.

If no transactions are flagged → print "✓ No categorization issues found since [date]." and skip to the update step.

### 3. Present table

| # | Date | Account | Description | Amount | Monarch Says | Suggested | Flag |
|---|------|---------|-------------|--------|--------------|-----------|------|

```
Reply with: ok · skip 2,4 · 3=Medical · cancel
```

### 4. Wait for confirmation, then apply

For each applied transaction: call "update transaction" with the corrected category ID and mark it reviewed.

### 5. Update patterns (Phase 2)

Same pattern update rules as Phase 1 step 5.

For 🔴 mismatch/rule-broken transactions where Monarch was wrong and we applied the correct category: increment the pattern's `seen` count (the pattern was right, Monarch was wrong — confidence should grow).

### 6. Update state

Write `~/.claude/skills/review-transactions/state.json`:
```json
{ "last_reviewed": "today's date" }
```

Update this **only after Phase 2 confirm** (or after Phase 1 if user passed `skip-phase2`).

---

## Roth IRA Spreadsheet Auto-Update

**Spreadsheet path:** `/home/harshit-shah/gdrive/Important Documents/Documents/Investments/Roth IRA .xlsx`  
**Sheet:** `Sheet1` — columns: `Year | Contributions | Change In Market Value | Withdrawals`

Run this step automatically after Phase 2 confirm, before the Final Report. No user prompt needed unless something is ambiguous.

### 1. Identify new rollovers

From the Phase 2 transaction set, find all transactions where:
- Description contains `"ROLLOVER CASH DIRECT ROLLOVER"` (case-insensitive)
- Account contains `"ROTH IRA"`

These are the mega backdoor Roth rollovers arriving from the Amazon 401k.

### 2. Find the matching realizedGainLoss

For each rollover, fetch 401k transactions within ±2 days of the rollover date:
```
get transactions(
  start_date: rollover_date - 2 days,
  end_date:   rollover_date + 2 days,
  search:     "realizedGainLoss"     # official: inside the filters JSON
)
```
Filter to account containing `"401"`. The matching entry will have a date 1 day before the rollover. Its `amount` is the Change in Market Value. If no match found, use `0.00`.

### 3. Check for duplicates

Load the spreadsheet with openpyxl. A row is already present if a row exists with the same `Year` AND `Contributions` value (exact float match). Skip duplicates silently.

### 4. Append new rows

For each new rollover not already in the spreadsheet, write directly below the last row that has data. Do NOT use `ws.append()`: the sheet has ~1000 pre-formatted empty rows, so `append()` lands at row 1001+ (this happened 2026-04/05 and had to be moved by hand).
```python
import copy
last = max(r for r in range(1, ws.max_row + 1) if ws.cell(r, 1).value is not None)
for i, (year, contribution_amount, realized_gain_loss) in enumerate(new_rows, start=1):
    ws.row_dimensions[last + i].height = ws.row_dimensions[last].height  # data rows are 22.5pt; empty rows default to 15.75
    for c, v in enumerate([year, contribution_amount, realized_gain_loss, None], start=1):
        ws.cell(last + i, c).value = v
        ws.cell(last + i, c)._style = copy.copy(ws.cell(last, c)._style)
wb.save(path)
```

### 5. Report in summary

Add a line to the Final Report:
```
Roth IRA sheet:      N rows added · [amounts]
```
If nothing added: `Roth IRA sheet: ✓ already up to date`

---

## Final Report

```
── Summary ────────────────────────────────────────────
Phase 1 (needs review):  N updated · N skipped · N failed
Phase 2 (audit):         N updated · N skipped · N failed

Patterns: N new · N updated · N newly confident

Next audit will start from: YYYY-MM-DD
```

### Rule promotion suggestions

**Promotion threshold:** `seen >= 5` AND `overrides == 0` AND `monarch_rule == false`.

This is higher than the `confident` bar (3+) because a Monarch Rule applies globally with no
review — you want to be sure before making it permanent. Infrequent merchants may never hit the
threshold; that's fine, the skill keeps handling them.

After the summary, list every pattern meeting the threshold, showing the exact rule each one would
become:

```
── Ready to promote to Monarch Rules ──────────────────
These patterns have been seen 5+ times with no overrides.

  1. Original statement contains "rollover cash direct rollover" (account: ROTH IRA) → Transfer  [seen: 20]
  2. Merchant name equals "contribution" (account: AMAZON 401(K)) → Retirement Contributions  [seen: 6]
  ...

Reply with: promote all · promote 1,3 · skip
```

**Never create rules without this confirmation.** Rules apply globally with no review.

On approval, for each selected pattern:
1. **Check for an existing rule first.** Call "list rules" once and
   look for a rule with the same criteria value (case-insensitive) and the same account scope.
   Official `ListRules` shows the value under `merchant_names`, `merchant_names_legacy` or
   `original_statement_values`; community shows `*_criteria` arrays. If
   one exists and already sets the pattern's category, skip creating and just mark
   `monarch_rule: true`. If it exists but sets a different category, report it and don't touch it.
2. **Map the pattern to a rule:**
   - `match_type: "substring"` → operator `contains`; `"exact"` → operator `eq`.
   - `match_type: "regex"` → **do not create** (Monarch rules don't support regex). Report it as
     "needs manual rewrite as substring/exact".
   - Criterion field: use `original_statement_criteria` (patterns match the raw description).
   - `account_hint` → resolve to account ID(s) via "get accounts" (account
     display name contains the hint, case-insensitive). If the hint matches 0 accounts or more
     than one, stop and ask instead of guessing.
   - Category → `set_category_action` with the ID from `categories-cache.json`.
   - Add `set_merchant_action` only if the user asks for a merchant rename too.
   - Leave `apply_to_existing_transactions` off unless the user asks to backfill.
3. **Pick the server.** Official `CreateRule` only matches on merchant name, not original
   statement, and can't backfill existing transactions. So:
   - Community `create_transaction_rule` connected → use it (supports everything above), e.g.:
     ```json
     { "rule": {
         "original_statement_criteria": [{ "operator": "contains", "value": "rollover cash direct rollover" }],
         "account_ids": ["<roth ira account id>"],
         "set_category_action": "<Transfer category id>"
     } }
     ```
   - Only official connected → don't silently convert a statement pattern into a merchant-name rule
     (merchant names are Monarch-cleaned and often differ from the raw description). Show the user
     the transaction's merchant name next to the pattern and offer: (a) create a merchant-name rule
     with `CreateRule(merchant_names: [...], account_ids: [...], set_category_id: ...)`, or
     (b) leave it for them to create in the Monarch web app. If backfill was requested, tell them to
     run the rule from its detail page in the web app.
4. On success, set `monarch_rule: true` on that pattern in `monarch-patterns.json`. On error, leave
   the flag false and report the error message.

Add a line to the Final Report: `Monarch rules: N created · N already existed · N failed`.

If no patterns meet the threshold → print nothing (skip this section).
If all eligible patterns already have `monarch_rule: true` → print:
```
✓ All promotion-ready patterns have Monarch Rules — nothing to promote.
```
