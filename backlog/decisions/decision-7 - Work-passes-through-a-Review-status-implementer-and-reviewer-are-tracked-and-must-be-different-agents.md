---
id: decision-7
title: >-
  Work passes through a Review status; implementer and reviewer are tracked and
  must be different agents
date: '2026-07-10 09:11'
status: accepted
---
## Context

- Multiple agents/sessions work this repo (an implementer session plus the hourly review loop
  and the 3-hourly meta loop). Tasks were going straight from `In Progress` to `Done` by the
  implementing agent, with no independent check recorded and no durable record of who did the
  work vs who checked it.
- The review loop has repeatedly caught fixes that were marked done but were incomplete (a fix
  nails its literal scope but misses the semantic sibling half — see the "sweep the whole
  surface" checklist), which is exactly what an independent Review gate exists to catch before
  Done rather than after.

## Decision

- **New workflow status `Review`** between `In Progress` and `Done`
  (`To Do → In Progress → [Blocked] → Review → Done`).
- When an implementer finishes (code + tests + verify pipeline green), they check the ACs, move
  the task to **`Review`** (never straight to `Done`), and leave a comment tagged
  `implemented-by: <agent-id> — <files/tests/commit>` (assignee = implementer).
- A **different agent** picks the task up from `Review` — a task must never be reviewed by its
  own implementer. On pass: `reviewed-by: <agent-id> — <verdict>` comment, check the DoD, set
  `Done`. On fail: `reviewed-by:` comment with the problem, send back to `In Progress`/`Blocked`
  or file a follow-up.
- **Done gate (DoD item):** a task reaches `Done` only with a `reviewed-by` comment from a
  second agent, having passed through `Review`.
- Agent identity for both tags = the identity used to sign commits (the `Co-Authored-By`
  model/session name), so the backlog trail lines up with git authorship.

## Consequences

- Every Done task carries a greppable record of **who implemented and who reviewed** it
  (`implemented-by:` / `reviewed-by:` comments + `--comment-author`), which the meta loop can
  mine.
- Independent review is enforced by convention (reviewer ≠ implementer), catching the
  incomplete-fix class before Done instead of in a later review pass.
- Slightly more ceremony per task (an extra status hop + a second agent), accepted for the
  quality/traceability gain. Solo throwaway/doc commits that aren't backlog tasks are
  unaffected.
- Recorded in `config.yml` (statuses + DoD) and CLAUDE.md `### Comment as you work`
  (2026-07-10).
