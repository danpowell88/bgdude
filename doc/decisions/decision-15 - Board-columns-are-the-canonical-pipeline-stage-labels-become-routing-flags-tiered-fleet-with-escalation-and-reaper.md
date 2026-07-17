# Decision 15 — Board columns are the canonical pipeline stage; labels become routing flags; tiered fleet gains an escalation lane and a reaper

- **Date:** 2026-07-12
- **Status:** accepted
- **Supersedes:** the labels-are-canonical part of decisions 12 and 13 (the ten-stage
  pipeline itself, the human verification gate, and GitHub-Issues-as-planning-source all
  stand unchanged).

## Decision

1. **The pipeline stage of every issue lives in the `Status` single-select field on user
   project #2 (`bgdude`)** — Idea, Planned, To Do, Doing, Blocked, Needs Review, Reviewing,
   Reviewed, Requires Human Verification, Done (closed). The `status:*` labels are retired.
   The per-milestone phase boards (#12–#20) are mirrors, reconciled hourly by
   `.github/workflows/project-sync.yml` (Projects v2 field edits fire no repo workflow
   events, so the mirror is scheduled, not event-driven; issue open/close membership and
   the closed→Done stamp remain event-driven).
2. **Labels survive only as cross-cutting routing flags** that annotate a stage rather than
   being one: `escalate` (a Blocked item waiting for the stronger escalation agent),
   `needs-human` (a Blocked item every automated tier failed on), `detail-needed`,
   `verification-batch`, `priority:*`.
3. **The agent fleet is tiered by model cost** (extends decision-10), driven by
   `scripts/run-agent.ps1` + `loops/*.md`:
   - *Implementers* (cheap: qwen-code / GitHub Copilot CLI / Claude Haiku or Sonnet) drain
     `To Do`. They must drive the PR's **remote CI checks green before handing off** to
     `Needs Review` (build-fix ceiling: 3 attempts), so review quota is spent on substance.
   - *Escalation* (Claude Sonnet) drains `Blocked`+`escalate` — work the cheap tier
     couldn't finish or the reviewer bounced ≥3 times — resuming the existing branch.
     Its own ceiling → `Blocked`+`needs-human`.
   - *Reviewer* (Claude Opus) drains `Needs Review`, merges on pass (decision-10
     unchanged: reviewer is the only merger, never `--admin`), fails back to `To Do`,
     and escalates instead of bouncing on the third failed cycle. Its verdicts are also
     emitted as structured output (`PASS|FAIL|ESCALATE`), fail-closed.
   - *Reaper* (no model) releases `Doing`/`Reviewing` claims silent for 45+ minutes,
     judged by GitHub server timestamps only. Workers post `progress:` comments as
     liveness heartbeats.
4. **Multi-machine coordination happens exclusively through GitHub** (board moves + signed
   claiming comments, earliest claim wins) — no shared filesystem; any number of machines
   can run loops concurrently. All loops share one account, so every `gh` consumer backs
   off on 403/429 (honoring `Retry-After`), pre-flights `gh api rate_limit`, jitters its
   cadence, and never hot-polls (`gh pr checks` at 60–90s, no `--watch`).

## Why

- Summer directed the queue to live on the board ("use board columns instead of labels in
  most cases unless it makes sense") — the board is the thing actually looked at, and the
  label↔board mirror was a second copy of the truth that could drift.
- One `gh project item-list` call now returns the whole queue with Status AND the Ordinal
  sort key — cheaper on the shared account's rate limits than per-label issue queries plus
  body-regex ordinal parsing.
- Routing flags stay labels deliberately: they annotate a stage (`Blocked` + *why*), fire
  issue events, and match the existing `detail-needed`/`verification-batch` pattern —
  turning them into columns would fork the pipeline into parallel stage sets.
- The escalation lane + rework ceiling bound the two failure loops (worker grinding on a
  build it can't fix; reviewer↔implementer ping-pong) that otherwise burn quota without
  converging; the reaper bounds the third (a dead machine holding a claim forever).

## Consequences

- New issues get no status label; the sync workflow stamps them `Idea` on the board.
  `gh` on every fleet machine needs the Projects scope (`gh auth refresh -s project`).
- One-time migration: existing open issues' `status:*` labels are swept onto the board
  Status (manual or scripted), then the labels are deleted from the repo.
- `.github/ISSUE_TEMPLATE/task.md` no longer seeds `status:idea`; CLAUDE.md's cheat-sheet
  is board-based; `loops/README.md` carries the board command cheat-sheet.
- The `implemented-by:` / `reviewed-by:` / `friction:` comment conventions (decisions 7,
  12) are unchanged — comments remain the greppable audit trail, and now also serve as the
  reaper's liveness signal.
