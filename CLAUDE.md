# Project conventions for Claude

## Always keep the user guide current
`doc/user-guide.html` is a page-by-page walk-through of every screen, panel and icon
(purpose + how to use). **Whenever you add, change, or remove a feature, page, panel,
icon, notification category, mode, report, or setting, update `doc/user-guide.html` in the
same change** so it never drifts from the app. If the change is user-visible, it belongs in
the guide. Keep the marketing/overview doc `doc/index.html` roughly in step too, but the
user guide is the source of truth for "how to use it".

When a change adds a new screen, also regenerate screenshots when an emulator is available
(`flutter drive --driver=test_driver/screenshot_driver.dart
--target=integration_test/screenshots_test.dart -d <device>`) and reference the new PNG in
both docs.

## GitHub Issues (task tracking — the single planning source)
All planning lives in **GitHub Issues** on `danpowell88/bgdude` (CLI: `gh`). Backlog.md was
migrated here 2026-07-11 (decision-13); the old `TASK-<id>` → issue `#<n>` mapping is
`doc/backlog-migration-map.md`, and each migrated issue carries its full history (ACs, plan,
notes, comments) in its body. Structure:

- **Issues** are the unit of execution. **Status is a `status:*` label** (exactly one per
  open issue); **a closed issue is `Done`** (closing is Summer's act — see the pipeline).
- **Milestones** carry the phasing (`Phase 0: …` … `Phase 7: …`, `Code health`).
- **Project boards** are the column views. The main backlog board is user project **#2
  `bgdude`** (all open issues; built-in `Status` field carries the ten pipeline stages as
  columns, plus an `Ordinal` number field for ordering). Each milestone also has its own
  board — projects **#12–#20**, titled exactly like the milestones (`Phase 0: …` …
  `Code health`) — containing ALL of that milestone's issues including Done, so a phase's
  progress reads at a glance. Labels are canonical; the boards are mirrors
  (`.github/workflows/project-sync.yml` syncs label → board `Status` when its
  `PROJECT_SYNC_TOKEN` secret is configured — otherwise best-effort manual via
  `gh project item-edit`). When creating an issue, add it to project #2 and, if it has a
  milestone, to that milestone's project (`gh project item-add <n> --owner danpowell88
  --url <issue-url>`).
- **Decisions** (product/architecture choices that outlive an issue) live in
  `doc/decisions/decision-<n>.md` — check them before re-litigating one; add a new numbered
  file (straight-to-main lane) when a standing choice is made. Read-only charter, personal
  audience, GBM-not-neural, what-not-to-change all live there.
- The old `ROADMAP.md` is archived verbatim as `doc/roadmap-archived-2026-07-06.md` — issue
  notes citing `Source: ROADMAP section N` refer to it. There is no ROADMAP.md; do not
  recreate one.

### Working with issues (gh cheat-sheet)
- List pickable work: `gh issue list --label "status:to-do" --state open --limit 200`
- Read one fully: `gh issue view <n> --comments`
- Search: `gh issue list --search "<terms> in:title,body"` (add `in:comments` to search
  comment trails, e.g. `gh issue list --state all --search "friction: in:comments"`)
- Comment: `gh issue comment <n> --body "..."`
- Move status: `gh issue edit <n> --remove-label "status:to-do" --add-label "status:doing"`
- Edit body (tick AC checkboxes etc.): `gh issue view <n> --json body -q .body > b.md`,
  edit, `gh issue edit <n> --body-file b.md`
- Create: `gh issue create --title "<plain title>" --body-file <f> --label "status:idea"
  --label "priority:medium" --milestone "<milestone title>"` — then add it to the project:
  `gh project item-add <proj#> --owner danpowell88 --url <issue-url>`

### Structure conventions
- **Titles are plain descriptions** — no id prefixes and no `§` symbol; provenance lives in
  the body's `- Source:` bullet.
- **Issue bodies carry structured metadata as bullets** (the migrated issues model this):
  `- **Ordinal:** <n>`, `- **Depends on:** #<n>, #<m>`, `- **Branch:** issue-<n>`,
  `- **PR:** #<n>`, plus `## Description`, `## Acceptance Criteria` (checklist),
  `## Implementation Plan`, `## Implementation Notes`, `## Definition of Done` (checklist)
  sections. New issues follow the `.github/ISSUE_TEMPLATE/task.md` template.
