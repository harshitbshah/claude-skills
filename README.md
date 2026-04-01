# claude-skills

Personal Claude Code skills. Invoke any skill with `/skill-name` in a Claude Code session.

## Skills

### `/review-transactions`
Reviews Monarch Money transactions flagged for review (`needs_review: true`). Uses a local pattern knowledge base to suggest categories instantly — only falls back to fetching transaction history for unknowns. Learns from every confirmed run.

**Flow:** Fetch needs-review → match against saved patterns → fetch history for unknowns → show suggestion table → wait for confirmation → apply + update patterns.

**Files:**
- `review-transactions/SKILL.md` — skill definition
- `review-transactions/monarch-patterns.json` — learned categorization patterns (grows over time)
- `review-transactions/categories-cache.json` — Monarch category list (cached permanently; delete to refresh)

---

### `/compare-portfolio`
Compares US portfolio holdings between the Google Sheet (updated daily by [portfolio-sync](https://github.com/harshitbshah/portfolio-sync)) and SavvyTrader. Flags missing tickers and quantity drift above 0.1 shares.

**Flow:** Read sheet via `gws` + fetch SavvyTrader holdings in parallel → diff tickers and quantities → clean one-liner output when in sync, detailed table when issues found.

**Requirements:** `gws` CLI authenticated with `https://www.googleapis.com/auth/spreadsheets` scope.

---

## Restore on a new machine

```bash
git clone https://github.com/harshitbshah/claude-skills.git ~/.claude/skills
```

## Keeping skills backed up

After updating a skill or after `monarch-patterns.json` has grown meaningfully:

```bash
cd ~/.claude/skills && git add . && git commit -m "update patterns" && git push
```
