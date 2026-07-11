---
name: bgdude-issues
description: Operate bgdude's GitHub-Issues workflow — the single planning source on danpowell88/bgdude. Use when picking up, claiming, progressing, commenting on, or finishing issue work, or when creating issues. Covers the status-label pipeline, the gh cheat-sheet, ordinals and body structure, comment/friction tags, and the rule that PRs never auto-close issues. Pairs with the general `github` skill (gh mechanics) and `verify-build`.
---

# Working bgdude issues

All planning lives in **GitHub Issues** on `danpowell88/bgdude` (CLI: `gh`). Issues are the
unit of execution.

## Status is a label; Done = closed
- **Status is a `status:*` label** — exactly one per open issue. A **closed** issue is
  `Done`, and **closing is Summer's act** (the human gate), not an agent's.
- Pipeline (each stage is a `status:*` label): `idea → planned → to-do → doing →
  needs-review → reviewing → reviewed → needs-human-verification`, plus `blocked` (parked,
  usable from any active stage). Implementers pick only from `status:to-do`.
- Move status by flipping the label:
  `gh issue edit <n> --remove-label "status:to-do" --add-label "status:doing"`.

## Boards, milestones, decisions
- **Milestones** carry the phasing (`Phase 0…7`, `Code health`). Every issue gets one; new
  code-health work → `Code health`.
- **Project boards** mirror the labels: main backlog is user project **#2 `bgdude`** (built-in
  `Status` field = the pipeline columns, plus an `Ordinal` number field). Each milestone also
  has its own board (projects **#12–#20**). Labels are canonical; boards are mirrors
  (`.github/workflows/project-sync.yml` syncs label → board when `PROJECT_SYNC_TOKEN` is set,
  else `gh project item-edit` manually). On create, add the issue to project #2 and its
  milestone's project: `gh project item-add <n> --owner danpowell88 --url <issue-url>`.
- **Decisions** that outlive an issue live in `doc/decisions/decision-<n>.md` — check them
  before re-litigating; add a new numbered file (straight-to-main) when a standing choice is
  made.

## gh cheat-sheet
- Pickable work: `gh issue list --label "status:to-do" --state open --limit 200`
- Read fully: `gh issue view <n> --comments`
- Search: `gh issue list --search "<terms> in:title,body"` (add `in:comments` for comment
  trails, e.g. `gh issue list --state all --search "friction: in:comments"`)
- Comment: `gh issue comment <n> --body "..."`
- Edit body (tick AC checkboxes): `gh issue view <n> --json body -q .body > b.md`, edit,
  `gh issue edit <n> --body-file b.md`
- Create: `gh issue create --title "<plain title>" --body-file <f> --label "status:idea"
  --label "priority:medium" --milestone "<milestone title>"`, then add to the project.

## Structure conventions
- **Titles are plain descriptions** — no id prefixes, no `§`; provenance lives in a
  `- Source:` bullet.
- **Bodies carry structured metadata as bullets**: `- **Ordinal:** <n>`,
  `- **Depends on:** #<n>`, `- **Branch:** issue-<n>`, `- **PR:** #<n>`, plus `## Description`,
  `## Acceptance Criteria` (checklist), `## Implementation Plan`, `## Implementation Notes`,
  `## Definition of Done` (checklist). New issues follow `.github/ISSUE_TEMPLATE/task.md`.
- **Blockers go in the `Depends on:` bullet** as `#<n>` references, not prose. An issue is
  pickable only when every dependency is closed or `status:reviewed`.
- **Definition of Done** is the CI-equivalent pipeline (see the `verify-build` skill).
- **Execution order is encoded in ordinals**, in three bands: stabilise (fixes/cleanup/tests,
  100000+), then finish existing features (500000+), then new features (700000+). Pick the
  lowest ordinal whose deps are met. Sort:
  ```
  gh issue list --label "status:to-do" --state open --limit 200 --json number,title,body |
  jq -r 'map({n:.number,t:.title,o:(((.body // "") | capture("Ordinal:\\*\\* (?<o>[0-9]+)")?.o // "999999999") | tonumber)}) | sort_by(.o)[] | "\(.o)\t#\(.n)\t\(.t)"'
  ```

## Comment as you work
All agents share one GitHub account, so **every comment starts with your agent id**:
`gh issue comment 42 --body "<agent-id>: Started — <approach>"`. Keep `implemented-by:` /
`reviewed-by:` tags and signatures present — they're the greppable `in:comments` record.

- **While working**: comment any significant finding, decision, or deviation (what and why),
  not a play-by-play.
- **Finishing**: first `git merge origin/main` into the branch, then confirm code + tests +
  the full verify pipeline green (see `verify-build`). Tick the AC checkboxes, push, and open
  a PR (if one exists, just push — it updates itself; leave a comment on what changed). Add
  the `- **PR:** #<pr>` bullet, and a closing comment tagged
  `implemented-by: <agent-id> — branch issue-<n>, PR #<pr>, <files, tests, commit>`. **This
  closing comment MUST end with a friction line** (below) — `friction:none` if it was smooth.
- **Blocked**: when a dependency / missing decision / environment limit blocks you, **do not
  leave the issue `status:doing`** — move it to `status:blocked`, comment the blocker and what
  would unblock it, and add the blocker to `Depends on:`. `Doing` must mean *actively worked
  right now*; sweep your `Doing`/`Reviewing` issues before ending a session.

## PRs never auto-close issues
Reference the issue as `Refs #<n>` / `Issue: #<n>` — **never** `Closes/Fixes/Resolves #<n>`.
A closing keyword would mark the issue Done at merge time, bypassing the human (Summer) gate.

## Log friction as you hit it
Whenever something slows you down, drop a one-line comment tagged **`friction:<category>`** so
recurring ones become fixes/conventions. Categories: `build` (CI/gradle/codegen/APK), `env`
(emulator/SDK/device), `deps` (package/version/pub), `code` (a language/API footgun), `test`
(flaky/hollow/hard test), `tooling` (gh, git, harness, editors). Format:
`friction:<category> — <what bit you> — <root cause and the fix/workaround>`. One per distinct
issue; skip the trivial; include the fix. Greppable: `gh issue list --state all --search
"friction: in:comments"`.
