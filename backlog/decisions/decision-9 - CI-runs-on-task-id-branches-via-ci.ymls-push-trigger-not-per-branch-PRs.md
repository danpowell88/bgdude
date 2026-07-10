---
id: decision-9
title: 'CI runs on task-<id> branches via ci.yml''s push trigger, not per-branch PRs'
date: '2026-07-10 12:52'
status: accepted
---
## Context

- decision-8 requires the review loop to confirm CI is green on a task's branch before
  merging it to `main`. But `ci.yml`'s `push` trigger only covered `branches: [main]` — a
  `task-<id>` branch pushed on its own (the normal decision-8 flow: push branch, move the
  task to `Review`, the loop merges) got zero CI runs.
- Filed as TASK-309 (2026-07-10) after the review-and-merge loop found 11 tasks queued in
  `Review` with no merges possible: the "CI green on the branch" gate condition could never
  be satisfied for the standard flow. Only TASK-141, which happened to have a GitHub PR
  open, had any CI signal at all (via the existing `pull_request` trigger).
- Two options existed: (a) add `task-**` to `ci.yml`'s `push.branches`, so every task branch
  gets a run on the same hosted runners `main` uses; or (b) require a GitHub PR per task
  branch, relying on the existing `pull_request` trigger.

## Decision

- **`ci.yml`'s `push` trigger now covers `branches: [main, 'task-**']`.** Pushing a
  `task-<id>` branch runs the full pipeline (analyze / sharded tests + coverage gate / APK
  build / native tests) on GitHub-hosted runners automatically — no PR required. The
  existing `paths-ignore` (backlog/doc/md) still applies to these pushes (it is one shared
  push trigger), so a branch that only touched bookkeeping still doesn't burn CI.
- Opening a PR against `main` remains optional (useful for a review-UI diff/comment thread)
  and still works via the existing `pull_request` trigger — this decision does not remove
  that path, it just stops requiring it for CI to run at all.
- The review loop checks CI with `gh run list --branch task-<id> --limit 1` (or the PR
  checks, if one was opened) and looks for the latest commit's run as
  `completed`/`success` before merging.
- A separate, larger effort (self-hosted Unraid runner, `ci/self-hosted-runner/`, started
  2026-07-10 in parallel with this decision) additionally targets running the
  `integration_test/` emulator suite in CI via `/dev/kvm` — that is a phase-2 capability
  addition, not a substitute for this fix; this decision's hosted-runner branch trigger is
  what unblocks the decision-8 merge gate *today*, independent of whether/when the
  self-hosted runner is deployed.

## Consequences

- Every `Review`-stage task branch gets a real, checkable CI run the moment it's pushed —
  the decision-8 merge gate ("confirms CI is green ... on the branch") is now actually
  satisfiable, unblocking the backlog of tasks stuck in `Review` since branch-per-task
  started.
- CI minutes usage roughly doubles in the worst case (a branch's push run, then its
  eventual `--no-ff` merge-to-main run) — accepted; correctness of the merge gate matters
  more than the extra hosted-runner minutes for a personal project.
- If a task branch is later force-pushed/rebased, its previous CI run becomes stale for the
  new tip commit — the reviewer's `gh run list` check must be against the CURRENT branch
  HEAD's SHA, not just "a green run exists somewhere in the branch's history."
- Recorded in CLAUDE.md's `## Git` section (the "Task work goes on a feature branch..."
  bullet list) and the `### Comment as you work` reviewer-stage paragraph; refines
  decision-8 (2026-07-10).