- **Blockers go in the `Depends on:` bullet** as `#<n>` references (GitHub cross-links them),
  not prose. A partial dependency (only one stage blocked) still gets the entry, with the
  nuance spelled out in the plan. An issue is pickable only when every dependency is closed
  or `status:reviewed`.
- **Every issue gets a milestone**; new code-health work → `Code health`.
- **Definition of Done** is the CI-equivalent pipeline from "Verify the build" below — the
  issue template carries the checklist; tick items via body edit when finishing.
- **Execution order is encoded in ordinals** (2026-07-06 triage), in three bands:
  stabilise existing functionality (fixes, cleanup, tests — ordinals 100000+), then
  **finish existing features** (500000+), then new features (700000+). Pick work from
  the lowest ordinal whose dependencies are met; give a new issue an ordinal in the
  band it belongs to (fixes/tests → band 1, completing something started → band 2,
  net-new → band 3). Sort by ordinal with:
  `gh issue list --label "status:to-do" --state open --limit 200 --json number,title,body |
  jq -r 'map({n:.number,t:.title,o:(((.body // "") | capture("Ordinal:\\*\\* (?<o>[0-9]+)")?.o // "999999999") | tonumber)}) | sort_by(.o)[] | "\(.o)\t#\(.n)\t\(.t)"'`

### Status pipeline (decision-12; GitHub mechanics decision-13)
`Idea → Planned → To Do → Doing → Needs Review → Reviewing → Reviewed → Requires Human
Verification → Done`, plus `Blocked` (parked, usable from any active stage). Statuses map to
labels `status:idea`, `status:planned`, `status:to-do`, `status:doing`, `status:blocked`,
`status:needs-review`, `status:reviewing`, `status:reviewed`,
`status:needs-human-verification`; **`Done` = the issue is closed** (reason `completed`).
Keep exactly one `status:*` label on every open issue. Who moves what:

- **Idea** — raw thought, no ACs needed; anyone files these. **Planned** — groomed by the
  groomer loop (description, ACs, plan, milestone, ordinal, deps); `detail-needed` issues wait
  here. **To Do** — deps met, spec sufficient: the ONLY status implementers pick from.
- **Doing** — claimed by an implementer (claim protocol below). Must mean actively worked
  *right now*. **Needs Review** — verify pipeline green, branch pushed, PR open.
- **Reviewing** — claimed by a reviewer (same claim protocol; stops two reviewers racing one
  issue). **Reviewed** — review passed and **the PR is merged**; awaiting batch verification.
  A failed review goes back to **To Do** (branch + PR stay open).
- **Requires Human Verification** — the groomer groups `status:reviewed` issues into a
  `verification-batch` issue assigned to `danpowell88` (body = per-member checklist of what
  to verify on the real app); members move here with a comment naming their batch. **Done** —
  Summer verified the batch and **closes the issues** (the one agent path to closing is the
  groomer acting on her recorded verdict). **Agents never close a task issue otherwise**
  (DoD item); merge already happened at `Reviewed`, so the human gate verifies outcomes
  without serializing merges.
- **PRs must never auto-close issues**: reference the issue as `Refs #<n>` / `Issue: #<n>`,
  NEVER `Closes/Fixes/Resolves #<n>` — a closing keyword would mark the issue Done at merge
  time, bypassing Summer's gate.

### Comment as you work
All agents share one GitHub account, so **every comment starts with your agent id**:
`gh issue comment 42 --body "<agent-id>: Started — <approach in one line>"`. The
`implemented-by:` / `reviewed-by:` tags and comment signatures are the greppable record of
who did what (`in:comments` search) — keep both present on every issue that reaches Reviewed.

- **Claiming (replaces the old claim-commit protocol — no git involved).** To claim, in one
  step flip the label and sign it:
  `gh issue edit <n> --remove-label "status:to-do" --add-label "status:doing"` then
  `gh issue comment <n> --body "<agent-id>: claiming — branch issue-<n> — <approach>"`.
  Then **re-read the issue** (`gh issue view <n> --comments`): if another agent's claiming
  comment is already there with an earlier timestamp, they win — restore the label, drop a
  one-line "backing off" comment, and pick something else. Claims are visible instantly to
  every session (no push race, no bookkeeping commits — this is why the migration happened;
  see decision-13 / old TASK-310).
