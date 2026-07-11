---
id: decision-12
title: Ten-stage status pipeline with a human batch-verification gate before Done
date: '2026-07-10 14:03'
status: accepted
---
## Context

- The five-status pipeline (`To Do → In Progress → Review → Done`, plus `Blocked`) had three
  gaps: no home for raw ideas vs vetted-but-not-ready work, no way for two reviewer agents to
  see each other mid-review (the `Reviewing` claim), and — most importantly — **`Done` was set
  by an agent**, so nothing confirmed that a merged, agent-reviewed change actually works as
  intended on the real app.
- Summer wants a final human gate over **batches** of related tickets, not per-ticket
  micro-checks: agents do the volume, a human confirms whole pieces of work are truly complete.

## Decision

- **Statuses (config.yml):** `Idea → Planned → To Do → Doing → Needs Review → Reviewing →
  Reviewed → Requires Human Verification → Done`, plus `Blocked` (orthogonal parked state,
  usable from any active stage). Meanings:
  - **Idea** — raw thought, not yet committed work; anyone can file one, no ACs required.
  - **Planned** — groomed: description, ACs, plan, milestone, ordinal, deps filled in
    (groomer loop / expensive model). `detail-needed` tasks live here until answered.
  - **To Do** — ready to pick: deps met, spec sufficient. The ONLY status implementers pick from.
  - **Doing** — claimed by an implementer (replaces `In Progress`; same instant claim-commit
    protocol). Must mean actively worked right now.
  - **Needs Review** — implementation finished: verify pipeline green, branch pushed, PR open.
  - **Reviewing** — claimed by a reviewer (same claim-commit protocol; prevents two reviewers
    racing one task).
  - **Reviewed** — review passed and **the PR is merged**. Agent pipeline complete; awaiting
    batch verification. Review fails go back to `To Do` (branch/PR stay open).
  - **Requires Human Verification** — grouped into a verification batch awaiting Summer.
  - **Done** — Summer verified the batch. **Agents never set Done** (DoD item).
- **Human verification is batch-level.** The groomer loop groups `Reviewed` tasks (≥5, or any
  sitting a week, or a milestone completing) into a **batch task** labelled
  `verification-batch`, assigned to Summer, whose ACs are a per-member checklist of what to
  verify on the real app (from each member's user-visible ACs); members move to
  `Requires Human Verification` with a comment naming the batch. Summer verifies, then moves
  members + batch to `Done` — or comments the problems, and the groomer files fix tasks and
  bounces the affected members to `To Do`.
- Merge timing is unchanged from decision-10: merge happens at review-pass (entering
  `Reviewed`), NOT after human verification — main stays reviewed+CI-green, and the human gate
  verifies outcomes, it does not serialize merges.
- Roles: implementer (cheap) works `To Do → Doing → Needs Review`; reviewer (expensive) works
  `Needs Review → Reviewing → Reviewed`/`To Do`; groomer (expensive) works `Idea → Planned →
  To Do` and `Reviewed → Requires Human Verification`; Summer works
  `Requires Human Verification → Done`.

## Consequences

- Every existing `Review` task (13) migrated to `Needs Review`; `In Progress` (none open)
  renamed to `Doing` everywhere; conventions/loops/docs updated (CLAUDE.md, `loops/*`,
  `doc/process.html`).
- decision-7's "reviewer sets Done" is superseded: the reviewer now lands tasks at `Reviewed`;
  only Summer produces `Done`. The reviewed-by/implemented-by trail is unchanged.
- A new standing groomer loop exists (`loops/groomer.md`); the DoD gains a "Done only after
  Summer verified the batch" item.
- Slightly longer tail per task (Reviewed → batch → Done), accepted: the batch gate is what
  finally closes the "agent says done ≠ actually works" gap (2026-07-11).