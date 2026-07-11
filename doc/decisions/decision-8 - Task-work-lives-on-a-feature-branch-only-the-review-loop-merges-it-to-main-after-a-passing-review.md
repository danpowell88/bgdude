---
id: decision-8
title: >-
  Task work lives on a feature branch; only the review loop merges it to main
  after a passing review
date: '2026-07-10 09:31'
status: accepted
---
## Context

- decision-6 put concurrent writers in their own worktree + branch and kept a "solo work
  commits straight to main" fast-path. decision-7 added a `Review` status + implementer/reviewer
  tracking. But task code still landed on `main` before any independent review, and the review
  loop only reviewed *after* the fact and filed follow-up tickets.
- We want `main` to only ever contain reviewed work, and the review loop to be the gate that
  merges — not just an after-the-fact commenter.

## Decision

- **Task work is developed on a feature branch `task-<id>` (optionally `task-<id>-<slug>`)**, in
  its own worktree off the latest `main`, through `In Progress` and `Review`. It is **never
  pushed straight to `main`** by the implementer. The branch is recorded on the task
  (`branch: task-<id>` comment).
- When the implementer finishes (code + tests + verify pipeline green on the branch), they push
  the branch and move the task to `Review`.
- **The review loop is the only merger.** For each `Review` task it fetches the branch, reviews
  the diff (adversarially, applying the "sweep the whole surface" checklist), confirms CI/verify
  is green, and:
  - Pass → `reviewed-by:` comment, check DoD, **merge `--no-ff` to `main` + push**, set `Done`,
    delete the branch + worktree.
  - Fail → `reviewed-by:` comment with the problems, **no merge**, bounce to `In Progress`/
    `Blocked` or file a follow-up.
- Reviewer ≠ implementer (decision-7): the loop never merges a branch it implemented.
- **Straight-to-main survives only for non-task bookkeeping** — the loops' own follow-up
  tickets and quality-check markers, backlog/decision/config edits, trivial docs. This narrows
  decision-6's solo fast-path to non-feature work.

## Consequences

- `main` only ever gains task code through a reviewed merge — the incomplete-fix class is caught
  before it lands, not after.
- The review loop's job shifts from "review main commits + file tickets" to "drain the `Review`
  queue: review each branch, merge passing ones, bounce failing ones" (its cron prompt updated
  to match).
- Merge is a local `git merge --no-ff` + push (no GitHub PR — the GitHub App isn't connected);
  if PR-based merge is wanted later, connect the app and switch the loop to open/merge PRs.
- More branch/worktree lifecycle to manage, accepted for the "main is always reviewed" guarantee.
- Recorded in CLAUDE.md `## Git` + `### Comment as you work`; refines decision-6, builds on
  decision-7 (2026-07-10).