- While working: comment any **significant finding, decision, or deviation** from the plan
  (what and why) — not a play-by-play, just what a reviewer would want to know.
- When you **finish the implementation**: first `git merge origin/main` into the branch — a
  branch must enter `Needs Review` mergeable (a conflicting PR doesn't even run CI) — then
  confirm code + tests + the full verify pipeline green on the branch. Tick the AC
  checkboxes (body edit), **push the `issue-<n>` branch and open a PR against `main`** (do
  NOT merge it yourself):
  `gh pr create --base main --head issue-<n> --title "issue-<n>: <title>" --body "<summary,
  ACs addressed, test evidence, implemented-by line, Refs #<n>>"`.
  If a PR for the branch already exists (rework after a failed review), just push — the PR
  updates itself; leave a PR comment saying what changed. Add the `- **PR:** #<pr>` bullet to
  the issue body, move the issue to `status:needs-review`, and add a closing comment tagged
  `implemented-by: <your-agent-id> — branch issue-<n>, PR #<pr>, <files, tests, commit hash>`.
  **This closing comment MUST end with a friction line** — a `friction:<category> — …` bullet
  for anything that tripped you up (build/env/deps/code/test/tooling), or literally
  `friction:none` if it was genuinely smooth. No issue reaches `Needs Review` without one —
  the Review gate is the *floor* that makes the friction trail exist; logging in the moment
  (below) is the ideal.
- **Review stage — done by the reviewer loop (expensive model), a different agent, which also
  merges the PR.** An issue in `status:needs-review` is picked up by a **different agent than
  the `implemented-by` one** (normally the scheduled reviewer loop, `loops/reviewer.md`) — an
  issue must never be reviewed or merged by its own implementer (decision-7). The reviewer
  **claims it first** (`status:reviewing` + signed claiming comment, same protocol). Then it
  finds the PR (`gh pr list --head issue-<n>` or the body's PR bullet), verifies the ACs and
  DoD against the PR diff (apply the "sweep the whole surface" checklist below), and checks
  CI (`gh pr checks <pr>`). If the branch is stale or conflicts with `main`, the reviewer
  merges `main` into the branch, resolves faithfully to both sides' intent, pushes, and lets
  CI re-run before judging. Review notes go on **both** the PR and the issue. Then:
  - **Pass** → comment tagged `reviewed-by: <reviewer-agent-id> — <what was checked /
    verdict>`, tick the DoD boxes (body edit), **merge the PR:
    `gh pr merge <pr> --merge --delete-branch`** (**never `--admin`** — if GitHub refuses
    because checks are red or pending, that is the gate working: wait or fail the review,
    don't bypass). Move the issue to `status:reviewed` — do NOT close it.
  - **Fail** → comment tagged `reviewed-by: <reviewer-agent-id> — <the problems>`, leave the
    concrete follow-ups as PR comments, **do not merge**, and move the issue back to
    `status:to-do` (or `status:blocked`, or file a prioritised follow-up issue for a
    separable gap) so any implementer resumes **on the same branch/PR**. Never rubber-stamp
    or merge on a fail.
- **Human verification — Summer's gate, batch-level (decision-12).** The groomer loop
  (`loops/groomer.md`) groups `status:reviewed` issues into a `verification-batch` issue
  assigned to `danpowell88` whose body checklist lists, per member, exactly what to check on
  the real app; members move to `status:needs-human-verification` with a comment
  `verification-batch: #<batch>`. Summer verifies and closes members + batch — or comments
  the problems, and the groomer files fix issues and bounces the affected members to
  `status:to-do`. **No agent ever closes a task issue except the groomer acting on Summer's
  recorded verdict.**
- When you **cannot make further progress** — a dependency, a missing decision or answer, or
  an environment limitation (e.g. no reachable emulator) blocks you — **do not leave the
  issue `status:doing`**. Move it to `status:blocked`, comment the blocker and exactly what
  would unblock it, and if another issue is the blocker add it to the `Depends on:` bullet.
  Move it back to `status:doing` only when you actually resume it, or to `status:to-do` if
  you are handing it off unstarted. **`Doing` must mean actively being worked right now**
  (and `Reviewing` actively being reviewed) — never a parked, waiting, or half-done issue.
  Before ending a work session, sweep your `Doing`/`Reviewing` issues and re-status any you
  are not still actively progressing.
- **Log friction as you hit it** — whenever something slows you down or trips you up, drop a
  one-line comment on that issue tagged **`friction:<category>`** so the groomer can
  aggregate them and turn recurring ones into fixes or conventions. Err toward logging.
  Categories: `build` (CI/gradle/codegen/APK breakage), `env` (emulator/SDK/device/platform
  limits), `deps` (package/version/pub conflicts), `code` (a language/API/framework footgun),
  `test` (a flaky/hollow/hard-to-write test), `tooling` (gh, git, this harness, editors).
  Format: `friction:<category> — <what bit you> — <root cause and the fix/workaround, if
  known>`. One comment per distinct issue; skip the trivial; include the fix so the trail is
  actionable. If the friction isn't tied to one issue, log it on the closest related one.
  The tag is greppable repo-wide: `gh issue list --state all --search "friction: in:comments"`.

### `detail-needed` label
If an issue lacks the information needed to implement it properly (unclear requirement,
missing decision, unknown validation data, ambiguous acceptance criterion), **do not guess**:

```
gh issue edit 42 --add-label "detail-needed"
gh issue comment 42 --body "<agent-id>: detail-needed — <the specific questions>"
```

State the concrete questions in the comment. If the issue was `status:doing`, move it to
`status:blocked` (an information gap you cannot resolve yourself is a blocker); if it was
`status:to-do`, demote it to `status:planned` so implementers stop picking it up until the
groomer/Summer answers. Either way it must not stay `Doing`. Then move on.
(`needs-exploration` is the related label for issues known to be under-scoped at creation;
`detail-needed` is for gaps you discover.)

### Formatting issue content (GitHub renders markdown)
Issue bodies and comments render as GitHub-flavored markdown. Rules:

- **Use bullet lists, not prose blocks.** Any sequence of facts, steps, or key–value pairs
  must be a `- ` list (Implementation Notes are always bullets: `- Source: …`, `- Effort: …`).
- **Short paragraphs** (≤3 sentences) separated by blank lines; a bold lead-in
  (`**Background.**`) only for genuine paragraphs.
- **Implementation plans are numbered/bulleted steps**, one step per line.
- Wrap code identifiers/paths in backticks so underscores don't italicise, and so `#123` in
  code/paths isn't auto-linked as an issue reference. Only write a bare `#<n>` when you MEAN
  to cross-reference that issue/PR, and never a closing keyword (`Closes #n`) outside of
  Summer's own use.
- When passing multi-line text to `gh --body`, use `--body-file` or a here-string with real
  newlines. Never write literal `\n`.

## Agent roles (model tiering — decisions 10 + 12)
Work in this repo is split across three agent roles (chosen by cost) plus one human gate:

- **Implementers — cheap models.** Claude Sonnet/Haiku sessions, or external CLI agents
  (e.g. **qwen code**) — external agents follow these same conventions: `gh`, the claim
  protocol, branch/worktree isolation, the verify pipeline, the PR flow, and they sign
  comments, `implemented-by:` tags and `Co-Authored-By` with their own agent id (e.g.
  `qwen-code`). They pick the lowest-ordinal `status:to-do` issue whose deps are met, claim
  it (`status:doing`), implement it on an `issue-<n>` branch, and open a PR
  (loop prompt: `loops/implementer.md`).
- **Reviewers — expensive model.** A scheduled loop (e.g. Opus/Fable) that drains the
  `status:needs-review` queue: claims (`status:reviewing`), reviews each issue's PR, merges
  `main` into stale branches, and is the **only** thing that merges to `main`; a pass lands
  at `status:reviewed` (loop prompt: `loops/reviewer.md`). Reviewer ≠ implementer
  (decision-7).
- **Groomer — expensive model.** A scheduled loop that refines `Idea → Planned → To Do`
  (specs, ACs, plans, ordinals, deps), batches `status:reviewed` issues into
  `verification-batch` issues for Summer (`status:needs-human-verification`), processes her
  verdicts, and mines `friction:` comments (loop prompt: `loops/groomer.md`).
- **Summer — the human gate.** Verifies each batch on the real app and is the only one who
  closes task issues (`Done`).

## Git
**Concurrent sessions isolate via worktrees + branches — ALL work, no exceptions.** When more
than one session/agent writes to this repo at once (implementer agents, the reviewer/meta
loops, any file-mutating agent), each works in its **own git worktree on its own short-lived
branch off `main`** — this is what prevents two sessions racing on one working tree (the "file
modified since read" / manually-scoped-commit problem). Workflow:
- `git worktree add ../bgdude-<purpose> -b <purpose>` off the latest `main` (e.g.
  `../bgdude-issue-42`, `../bgdude-review`). One branch per worktree — git refuses to check
  out `main` in two worktrees at once, which is exactly why concurrent writers need branches.
- Subagents that **mutate files in parallel** take `isolation: "worktree"` on the Agent tool;
  read-only reviewers don't need it.

**Task work ships as a GitHub PR and reaches `main` only via a reviewed, CI-green PR merge
(decision-10).** Do NOT push task work straight to `main`. Concretely:
- One branch per issue, deterministically named **`issue-<n>`** (n = the issue number;
  optionally `issue-<n>-<slug>`), created off the latest `main` in its own worktree. Record
  it on the issue (`- **Branch:** issue-<n>` bullet / claiming comment). (Pre-migration
  branches are named `task-<id>` after their old Backlog IDs — `doc/backlog-migration-map.md`
  maps them; do NOT reuse the `task-` prefix for new work, the numbers would collide.)
- The implementer commits to that branch through `Doing`; when done it pushes the branch,
  **opens a PR** (`gh pr create`, title `issue-<n>: <title>`, body `Refs #<n>` — never a
  closing keyword), records `PR: #<pr>` on the issue, and moves the issue to
  `status:needs-review` (never further, never a `main` push, never a self-merge).
- **The reviewer loop is the only merger, and it merges via the PR** (`gh pr merge --merge`),
  only after a passing review with CI green. On a fail it comments on the PR + issue and
  bounces the issue back to `status:to-do` (see `### Comment as you work`). It never merges a
  PR whose `implemented-by` is itself (reviewer ≠ implementer, decision-7).
- **A GitHub ruleset enforces this** ("main merge gate: PR + green CI"): merging to `main`
  requires a PR with required checks `analyze`, `coverage-gate`, `apk-build`, `native-tests`,
  `native-lib-alignment`, `actionlint`, `android-lint`, `dependency-review` green **and
  CodeQL code-scanning results with no high+ security / error-level alerts**
  (decision-11 — the CodeQL workflow `.github/workflows/codeql.yml` scans the `android/`
  Kotlin + workflow files; Dart is not CodeQL-supported and is covered by our own checks
  instead); merge-commit method only; no force-push or deletion of `main`. Repository admins
  carry an `always` bypass **solely** for rare non-task bookkeeping commits (below) — using
  it to merge a PR (`gh pr merge --admin`) or push task code to `main` is forbidden. If a
  merge is refused, CI isn't green: fix that, never bypass.

**Straight-to-`main` is only for non-task bookkeeping** — `doc/decisions/` entries, config
edits, and trivial docs. (Issue status changes are `gh` API calls now, NOT commits — the
old claim/status-commit churn is gone, which is what kept feature branches from rotting;
decision-13.) These aren't feature work and carry no review gate. See the memory
`git-workflow` and `doc/decisions/` (6, 7, 8, 10, 12, 13).

## Verify the build after EVERY task (must match CI — CI is the source of truth)
The GitHub Actions workflow (`.github/workflows/ci.yml`) is what decides if `main` is
green, and **it must never be left red**. `flutter analyze` + `flutter test` passing is
**not sufficient** — CI also generates code and builds the APK, so a change can be
"green locally" yet break CI. After finishing any task (and before committing), run the
**same pipeline CI runs, in this order**, and only commit when it all passes:

1. `flutter pub get`
2. `dart run build_runner build --delete-conflicting-outputs` — **required**: generated
   files (`*.g.dart`, drift) are **not committed**, so analyze/test/build all depend on
   this succeeding. If you changed dependencies (esp. removing/adding codegen packages
   like drift/build_runner), this is the step most likely to break CI — run it.
3. `flutter analyze` — clean.
4. `flutter test --coverage test/` — green (this is the scope CI uses; the
   `integration_test/` suite needs an emulator and is separate).
   **Line coverage must not drop.** After the run, compute the percentage the way CI
   does — sum `LH:`/`LF:` over `coverage/lcov.info`, excluding `lib/data/database.g.dart`
   — and confirm it is at or above the floor in `ci.yml` (floor 65%; actual ~67.4% on
   2026-07-08). Coverage is a **ratchet, per ticket**: any new testable code ships with
   its tests in the *same* change, so the number never regresses; if your change lowers
   it, add tests until it recovers before committing; if it raises the sustained level,
   bump the `ci.yml` floor so the gain is locked in. **CI machine-enforces the ratchet on
   PRs** (decision-11): the `coverage-gate` check fails any PR whose coverage is below the
   latest successful `main` run's, not just below the floor — so a local pass at 65% can
   still fail CI if `main` is higher. (UI-only screens are covered by the
   `integration_test/` suite, not unit tests — don't chase their unit-coverage lines.)
5. `flutter build apk --debug` — **required**: this catches Android/Gradle/manifest
   breakage that analyze and unit tests miss. Do not skip it.
6. When native Kotlin changed: `cd android && ./gradlew :app:testDebugUnitTest`.

If any step fails, fix it before committing — do not push a change that would turn CI
red. If CI is already red on `main`, treat getting it green as part of the current task.
Native code is buildable/testable here (JDK + Android SDK present); verify pumpx2 APIs via
`javap` on the cached jar before writing.

**Dev-env gotcha — don't reach for `dart run` here.** `dart run <script>` crashes on this
package (an FFI/kernel-transform exception) *even for pure-Dart, Flutter-independent files*, so a
throwaway "quick probe" script is not viable. When you want to sanity-check a pure-Dart function
in isolation, write a throwaway file under `test/` and run it with `flutter test <file>` instead —
it works, just slightly slower to spin up. (Source: friction:tooling, old TASK-155.)

## Fixing a bug? Sweep the whole surface — don't just patch the reported site
The single most common defect the review loop finds is a fix that **protects its literal
target but leaves the symmetric/adjacent path unguarded**. This has recurred repeatedly
(e.g. `@Volatile` fixed visibility but not the compound-op race → a follow-up was needed;
a persist gate was applied to the annotation but not the sibling notification; a clamp
guarded three divisions and missed the fourth; per-field range validation shipped without
the ordering invariant; a "crash detector" test couldn't actually fail). Before you call a
fix done, sweep these four axes:

- **Sibling call sites** — `grep` for the *same construct* you just fixed and patch every
  occurrence, not only the one in the ticket. If you guarded one `/ isf`, one `.values[i]`
  enum decode, one `jsonDecode`, one unclamped field — find the others in that file and its
  siblings and guard them too (or state why they don't need it).
- **Both branches / every side-effect of the same action** — if you gate something on
  success, gate *every* user-visible effect of that action the same way (persist-before-emit
  applies to the annotation **and** the notification **and** the state). Handle the failure
  branch, not just the happy path. If you validate a value, validate its relationships too
  (a per-field range check is not an ordering check).
- **A test that actually fails if the fix is reverted** — every fix ships with a
  negative-case test whose assertion is on the *real invariant/output*, not `returnsNormally`
  / "no throw" / a log the test binding never populates. If you can't make it fail by
  reverting the fix, the test is hollow. (Prove it: revert, watch it go red, restore.)
- **Concurrency & security nuance** — visibility ≠ atomicity (`@Volatile` doesn't make a
  read-modify-write atomic); a host-allowlist check is not a scheme check; a redirect re-checks
  per hop. When the fix touches threads, tokens, or redirects, reason about the *other* way it
  can still go wrong.

Reviewing someone else's fix? Apply the same four axes before trusting the green checkbox —
"the fix compiles and its one test passes" is exactly the state these misses hide in.

## Emulator (integration) tests for every feature
Every user-facing screen/flow should have on-device coverage under `integration_test/`
(shared helpers in `integration_test/harness.dart`; run in demo mode). When you add or
change a screen, panel, mode, report, or setting, add/extend an integration test so it's
exercised on a device. Run: `flutter test integration_test/<file>.dart -d <device-id>`
(an emulator, e.g. `emulator-5554`, is available). The `screenshots_test.dart` /
`walkthrough_test.dart` files need `flutter drive`, so run the functional `*_test.dart`
files explicitly rather than the whole folder.
