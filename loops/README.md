# Agent loops (decisions 10 + 12)

Three scheduled agent roles plus one human gate keep the backlog moving through
`Idea → Planned → To Do → Doing → Needs Review → Reviewing → Reviewed → Requires Human
Verification → Done`. The prompts here are agent-agnostic: any CLI agent that can read
`CLAUDE.md` and run `git`/`gh`/`backlog`/`flutter` can run them — Claude Code on a cheap
model, qwen code, etc. Identity comes from the agent id it signs with, not the tool.

| Loop | Prompt | Model tier | Cadence | Pipeline segment |
|------|--------|-----------|---------|------------------|
| Implementer | `loops/implementer.md` | cheap (Sonnet / Haiku / qwen) | every 30–60 min, several in parallel OK | `To Do → Doing → Needs Review` |
| Reviewer | `loops/reviewer.md` | expensive (Opus / Fable) | hourly | `Needs Review → Reviewing → Reviewed` (or `→ To Do`) |
| Groomer | `loops/groomer.md` | expensive (Opus / Fable) | daily | `Idea → Planned → To Do`; `Reviewed → Requires Human Verification`; verdicts `→ Done` |
| Summer (human) | — | — | when a batch appears | `Requires Human Verification → Done` |

Safe to overlap: every role claims work with an immediate status commit pushed to `main`
(`Doing` / `Reviewing`) before touching anything, and the groomer is idempotent.

## Start an agent (script)

`scripts/run-agent.ps1` wraps everything — one iteration or a persistent loop:

```powershell
pwsh scripts/run-agent.ps1                                  # one implementer run, claude sonnet
pwsh scripts/run-agent.ps1 -Role reviewer                   # one reviewer run, claude opus
pwsh scripts/run-agent.ps1 -Role groomer                    # one groomer run, claude opus
pwsh scripts/run-agent.ps1 -Agent qwen                      # implementer via qwen code
pwsh scripts/run-agent.ps1 -Loop -IntervalMinutes 45        # keep implementing forever
pwsh scripts/run-agent.ps1 -Role reviewer -Loop -IntervalMinutes 60
```

## Schedule (Windows Task Scheduler)

```powershell
schtasks /Create /TN "bgdude-implementer" /SC HOURLY /TR "pwsh -NoProfile -File C:\Users\danpo\Desktop\bgdude\scripts\run-agent.ps1 -Role implementer" /F
schtasks /Create /TN "bgdude-reviewer"    /SC HOURLY /ST 00:30 /TR "pwsh -NoProfile -File C:\Users\danpo\Desktop\bgdude\scripts\run-agent.ps1 -Role reviewer" /F
schtasks /Create /TN "bgdude-groomer"     /SC DAILY  /ST 07:00 /TR "pwsh -NoProfile -File C:\Users\danpo\Desktop\bgdude\scripts\run-agent.ps1 -Role groomer" /F
```

(Inside a Claude Code session the same loops can be scheduled with `/schedule` / cron tools
instead — point them at the same prompt files so there is one source of truth.)

Full process documentation (pipeline, gates, roles, human verification): `doc/process.html`.

## Invariants (enforced by ruleset + convention)

- `main` only gains task code through a PR with `analyze`, `coverage-gate`, `apk-build`,
  `native-tests` green plus CodeQL code-scanning results clean of high+ security /
  error-level alerts — including error-level *quality* findings (security-and-quality
  suite) — (GitHub ruleset "main merge gate: PR + green CI", decisions 10 + 11).
- `coverage-gate` on a PR enforces the floor AND the no-drop ratchet vs the latest
  successful `main` run: coverage that regresses fails the check — add tests, don't argue.
- Implementers never merge; the reviewer never merges its own work; nobody uses
  `gh pr merge --admin`.
- Agents never set `Done` — that is Summer's verdict on a verification batch (decision-12).
  The one exception: the groomer flips tasks to `Done` when acting on her recorded verdict.
- Claim/status backlog commits go straight to `main`, immediately, at every transition.
