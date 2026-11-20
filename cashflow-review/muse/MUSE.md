# Monthly cashflow review (instructions for Meta Muse)

Once a month you'll run Harshit's cashflow review: a short summary of last month's income and
spending, compared with his own previous months. It flags anything unusual and learns from his
answers. It runs on his OCI VM. You don't analyze anything yourself: you start it, show him what
it prints, and pass his answers back word for word.

## Schedule
On the 5th of every month at 7:00 PM US Eastern. The wait gives Monarch time to post the last days of
the month. He can also ask at any time ("cashflow review", "monthly review", "how did last month go").

## How to run it
Connect over SSH to the host `oci-vm` (on his Tailscale network) as user `ubuntu`.

### Step A: categorize the month first
The summary is only as good as the categories, so first do a transaction review exactly as described
in `~/.claude/skills/review-transactions/muse/MUSE.md` ("How to run it", steps 1–5): run
`~/bin/review-txn start` and finish it with him. A run with nothing to fix
("✓ No transactions need review") takes seconds; just mention it and move on.

### Step B: the cashflow summary
1. Run: `~/bin/cashflow-rev status`. If something is in progress from earlier, mention it; starting
   again is safe.
2. Run: `~/bin/cashflow-rev start`. This reviews the last full month. It can take 1–5 minutes; wait.
   To review a specific month he names, run e.g. `~/bin/cashflow-rev start 2026-10`.
3. Send him the output exactly as printed: tables, numbers, flags. Don't summarize, reword or drop
   rows. If it's long, split it across messages but keep everything.
   - If it ends with a "Reply with:" line, it's waiting for him: go to step 4.
   - If there's no "Reply with:" line, the review is done. Send the final summary.
4. Wait for his answer, then run `~/bin/cashflow-rev reply "<his answer, exactly as he wrote it>"`.
   Typical answers: `ok`, `2=one-off`, `3=recurring`, `1=seasonal(1,7)`, `skip 4`, `yes`, `no`.
   Pass everything through unchanged (keep the double quotes; replace any double quote inside his
   answer with a single quote).
5. Repeat steps 3–4 until there's no "Reply with:" line.

## Rules (important)
- Never answer a question yourself, and never treat silence as "ok". Every reply must be his own words.
- If he doesn't answer, leave it open. Remind him once the next day, then stop.
- This review never changes anything in Monarch. Don't edit files on the VM, don't run other
  commands, and don't change the setup. Only use `review-txn` and `cashflow-rev` with start, reply
  and status.

## When something goes wrong
Same as the weekly review (see the "When something goes wrong" section of
`~/.claude/skills/review-transactions/muse/MUSE.md`): an expired Monarch cookie, an expired Claude
token, SSH/Tailscale approval, or anything that fails twice. Tell him and stop; don't keep retrying.

## Background (so you can answer his questions)
- Each run adds the month to a history kept on the VM (January 2026 onwards), so comparisons get
  sharper over time. His answers ("one-off", "seasonal") teach it what not to flag again, e.g. the
  property tax bill in January and July.
- "Spendable" income means paychecks plus other income. Retirement contributions, HSA, dividends and
  interest count as income but aren't cash he can spend, so they're reported separately.
