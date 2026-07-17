# Reaper (no LLM — pure `gh`/`git`, implemented in `scripts/run-agent.ps1`)

The reaper is the fleet's crashed-claim recovery: with agents running on several machines,
a box can die (or a process get killed) after claiming an item, leaving it stuck in
`Doing`/`Reviewing` forever. The reaper releases such claims so the queue never leaks work.
It is not a prompt — `pwsh scripts/run-agent.ps1 -Role reaper` runs the logic directly
(function `Invoke-Reaper`); this file documents the contract.

## What it does

Each tick (schedule every ~15 minutes):

1. One `gh project item-list` call → all items in `Doing` or `Reviewing`.
2. For each, compute **last activity** from **GitHub server timestamps only** (authoritative
   across machines with skewed clocks): the latest of
   - the newest issue comment (`created_at`) — claims and `progress:` heartbeats count, and
   - the newest commit on the `issue-<n>` branch (falling back to the issue's own
     `updated_at` when neither exists).
3. If the item has been quiet longer than `-StaleMinutes` (default 45):
   - `Doing` → back to `To Do`
   - `Reviewing` → back to `Needs Review`
   with a signed comment: `reaper: released #<n> — no activity since <ts> — returning to
   <column>. The claim went silent…`. The **branch and PR are never touched** — the next
   agent to pick the item up resumes them (the implementer/escalation prompts handle an
   existing branch explicitly).

## Safety properties

- **Idempotent:** a released item is no longer in `Doing`/`Reviewing`, so re-running the
  reaper is a no-op. A crash between the column move and the comment just loses the comment.
- **Never reaps live work:** any comment or commit inside the window counts as activity —
  which is why the worker prompts require `progress:` heartbeats on long-running issues.
  Size `-StaleMinutes` above your slowest expected quiet stretch (a long APK build is ~10
  minutes; 45 is conservative).
- **Rate-limit aware:** runs behind the same `Invoke-Gh` backoff + `rate_limit` pre-flight
  as everything else; a tick that can't get quota skips cleanly.
