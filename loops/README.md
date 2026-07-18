# Agent loops (decisions 10 + 12 + 13 + 15)

A tiered agent fleet plus one human gate keeps GitHub Issues moving through
`Idea → Planned → To Do → Doing → Needs Review → Reviewing → Reviewed → Requires Human
Verification → Done`. **The pipeline stage lives in project #2's `Status` column
(decision-15) — board columns are canonical; labels survive only as routing flags**
(`escalate`, `needs-human`, `detail-needed`, `verification-batch`, `priority:*`).
The prompts here are agent-agnostic: any CLI agent that can read `CLAUDE.md` and run
`git`/`gh`/`flutter` can run them — Claude Code, qwen-code, GitHub Copilot CLI. Identity
comes from the agent id it signs with, not the tool.

| Loop | Prompt | Tier / harness | Cadence | Pipeline segment |
|------|--------|----------------|---------|------------------|
| Implementer | `loops/implementer.md` | cheap: qwen-code / copilot-cli / Claude Haiku or Sonnet — several in parallel OK (one qwen per GPU box) | every 30–60 min | `To Do → Doing → Needs Review` (ceiling → `Blocked`+`escalate`) |
| Escalation | `loops/escalation.md` | Claude Sonnet | every 60–90 min | `Blocked`+`escalate` → `Doing` → `Needs Review` (ceiling → `Blocked`+`needs-human`) |
| Reviewer | `loops/reviewer.md` | Claude Opus | hourly | `Needs Review → Reviewing → Reviewed` (fail → `To Do`; K fails → `Blocked`+`escalate`) |
| Groomer | `loops/groomer.md` | Claude Opus | daily | `Idea → Planned → To Do`; `Reviewed → Requires Human Verification`; verdicts `→ Done` |
| Reaper | `loops/reaper.md` | none — pure `gh`/`git` in `run-agent.ps1` | every ~15 min | releases stale `Doing`/`Reviewing` claims |
| Summer (human) | — | — | when a batch appears | `Requires Human Verification → Done` (closes the issues) |

Safe to overlap: every role claims work by moving the board `Status` and posting a
**signed claiming comment BEFORE touching anything**, then re-reads the issue and backs off
if an earlier claim is present. Claims are API calls — instantly visible to every session
and machine, no commits, no push races. If a machine dies mid-claim, the reaper releases
the item after `-StaleMinutes` of server-side silence. All transitions are **idempotent**
(check-then-act), so a crashed half-finished iteration is always resumable.

## Board queue cheat-sheet (all prompts use these)

```bash
# The whole queue in ONE call: item id, issue number, Status column, Ordinal field
gh project item-list 2 --owner danpowell88 --format json --limit 500

# Resolve ids once per run (cache them):
gh project view 2 --owner danpowell88 --format json          # -> .id (project id)
gh project field-list 2 --owner danpowell88 --format json    # -> Status field id + option ids

# Move an item between columns:
gh project item-edit --project-id <project-id> --id <item-id> \
  --field-id <status-field-id> --single-select-option-id <target-option-id>
```

Sort candidates by the board's `Ordinal` number field (fall back to the issue body's
`- **Ordinal:** <n>` bullet when the field is unset). Dependency state is read from the
same `item-list` output: a `Depends on:` issue is satisfied when closed or in `Reviewed`.

**Rate-limit etiquette (every loop):** the fleet shares one GitHub account. If any `gh`
call fails with 403/429, wait for the `Retry-After` value (or 60s) and retry up to 3
times; if it still fails, stop the iteration cleanly — leave state as-is (transitions are
re-entrant) and let the next scheduled run resume. Never tight-loop `gh`; poll PR checks
at 60–90s intervals, not `--watch`.

## Start an agent (script)

`scripts/run-agent.ps1` wraps everything — interactive picker, one iteration, or a
persistent loop (`pwsh` works on Windows, Linux and macOS):

