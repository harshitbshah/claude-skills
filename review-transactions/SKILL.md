---
name: review-transactions
description: Review Monarch Money transactions that need categorization. Uses saved patterns to suggest categories instantly, fetches history only for unknowns, and learns from every confirmed run.
---

# review-transactions

Two-phase transaction review:
- **Phase 1** — transactions Monarch flagged `needs_review` (always runs, no date limit)
- **Phase 2** — all transactions since `last_reviewed`, audited against patterns to catch mismatches and unknowns

---

## Startup: read these files first

1. **`~/.claude/skills/review-transactions/monarch-patterns.json`** — categorization rules. If missing, treat as empty array.
2. **`~/.claude/skills/review-transactions/account-context.md`** — account structure and financial setup context. Read this to correctly classify investment account activity.
3. **`~/.claude/skills/review-transactions/state.json`** — watermark. If missing, use 30 days ago as default `last_reviewed`.
4. **`~/.claude/skills/review-transactions/categories-cache.json`** — category list. If missing, call `mcp__monarch-money__get_transaction_categories` once and write it as `{ "categories": [ ... ] }`. Never re-fetch if it exists.

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
  "last_seen": "2026-03-28",
  "note": ""
}
```

**Confidence rules:**
- `learning` — seen 1–2×, no overrides
- `confident` — seen 3+×, overrides == 0
- `uncertain` — overrides > 0 on last confirmation

**Matching logic:** For each transaction, find the first pattern where:
1. `match_type` is satisfied against the transaction description (case-insensitive)
2. `account_hint` is null OR the account name contains the hint (case-insensitive)

---

## Phase 1 — Needs Review

### 1. Fetch
Call `mcp__monarch-money__get_transactions` with `needs_review: true`. No date filter.

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

For each applied transaction: call `mcp__monarch-money__update_transaction` with the category ID and `needs_review: false`.

Track Phase 1 IDs that were processed — Phase 2 will skip them to avoid double-handling.

### 5. Update patterns (Phase 1)

For each applied transaction:
- **Confident/learning match, no override:** increment `seen`, update `last_seen`, recalculate confidence (seen ≥ 3 and overrides == 0 → `confident`)
- **Pattern matched but user overrode:** increment `overrides`, set confidence to `uncertain`, update `last_seen`. Add NEW pattern for the overridden category (seen: 1, confidence: `learning`)
- **History/best-guess confirmed:** check if pattern exists for this merchant — if yes, increment seen; if no, add new pattern (match_type: `substring`, seen: 1, confidence: `learning`)
- **Skipped:** no pattern update

---

## Phase 2 — Pattern Audit

```
── Phase 2: Pattern Audit (since YYYY-MM-DD) ──────────
```

### 1. Fetch
Call `mcp__monarch-money__get_transactions` with `start_date: last_reviewed`, `end_date: today`, `limit: 100`.

Exclude any transaction IDs already processed in Phase 1.

### 2. Classify and flag

For each transaction, run the pattern engine and compare against Monarch's current category:

| Situation | Action | Flag |
|-----------|--------|------|
| `confident` pattern matches AND agrees with Monarch's category | Skip silently | — |
| `confident` pattern matches AND **disagrees** with Monarch's category | FLAG — suggest pattern's category | 🔴 mismatch |
| `learning` or `uncertain` pattern matches | FLAG — suggest pattern's category, verify | 🟡 low confidence |
| No pattern, Monarch assigned a category | FLAG — fetch history, suggest best category | 🟠 unknown |

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

For each applied transaction: call `mcp__monarch-money__update_transaction` with the corrected category ID. Set `needs_review: false`.

### 5. Update patterns (Phase 2)

Same pattern update rules as Phase 1 step 5.

For 🔴 mismatch transactions where Monarch was wrong and we applied the correct category: increment the pattern's `seen` count (the pattern was right, Monarch was wrong — confidence should grow).

### 6. Update state

Write `~/.claude/skills/review-transactions/state.json`:
```json
{ "last_reviewed": "today's date" }
```

Update this **only after Phase 2 confirm** (or after Phase 1 if user passed `skip-phase2`).

---

## Final Report

```
── Summary ────────────────────────────────────────────
Phase 1 (needs review):  N updated · N skipped · N failed
Phase 2 (audit):         N updated · N skipped · N failed

Patterns: N new · N updated · N newly confident
Next audit will start from: YYYY-MM-DD
```
