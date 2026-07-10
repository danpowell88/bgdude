---
id: decision-10
title: >-
  Tiered agents with a PR merge gate: cheap models implement, expensive models
  review; GitHub ruleset blocks non-PR / red-CI merges to main
date: '2026-07-10 13:20'
status: accepted
---
## Context

- decision-8 put task work on `task-<id>` branches with the review loop as the only merger, but
  the merge was a *local* `git merge --no-ff` + push — nothing machine-enforced stopped a bad
  merge, and CI-on-the-branch needed a fragile `task-**` push trigger (TASK-309/TASK-310 were
  both symptoms of that gap).
- decision-8 explicitly anticipated: "if PR-based merge is wanted later … switch the loop to
  open/merge PRs". We now want that, plus **model tiering**: implementation is high-volume,
  mostly mechanical work that cheaper models (Claude Sonnet/Haiku, or external CLI agents such
  as qwen code) can do; review/merge is the quality gate and stays on an expensive model.

## Decision

- **Roles by model tier.** Implementer agents run on cheap models (or are external agents like
  qwen code that still follow this repo's CLAUDE.md conventions). Reviewer agents run on an
  expensive model, on a schedule, and are the only mergers. Reviewer ≠ implementer (decision-7)
  still holds — the tiers make it structural.
- **Every task ships as a GitHub PR.** The implementer claims a task (`In Progress` + assignee +
  `branch:` comment, committed straight to `main` and pushed IMMEDIATELY, before any code), works
  in its own worktree on `task-<id>`, runs the full verify pipeline locally, pushes the branch,
  opens a PR titled `TASK-<id>: <title>` (body: task link + `implemented-by:`), records
  `PR: #<n>` on the task, and moves it to `Review`.
- **A GitHub ruleset enforces the merge gate** (ruleset "main merge gate: PR + green CI",
  id 18774666): merging to `main` requires a PR, merge-commit method only, and green required
  checks `analyze`, `coverage-gate`, `apk-build`, `native-tests`. Force-push and branch deletion
  on `main` are blocked. Repository admins have an `always` bypass **solely** so the backlog
  claim/status/bookkeeping commits can keep going straight to `main`; using the bypass to merge a
  PR (`gh pr merge --admin`, merging red CI) is forbidden by convention.
- **The reviewer loop drains `Review`:** for each task it finds the PR, merges `origin/main`
  into the branch when it is stale/conflicting (then lets CI re-run), reviews the diff against
  ACs/DoD with the sweep-the-whole-surface checklist, and leaves notes on both the PR and the
  task. Pass → `reviewed-by:` comment, DoD checked, `gh pr merge --merge` (never `--admin`),
  task `Done`, branch/worktree deleted. Fail → `reviewed-by:` comment with concrete follow-ups,
  PR stays open, task goes back to **`To Do`** so any implementer can pick it up and resume on
  the same branch/PR.
- CI's `task-**` push trigger is removed: branches build via their PR (`pull_request`), so each
  push builds once, not twice. `push: main` remains as post-merge verification.

## Consequences

- The merge gate is machine-enforced (ruleset + required checks), not convention-only: a red or
  unreviewed branch physically cannot merge through the normal path.
- Implementation cost drops (cheap models / external agents do the volume work); the expensive
  model's budget concentrates on review, where the incomplete-fix class is caught.
- Failed reviews land back in `To Do` (not `In Progress`), so the implementer pool — not one
  specific agent — picks up rework; the branch + PR carry the context forward.
- The admin bypass means the gate is convention-backed for the shared owner account's *direct
  pushes*; the greppable `implemented-by:`/`reviewed-by:`/`Co-Authored-By` trail remains the
  identity record since all agents share one GitHub account.
- Loop prompts live in `loops/` (implementer.md, reviewer.md) so external agents can run the
  same procedure. Refines decision-8 (merge mechanics → PRs) and decision-6; builds on
  decision-7. Recorded in CLAUDE.md `## Git` + `### Comment as you work` (2026-07-10).
