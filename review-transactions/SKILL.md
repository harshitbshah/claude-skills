---
name: review-transactions
description: Review Monarch Money transactions that need categorization. Uses saved patterns to suggest categories instantly, fetches history only for unknowns, and learns from every confirmed run.
---

# review-transactions

Review Monarch Money transactions that need review. Use saved patterns first — only fetch history for unknowns. Learn from every confirmed categorization.

---

## Pattern file

Read `~/.claude/skills/review-transactions/monarch-patterns.json` at the start of every run. If it doesn't exist, treat patterns as an empty array.

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
- `learning` — seen 1–2×, no overrides → still fetch history as cross-check
- `confident` — seen 3+×, overrides == 0 → skip history entirely
- `uncertain` — overrides > 0 on last confirmation → fetch history, treat as unknown

**Matching logic:** For each transaction, find the first pattern where:
1. `match_type` is satisfied against the transaction description (case-insensitive)
2. `account_hint` is null OR the account name contains the hint (case-insensitive)

---

## Steps

### 1. Fetch needs-review transactions
Call `mcp__monarch-money__get_transactions` with `needs_review: true`. No date filter.

If none found → say "No transactions need review." and stop immediately. Do not make any further API calls.

**Categories (cached permanently):** Read `~/.claude/skills/review-transactions/categories-cache.json`. If it exists, use it — do not call the API. If missing, call `mcp__monarch-money__get_transaction_categories` once and write the result to the cache file as:
```json
{ "categories": [ ... ] }
```
To force a refresh, delete the cache file manually.

### 2. Classify each transaction

For each transaction:

**A. Check patterns** (from the JSON file above):
- If a `confident` pattern matches → use it. Source = `📚 confident (seen N×)`
- If a `learning` pattern matches → use it as suggestion but still fetch history. Source = `📖 learning (seen N×) — cross-checking`
- If an `uncertain` pattern matches → treat as unknown. Source = `⚠️ uncertain (overridden before)`
- If no pattern matches → unknown

**B. For unknowns and learning/uncertain matches:**
Call `mcp__monarch-money__get_transactions` filtered to the same account, looking at the last 30 transactions with the same merchant name or similar description. Find the most common category used historically. If found → use it. Source = `📊 from history`

If history is also inconclusive → make a best guess based on merchant type. Source = `🤔 best guess`

### 3. Present review table

Show a table:

| # | Date | Account | Description | Amount | Suggested Category | Source |
|---|------|---------|-------------|--------|--------------------|--------|

Below the table:
```
Reply with:
  ok / apply   → apply all suggestions as-is
  skip 2, 4    → skip those row numbers
  3=Medical    → override category for row 3 (can combine: "ok, 3=Medical, 5=Transfer")
  cancel       → abort, nothing changes
```

### 4. Wait for user confirmation

Parse the reply:
- `ok` or `apply` → apply all
- `skip N` → remove those rows
- `N=Category` → update that row's category before applying (find best matching category ID from the categories list)
- `cancel` → stop

### 5. Apply updates

For each transaction being applied:
- Call `mcp__monarch-money__update_transaction` with the transaction ID, category ID, and `needs_review: false`

Track successes and failures.

### 6. Update the pattern file

After applying, update `~/.claude/skills/monarch-patterns.json`:

For each applied transaction:
- **If the suggestion came from a `confident` or `learning` pattern and user did NOT override:**
  - Increment `seen` by 1
  - Update `last_seen` to today
  - Recalculate `confidence`: seen >= 3 and overrides == 0 → `confident`, else `learning`

- **If the suggestion came from a pattern but user overrode the category:**
  - Increment `overrides` by 1
  - Set `confidence` to `uncertain`
  - Update `last_seen`
  - Also add a NEW pattern entry for the overridden category (seen: 1, confidence: learning)

- **If the suggestion came from history or was a best guess and user confirmed it:**
  - Check if a pattern already exists for this merchant+account_hint
  - If yes → increment seen, update confidence
  - If no → add a new pattern: match = merchant name (or significant words from description), match_type = `substring`, seen: 1, confidence: `learning`

- **Skipped transactions:** do not update patterns for them

Write the updated JSON back to `~/.claude/skills/review-transactions/monarch-patterns.json`.

### 7. Report

Print a short summary:
- N updated, N skipped, N failed
- N new patterns learned, N existing patterns updated
- Which patterns are now `confident` (if any newly crossed the threshold)
