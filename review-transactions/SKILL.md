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

Once a confident pattern is promoted to a **Monarch Transaction Rule** (Settings → Rules in the
Monarch UI), Monarch auto-categorizes those transactions correctly on import. The skill then has
nothing to flag and the Phase 2 list shrinks toward zero over time.

Monarch native features to leverage:
- **Transaction Rules** — if description contains X (or regex), set category to Y. Direct
  equivalent of a confident pattern. Create these in Settings → Rules.
- **Merchant corrections** — when you manually recategorize, Monarch offers "apply to all future
  transactions from this merchant?" Use this for one-off merchants.

The skill tracks whether each pattern has been promoted via a `monarch_rule` boolean field. At the
end of every run it lists patterns that are ready to promote so you can add them to Monarch in one
sitting.

---

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
- **Pattern matched but user overrode:** increment `overrides`, set confidence to `uncertain`, update `last_seen`. Add NEW pattern for the overridden category (seen: 1, confidence: `learning`, monarch_rule: false)
- **History/best-guess confirmed:** check if pattern exists for this merchant — if yes, increment seen; if no, add new pattern (match_type: `substring`, seen: 1, confidence: `learning`, monarch_rule: false)
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
| `confident` pattern, `monarch_rule: true`, Monarch agrees | Skip silently | — |
| `confident` pattern, `monarch_rule: true`, Monarch **disagrees** | FLAG — rule may be broken | 🔴 rule broken |
| `confident` pattern, `monarch_rule: false`, Monarch agrees | Skip silently | — |
| `confident` pattern, `monarch_rule: false`, Monarch **disagrees** | FLAG — suggest pattern's category | 🔴 mismatch |
| `learning` or `uncertain` pattern | FLAG — suggest pattern's category, verify | 🟡 low confidence |
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

For 🔴 mismatch/rule-broken transactions where Monarch was wrong and we applied the correct category: increment the pattern's `seen` count (the pattern was right, Monarch was wrong — confidence should grow).

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

### Rule promotion suggestions

**Promotion threshold:** `seen >= 5` AND `overrides == 0` AND `monarch_rule == false`.

This is higher than the `confident` bar (3+) because a Monarch Rule applies globally with no
review — you want to be sure before making it permanent. Infrequent merchants may never hit the
threshold; that's fine, the skill keeps handling them.

After the summary, list every pattern meeting the threshold:

```
── Ready to promote to Monarch Rules ──────────────────
These patterns have been seen 5+ times with no overrides. Add them in Settings → Rules to
eliminate future flags entirely.

  1. Description contains "ROLLOVER CASH DIRECT ROLLOVER" (account: Roth IRA) → Transfer  [seen: 20]
  2. Description contains "contribution" exact match (account: 401k) → Retirement Contributions  [seen: 6]
  3. Description matches regex "^IA \d+\.\d+$" (account: HSA) → HSA  [seen: 8]
  ...

Once added, set monarch_rule: true in monarch-patterns.json for each one.
```

If no patterns meet the threshold → print nothing (skip this section).
If all eligible patterns already have `monarch_rule: true` → print:
```
✓ All promotion-ready patterns have Monarch Rules — no manual action needed.
```
