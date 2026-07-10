---
id: decision-13
title: Task tracking migrated from Backlog.md to GitHub Issues + Projects
date: '2026-07-11'
status: accepted
---
## Context

- Task state lived in `backlog/` markdown files, so every status transition was a commit
  pushed straight to `main` (decision-8 carve-out). Measured 2026-07-11: **100 of the last
  100 commits on `main` touched `backlog/`**. That churn made feature branches go 10–20
  commits stale within hours; worse, each task's file was edited on BOTH its feature branch
  (comments, AC ticks) and `main` (status flips), so every branch eventually CONFLICTED,
  GitHub marked its PR DIRTY, CI skipped it, and the merge gate could never clear
  (old TASK-310 — ~36 Review branches were jammed).
- The claim protocol also depended on git push races as its mutual-exclusion primitive —
  workable but noisy, and invisible until pushed.

## Decision

- **All task tracking moves to GitHub Issues on `danpowell88/bgdude`** (CLI: `gh`), with the
  **`bgdude` user project board** as the pipeline view (custom `Stage` single-select +
  `Ordinal` number fields).
- **Mapping** (all 315 Backlog items migrated, full content — description, ACs, plan, notes,
  DoD, comment history — preserved in issue bodies; `doc/backlog-migration-map.md` maps
  `TASK-<id>` → `#<n>`):
  - task → issue; status → one `status:*` label per open issue; **Done → the issue is
    closed** (reason `completed`; archived tasks → closed `not planned` + `archived` label).
  - milestones m-0..m-8 → GitHub milestones; priority → `priority:*` labels; topic labels →
    labels as-is; ordinal → body bullet + project `Ordinal` field; dependencies/parent →
    `Depends on:`/`Parent:` body bullets with `#<n>` cross-links.
- **Closing an issue = Done, and only Summer's gate produces it** (decision-12 unchanged):
  agents move issues between `status:*` labels; only the groomer, acting on Summer's
  recorded batch verdict, ever closes a task issue. PR bodies use `Refs #<n>` — closing
  keywords (`Closes/Fixes/Resolves`) are forbidden so merges can't auto-close past the gate.
- **Claims are label flips + signed comments** (atomic API calls), replacing claim commits.
  There are **no backlog bookkeeping commits on `main` anymore** — this directly resolves
  old TASK-310's AC #3 (main churn) and removes the branch-vs-main conflict on task files
  entirely. Straight-to-`main` remains only for `doc/decisions/`, config, and trivial docs.
- **Branches are named `issue-<n>`** going forward. Legacy `task-<id>` branches (13 in
  Needs Review at migration) keep their names; the map + each issue's `Branch:` bullet tie
  them together. The `task-` prefix is retired to avoid number collisions.
- **Decisions and archived docs stay in the repo** (they are low-churn standing references,
  not workflow state): `backlog/decisions/` → `doc/decisions/`, the archived roadmap →
  `doc/roadmap-archived-2026-07-06.md`. New decisions are numbered markdown files added
  directly.
- The `backlog/` tree, the Backlog.md CLI/MCP wiring, and `scripts/watch-backlog.ps1` are
  removed (content fully replicated to issues; git history retains the originals). CI's
  `paths-ignore` for `backlog/**` is dropped. `.github/workflows/project-sync.yml` mirrors
  `status:*` labels to the project board's `Stage` field when a `PROJECT_SYNC_TOKEN` secret
  (fine-grained PAT with Projects read/write) is configured; labels stay canonical either
  way.

## Consequences

- CLAUDE.md, `loops/*.md`, `doc/process.html`, and `scripts/run-agent.ps1` rewritten for
  `gh`-based workflow; `.github/ISSUE_TEMPLATE/task.md` carries the body structure + DoD
  checklist.
- Agents share one GitHub account, so identity lives in comment signatures
  (`<agent-id>: …`) and `implemented-by:`/`reviewed-by:` tags — unchanged in spirit from
  `--comment-author`.
- The ~36 stale legacy branches still need reconciling or re-cutting (old TASK-310 AC #4,
  now issue-tracked); the migration stops NEW branches from rotting but does not repair old
  ones.
- decisions 6/7/8/10/12 remain in force with their git/backlog mechanics reinterpreted per
  this decision (worktrees, reviewer ≠ implementer, PR-only merges, the ten-stage pipeline).
