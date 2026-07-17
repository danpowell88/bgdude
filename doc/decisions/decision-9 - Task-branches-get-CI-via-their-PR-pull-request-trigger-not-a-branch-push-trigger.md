---
id: decision-9
title: Task branches get CI via their PR (pull_request trigger), not a branch-push trigger
date: '2026-07-17 20:30'
status: accepted
---
## Context

Old TASK-309 / issue #324: the decision-8 review-and-merge workflow requires green CI on a
task branch before it merges to main, but `ci.yml` only triggered on `push` to main and
`pull_request` against main — a task branch pushed on its own got **no CI run**, so the
merge gate could never be satisfied and the Review queue backed up indefinitely.

Two mechanisms were considered, and both were actually built at different points:

1. **Branch-push CI** — add `task-**` to the `push` trigger (implemented on the old
   `task-309` branch, PR #8).
2. **PR-per-branch CI** — every task branch gets a PR; the existing `pull_request`
   trigger runs the full pipeline on the merge ref, and a ruleset gates the merge.

## Decision

**PR-per-branch is the mechanism.** Every task branch gets a PR (decision-10); the
`pull_request` trigger runs the full pipeline; the "main merge gate: PR + green CI"
ruleset requires the checks (`analyze`, `coverage-gate`, `apk-build`, `native-tests`,
`actionlint`, `android-lint`, `dependency-review`, `native-lib-alignment`, CodeQL) green
before anything reaches main. The `push` trigger stays **main-only** (post-merge
verification).

The `task-**` push trigger was deliberately reverted: with PRs mandatory, it would build
every branch push **twice** (once for the push, once for the PR merge ref) for no extra
signal. PR #8, which implemented that rejected approach, was closed unmerged.

## Consequences

- A task branch without a PR gets zero CI — open the PR early; it is what makes the
  branch's state observable to the review loop (`gh pr checks <n>`).
- The `pull_request` run builds the **merge ref** (main + branch), so a PR automatically
  picks up main-side workflow fixes without the branch merging main — but a branch that
  conflicts with main gets no merge ref and therefore **no CI at all**; keeping branches
  mergeable is a prerequisite for having CI signal (issue #325).
- `ci.yml`'s push-trigger comment references this decision; this file resolves what was
  previously a dangling reference (the only decision-9 text existed on the closed
  `task-309` branch and described the rejected alternative).
