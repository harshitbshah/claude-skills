---
name: cashflow-review
description: Monthly cashflow retrospective for Monarch Money. Compares the month against your own trailing history (not a generic budget), flags real anomalies vs known seasonal expenses, and builds a growing picture of your spending trends over time.
---

# cashflow-review

## Purpose

Monarch's own Cashflow view is great for looking at one month in isolation. This skill exists for
the thing it doesn't do: **remember**. Every run appends the month's numbers to a local history
file, so over time the skill can tell you "Groceries is up 18% vs your 6-month average" instead of
just re-reporting this month's total. It's a monthly ritual, not a hygiene pass — run
`/review-transactions` first so the categorization underneath this analysis is trustworthy.

It also doubles as a standing knowledge base for ad-hoc financial questions ("what am I paying for
newsletter subscriptions", "how much did Travel cost me this year") — see "Answering ad-hoc
analytical questions" below. Every month reviewed makes both the monthly ritual and these ad-hoc
answers better, since they draw from the same `history.json`/`insights.json` files.

## Long-term goal

```
raw monthly numbers → trailing baseline per category → real anomaly detection → learned seasonal context
```

The more months in `history.json`, the sharper the baselines get. The more anomalies you annotate,
the fewer false alarms `insights.json` produces (a property tax spike in January should never be
flagged again once you've confirmed it's semi-annual).

---

## Startup: read these files first

1. **`~/.claude/skills/cashflow-review/history.json`** — every past month's numbers. If missing, treat as empty (`{"version": 1, "months": []}`) — this is the first run.
2. **`~/.claude/skills/cashflow-review/insights.json`** — learned context: confirmed seasonal/recurring expenses and standing notes. If missing, treat as empty (`{"version": 1, "recurring_patterns": [], "standing_notes": []}`).

**history.json shape** (one entry per month, `months` sorted ascending by month):
```json
{
  "version": 1,
  "months": [
    {
      "month": "2026-07",
      "income": { "total": 20787.89, "paychecks": 14092.24, "other": 324.27, "retirement_contributions": 5124.90, "hsa": 657.69, "dividends": 135.22, "interest": 453.57 },
      "expenses": { "total": 17572.83, "by_group": { "Housing": 2462.12, "Food & Dining": 1128.42, "...": 0 }, "by_category": { "Groceries": 898.86, "...": 0 } },
      "savings": 3215.06,
      "savings_rate": 0.1547,
      "spendable_income": 14416.51,
      "spendable_savings_rate": -0.2189,
      "top_merchants": [{ "name": "United Airlines", "amount": 1728.84 }],
      "notes": ["Property tax bill hit this month ($3577.86)"]
    }
  ]
}
```

**insights.json shape:**
```json
{
  "version": 1,
  "recurring_patterns": [
    {
      "category_or_group": "Taxes",
      "typical_months": [1, 7],
      "typical_amount": 3600,
      "note": "Township of Parsippany property tax bill, due ~Jan and ~Jul. Not an anomaly.",
      "confirmed": "2026-08-02"
    }
  ],
  "standing_notes": [
    "Cash & ATM withdrawals are just cash leaving the account, not necessarily spent - don't flag pure ATM swings unless unusually large."
  ],
  "subscriptions": [
    {
      "merchant": "X (Twitter) Premium",
      "category": "Newsletter",
      "cadence": "monthly",
      "typical_amount": 10.00,
      "first_seen": "2026-05-29",
      "last_seen": "2026-07-29",
      "status": "active",
      "note": "Charges vary $5.33-$14.93/mo."
    }
  ]
}
```

`subscriptions` is a merchant-level registry of recurring/subscription-type charges, distinct from
`recurring_patterns` (which is category/group-level and mainly for suppressing seasonal anomaly
flags). It exists so questions like "what am I paying for Newsletter subscriptions" or "what's my
annual GenAI spend" can be answered by reading this file instead of re-fetching and re-deriving
merchant breakdowns from Monarch every time. `status` is one of `active` (still recurring),
`watch` (single charge, no repeat yet — unclear if it'll recur or was one-time/cancelled), or
`lapsed` (used to recur, hasn't shown up in the last full cycle — worth asking the user if it was
cancelled). `cadence` is `monthly` / `quarterly` / `semi-annual` / `annual` / `irregular` / `unknown`.

---

## Step 1 — Determine the target month

Default to the most recently **fully completed** calendar month relative to today (if today is
2026-08-02, the target is 2026-07). If the user names a month explicitly, use that instead. If
`history.json` already has an entry for the target month, ask the user whether to overwrite it
before proceeding (the account may have been re-synced since).

## Step 2 — Fetch the month's data

Two Monarch MCP servers may be connected: **official** (`mcp__monarch__*`) and **community**
(`mcp__monarch-money__*`). Prefer official; fall back to community if the official tools aren't
available or error. Every official call needs `intent: "budgeting"`.

Call, for `start_date`/`end_date` spanning the full target month:

**Official server:**
- `GetCashFlow` with no `base_query` → `total_income`, `total_expense`, `net_savings`, `net_savings_rate`.
- `GetCashFlow` with `base_query: '{"group_by_entity": "category_group"}'` and again with
  `"category"` and `"merchant"`, each with `filters: '{"category_type": "expense"}'`; repeat
  `category` with `"income"` for the income breakdown. Rows are `{entity_name, entity_id, amount}`.
  **Expenses come back negative** — store absolute values in `history.json`.
- `GetBudget` (`include_actuals: true`) — same "skip if every budgeted amount is 0" rule as below.

**Community server:**
- `mcp__monarch-money__get_cashflow_summary` — quick `sumIncome`, `sumExpense`, `savings`, `savingsRate`.
- `mcp__monarch-money__get_cashflow` — `byCategory`, `byCategoryGroup`, `byMerchant`. **This can exceed the tool's output limit** — if so, save to the scratchpad and process with `jq`/`python`, never try to read it raw.
- `mcp__monarch-money__get_budgets` — only useful if `plannedAmount` is nonzero somewhere in `monthlyAmountsByCategoryGroup`/`monthlyAmountsByCategory`. If every planned amount is 0 (no budgets configured in Monarch yet), skip budget comparison for this run — trend-vs-history is the primary signal, not Monarch's budget feature.

**Filtering investment noise:** Investment mechanics (Buy, Sell, Transfer, Credit Card Payment)
are `transfer`-type categories — **exclude these entirely**, don't hand-maintain a category
exclusion list. On the official server the `category_type` filter does this for you. On the
community server, `byCategoryGroup` and `byCategory` each carry a `groupBy...group.type` field of
`income`, `expense`, or `transfer`: use `type: "expense"` groups/categories for the spending
picture and `type: "income"` for the income picture. Note that `income` includes non-spendable amounts (Retirement Contributions,
HSA, Dividends & Capital Gains, Interest) alongside Paychecks/Other Income — report the Paychecks +
Other Income figure separately from the full income total so "savings rate" isn't inflated by money
that was never spendable cash in the first place.

## Step 3 — Compute trailing baselines

From `history.json`, take up to the last 6 months before the target month (need at least 2 prior
months to compute a trend; if fewer, skip trend comparison for this run and say so — you're still
building the baseline). Compute, per expense category group and per top-level expense category:
- 3-month trailing average (or fewer if not enough history)
- 6-month trailing average where available

## Step 4 — Flag real anomalies

For each expense category group/category, flag if:
```
abs(actual - trailing_avg) > max($75, 25% of trailing_avg)
```
Before flagging, check `insights.json` → `recurring_patterns`: if the category/group has a pattern
whose `typical_months` includes the target month's numeric month, don't flag it — just note it as
"expected (seasonal)" in the summary. For everything else that clears the threshold, look at
`byMerchant` to find the single biggest contributor driving the move — the flag should say "Travel
& Lifestyle up $2,900 vs avg, driven by United Airlines ($1,729) + Airbnb ($1,469)", not just
"Travel & Lifestyle is up."

Skip flagging categories under $30 in absolute actual spend — too small to matter.

## Step 5 — Present the retrospective

```
── Cashflow Retro: <Month Year> ───────────────────────

Income (paycheck + other):  $X   (trailing 3-mo avg: $Y)
Total spend:                 $X   (trailing 3-mo avg: $Y)
Savings:                     $X   (rate: X% | trailing 3-mo avg: Y%)

By category group:
| Group | This month | 3-mo avg | Δ | Flag |
|-------|-----------|----------|---|------|
...

Anomalies to look at:
| # | Category | This month | Trailing avg | Driven by | 
|---|----------|-----------|--------------|-----------|
...

Reply with: ok · N=one-off · N=recurring · N=seasonal(month1,month2) · skip N
```

If there's not enough history yet (fewer than 2 prior months), skip the "vs trailing avg" columns
entirely and just present the raw month — say plainly "building baseline, trend comparison starts
next month with 2+ months of history."

## Step 6 — Apply annotations and save

For each anomaly the user annotates:
- `one-off` → no pattern created, just recorded in this month's `notes` in `history.json`.
- `recurring` → the deviation is expected to continue going forward (e.g. a new subscription); no
  `recurring_patterns` entry needed since future months' trailing average will naturally absorb it.
- `seasonal(month1,month2,...)` → add/update a `recurring_patterns` entry in `insights.json` with
  those `typical_months` so it's never flagged again in those months.
- `skip` → leave as flagged, unresolved, don't record anything.

Append the target month's full data to `history.json` (`income`, `expenses.total`, `expenses.by_group`
— **all** expense-type groups, `expenses.by_category` — **all** expense-type categories, not just the
flagged ones, `savings`, `savings_rate`, `spendable_income` = paychecks + other income,
`spendable_savings_rate` = (spendable_income - expenses.total) / spendable_income, top 5-8
`top_merchants` by expense with obvious bank/card-processor names (Chase, Discover, Citi, Wells Fargo,
Bank of America, Capital One, Amex, Robinhood, PayPal, Venmo, Zelle, Synchrony, TJX Rewards,
DirectPay, Google Store — `byMerchant` isn't category-type filtered, so these often sneak in as
disguised Credit Card Payment/Transfer entries, not real spend) filtered out, and `notes` from step 6).
Keep months sorted ascending. Storing full category/group breakdowns (not just anomalies) is what
lets ad-hoc questions later be answered without re-fetching — see "Answering ad-hoc questions" below.

## Step 6.5 — Update the subscriptions registry

Recurring/subscription-type charges are easy to spot in categories like `Newsletter`, `GenAI`,
`Internet & Cable`, `Subscriptions`-group items, and similar — anything billed by the same merchant
on a repeating cadence. Whenever this month's data includes one:

- **New merchant, never seen before** → add an entry to `insights.json` → `subscriptions` with
  `status: "watch"` if this is the only charge so far (cadence unknown until it repeats), or
  `status: "active"` if you can already tell the cadence from context (e.g. explicitly monthly billing
  language in the description).
- **Merchant already in the registry, charged again** → update `last_seen`, refine `cadence` now that
  there's a second data point (e.g. two charges ~6 months apart → `semi-annual`), update
  `typical_amount` if it's drifted, and promote `status` from `watch` to `active` once a pattern is
  clear.
- **Merchant in the registry with `status: "active"` that should have recurred by now but didn't**
  (e.g. a monthly subscription with no charge in over 45 days) → flag it in this month's summary as
  possibly lapsed/cancelled and ask the user; if confirmed cancelled, set `status: "lapsed"`.

Don't try to populate this exhaustively from history you haven't reviewed yet — it grows organically,
one month's categories at a time, same as `recurring_patterns`.

## Step 7 — Final narrative

One short paragraph, not a wall of text: overall trend direction (savings rate up/down vs trailing
average), the single biggest driver of any change, and one thing to watch next month if relevant.
No filler, no restating the whole table.

---

## Answering ad-hoc analytical questions

This skill isn't only for the monthly ritual — invoke it (or just read its files directly) for
questions like "how much have I spent on X this year" or "what subscriptions am I paying for."
Answer in this order, cheapest first:

1. **`insights.json` → `subscriptions`** — merchant-level recurring charges, already broken out by
   cadence/amount. Fastest path for "what am I subscribed to" style questions.
2. **`history.json` → `expenses.by_category` / `by_group` across months** — every reviewed month has
   the *full* category breakdown stored (not just anomalies), so category totals across any range of
   reviewed months are a local sum, no Monarch call needed. This only covers months that have actually
   been through a retro, though — check date coverage first.
3. **Live Monarch query** — only when the question needs merchant-level detail *within* a category
   (history.json doesn't store per-category merchant breakdowns, only top overall merchants per
   month) or covers a month not yet in `history.json`. Use official `GetCashFlow` with
   `group_by_entity: "merchant"` plus an `include_categories` filter, or `GetTransactions` /
   community `get_transactions` with `category_ids`, rather than re-pulling all of `get_cashflow`.

When a live query surfaces something worth remembering (a newly-discovered subscription, a
mischaracterized total), fold it back into `subscriptions` or `recurring_patterns` before finishing
the response — same instinct as Step 6.5, just triggered by a question instead of a monthly run.

## Notes

- This skill is read-only against Monarch except when the user explicitly asks to adjust a budget
  target — even then, only call `mcp__monarch-money__set_budget_amount` after explicit confirmation,
  never automatically. The official server has no budget-write tool; if the community server isn't
  connected, tell the user to change the budget in the Monarch app.
- Run `/review-transactions` before this for any month where you haven't done a categorization pass
  — this skill trusts Monarch's categories as given and doesn't re-verify them.
