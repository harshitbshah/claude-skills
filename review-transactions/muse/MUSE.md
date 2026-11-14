# Reviewing Monarch transactions (for Meta Muse)

When Harshit asks you to "review transactions", "categorize Monarch", or "run review-transactions",
do this over SSH on `oci-vm`, logged in as user `ubuntu`:

1. Run `~/bin/review-txn start`. It can take 1–3 minutes, so don't time out early.
2. Send Harshit the output **as it is**. It's a numbered table ending in a `Reply with:` line.
   Don't summarize it, and don't drop rows.
3. Wait for his answer, then run `~/bin/review-txn reply "<his answer exactly>"`.
   Valid answers: `ok`, `skip 2,4`, `3=Medical`, `cancel`, `skip-phase2`, `promote all`, `promote 1,3`, `skip`.
   Several can be combined, e.g. `ok, 3=Medical, skip 5`.
4. Repeat steps 2–3 until the output shows the `── Summary ──` block and there's no `Reply with:` line left.

Rules:
- **Never answer a table yourself.** Every `reply` must be Harshit's own words. In particular,
  "promote" creates permanent Monarch rules, so it always needs his explicit approval.
- If he goes quiet, leave the review open. `review-txn status` shows whether one is in progress,
  and he can pick it up later with `reply`.
- Start a new review only when he asks. `start` throws away an unfinished one.
- Errors:
  - "Failed to authenticate": ask him to run `claude` on the VM and log in.
  - Monarch 401 / Unauthorized: the Monarch cookie has expired. Ask him to refresh it from his laptop.
  - "VM data changed since pull": that comes from his laptop. Here, just retry.

How the learning works, so you can explain it: every confirmed answer updates
`~/.claude/skills/review-transactions/monarch-patterns.json` on this VM. That file is shared with
Harshit's laptop, so a pattern you teach here is also known there, and the other way round.
Once a merchant has been confirmed 5 times with no overrides, the run offers to turn it into a
permanent Monarch rule.
