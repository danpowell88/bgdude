---
id: decision-6
title: >-
  Concurrent sessions isolate via git worktree + branch; solo work commits
  straight to main
date: '2026-07-08 11:14'
status: accepted
---
## Context

- The project ran with a standing "commit straight to `main`, no feature branches" rule
  (personal single-dev repo; branch-then-merge ceremony was unwanted friction).
- In practice multiple sessions/agents write to the repo at once — an implementer session,
  the hourly review loop, the 3-hourly meta loop — and they shared one working tree. This
  produced repeated `file modified since read` races and forced every commit to be manually
  scoped to avoid staging another session's in-flight files.
- Git constraint: two worktrees cannot check out the same branch, so isolating concurrent
  writers into separate worktrees necessarily means separate branches.

## Decision

- **Solo fast-path:** a single session with no concurrent writer commits **directly to
  `main`** and pushes — unchanged, no branch.
- **Concurrent writers isolate:** when more than one session/agent writes at once, each works
  in its **own git worktree on its own short-lived branch off `main`**
  (`git worktree add ../bgdude-<purpose> -b <purpose>`), commits to the branch, runs the full
  verify pipeline, and integrates into `main` by merge/PR when green — then removes the
  worktree and deletes the branch.
- **File-mutating subagents** use `isolation: "worktree"` on the Agent tool; read-only
  reviewers do not.
- This supersedes the earlier absolute "never branch" rule: branches are now accepted
  **specifically for concurrency isolation**, not as general workflow.

## Consequences

- Eliminates the shared-working-tree race between concurrent sessions; no more manual
  commit-scoping to dodge another session's edits.
- Adds merge/rebase-to-main steps and short-lived branches (accepted trade-off the user opted
  into for the isolation benefit).
- Solo work keeps its low-friction straight-to-main path, so the ceremony only appears when
  concurrency actually warrants it.
- Recorded in CLAUDE.md `## Git` and the `git-workflow` memory; both updated 2026-07-08.