```powershell
pwsh scripts/run-agent.ps1                                   # interactive: role/harness/model
pwsh scripts/run-agent.ps1 -Role implementer -Agent qwen     # local qwen (one per GPU box)
pwsh scripts/run-agent.ps1 -Role implementer -Agent copilot  # Copilot CLI implementer
pwsh scripts/run-agent.ps1 -Role implementer -Model haiku    # cheap Claude implementer
pwsh scripts/run-agent.ps1 -Role escalation                  # sonnet rescue run
pwsh scripts/run-agent.ps1 -Role reviewer                    # one opus review run
pwsh scripts/run-agent.ps1 -Role reaper                      # release stale claims
pwsh scripts/run-agent.ps1 -Role implementer -Loop -IntervalMinutes 45
```

Per-machine setup (once): `gh auth login` then `gh auth refresh -s project` (Projects v2
scope), `claude login` (subscription — reviews burn no API credits), plus `qwen` /
`copilot` CLIs where that harness is used. Knobs: `-MaxTurns`, `-PermissionMode`,
`-RateLimitFloor`, `-StaleMinutes` — see the script header.

## Schedule

Throughput workers run always-on (`-Loop`); the on-demand tiers (reviewer, escalation,
reaper) run as **scheduler-driven stateless ticks** so smart-model quota is only spent
when their queue is non-empty. Windows Task Scheduler:

```powershell
schtasks /Create /TN "bgdude-implementer" /SC HOURLY /TR "pwsh -NoProfile -File C:\path\to\bgdude\scripts\run-agent.ps1 -Role implementer -NonInteractive" /F
schtasks /Create /TN "bgdude-escalation"  /SC HOURLY /ST 00:20 /TR "pwsh -NoProfile -File C:\path\to\bgdude\scripts\run-agent.ps1 -Role escalation -NonInteractive" /F
schtasks /Create /TN "bgdude-reviewer"    /SC HOURLY /ST 00:40 /TR "pwsh -NoProfile -File C:\path\to\bgdude\scripts\run-agent.ps1 -Role reviewer -NonInteractive" /F
schtasks /Create /TN "bgdude-reaper"      /SC MINUTE /MO 15 /TR "pwsh -NoProfile -File C:\path\to\bgdude\scripts\run-agent.ps1 -Role reaper -NonInteractive" /F
schtasks /Create /TN "bgdude-groomer"     /SC DAILY  /ST 07:00 /TR "pwsh -NoProfile -File C:\path\to\bgdude\scripts\run-agent.ps1 -Role groomer -NonInteractive" /F
```

cron equivalents on Linux/macOS use the same commands. (Inside a Claude Code session the
same loops can be driven with `/loop` or cloud Routines — point them at the same prompt
files so there is one source of truth.)

## Invariants (enforced by ruleset + convention)

- `main` only gains task code through a PR with `analyze` (--fatal-infos),
  `coverage-gate`, `apk-build`, `native-tests`, `actionlint`, `android-lint`
  (warningsAsErrors + baseline), `detekt` (Kotlin complexity/idiom, baseline —
  issue #333), and `dependency-review` green, plus CodeQL results
  clean of medium+ security / warning-level alerts introduced by the PR (GitHub ruleset
  "main merge gate: PR + green CI", decisions 10, 11, 14).
- **An item only reaches `Needs Review` with its PR's CI checks green** — the implementer
  drives remote CI green (build-fix ceiling, then escalate), so the reviewer spends Opus
  quota on substance, not mechanical failures.
- `coverage-gate` on a PR enforces the floor AND the no-drop ratchet vs the latest
  successful `main` run: coverage that regresses fails the check — add tests, don't argue.
- `detekt` and `android-lint` both run against a committed baseline, so only NEW
  findings fail. Regenerating a baseline to clear a finding you just introduced defeats
  the gate — fix the finding, or argue it in review, but don't re-baseline it away.
- Implementers never merge; the reviewer never merges its own work; nobody uses
  `gh pr merge --admin`.
- Agents never close a task issue — that is Summer's verdict on a verification batch
  (decision-12). The one exception: the groomer closes issues when acting on her recorded
  verdict. PR bodies say `Refs #<n>`, never `Closes #<n>`, so merges can't auto-close past
  her gate.
- Status moves happen via the board (`gh project item-edit`) + a signed comment,
  immediately at every transition — never batched, never left stale. `Doing`/`Reviewing`
  mean *actively being worked right now*; the reaper enforces it.
