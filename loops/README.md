# Agent loops (decision-10)

Two scheduled roles keep the backlog moving. The prompts here are agent-agnostic: any CLI
agent that can read `CLAUDE.md` and run `git`/`gh`/`backlog`/`flutter` can run them — Claude
Code on a cheap model, qwen code, etc. Identity comes from the agent id it signs with, not
the tool.

| Loop | Prompt | Model tier | Cadence |
|------|--------|-----------|---------|
| Implementer | `loops/implementer.md` | cheap (Sonnet / Haiku / qwen) | every 30–60 min, or several in parallel |
| Reviewer | `loops/reviewer.md` | expensive (Opus / Fable) | hourly |

Safe to overlap: implementers coordinate through the claim protocol (In Progress commit pushed
to `main` before any code), and the reviewer is idempotent over the `Review` queue.

## Run one iteration by hand

```powershell
# Claude Code, cheap model
claude -p "Follow the instructions in loops/implementer.md for one full iteration." --model sonnet --permission-mode acceptEdits

# Claude Code, expensive model
claude -p "Follow the instructions in loops/reviewer.md for one full iteration." --model opus --permission-mode acceptEdits

# qwen code (external implementer — same conventions, signs as qwen-code)
qwen --yolo -p "Read CLAUDE.md, then follow the instructions in loops/implementer.md for one full iteration. Sign all backlog comments and commits as qwen-code."
```

## Schedule (Windows Task Scheduler)

```powershell
schtasks /Create /TN "bgdude-implementer" /SC HOURLY /TR "cmd /c cd /d C:\Users\danpo\Desktop\bgdude && claude -p \"Follow the instructions in loops/implementer.md for one full iteration.\" --model sonnet --permission-mode acceptEdits" /F
schtasks /Create /TN "bgdude-reviewer"    /SC HOURLY /ST 00:30 /TR "cmd /c cd /d C:\Users\danpo\Desktop\bgdude && claude -p \"Follow the instructions in loops/reviewer.md for one full iteration.\" --model opus --permission-mode acceptEdits" /F
```

(Inside a Claude Code session the same loops can be scheduled with `/schedule` / cron tools
instead — point them at the same prompt files so there is one source of truth.)

## Invariants (enforced by ruleset + convention)

- `main` only gains task code through a PR with `analyze`, `coverage-gate`, `apk-build`,
  `native-tests` green plus CodeQL code-scanning results clean of high+ security /
  error-level alerts — including error-level *quality* findings (security-and-quality
  suite) — (GitHub ruleset "main merge gate: PR + green CI", decisions 10 + 11).
- `coverage-gate` on a PR enforces the floor AND the no-drop ratchet vs the latest
  successful `main` run: coverage that regresses fails the check — add tests, don't argue.
- Implementers never merge; the reviewer never merges its own work; nobody uses
  `gh pr merge --admin`.
- Claim/status backlog commits go straight to `main`, immediately, at every transition.
