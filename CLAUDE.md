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

## Backlog (task tracking — the single planning source)
All planning lives in [Backlog.md](https://github.com/MrLesk/Backlog.md) under `backlog/`
(CLI: `backlog`, e.g. `backlog task list --plain`, `backlog task 42 --plain`): **tasks** are
the unit of execution, **milestones** (m-0..m-8) carry the phasing, **decisions**
(`backlog/decisions/`) hold standing product/architecture choices (read-only charter,
personal audience, GBM-not-neural, what-not-to-change), and **docs** hold archived
narrative (the old `ROADMAP.md` is archived verbatim as doc-1 — task notes citing
`Source: ROADMAP section N` refer to it). There is no ROADMAP.md; do not recreate one.

<!-- BACKLOG.MD GUIDELINES START -->
<CRITICAL_INSTRUCTION>

## Backlog.md Workflow

This project uses Backlog.md for task and project management.

**For every user request in this project, run `backlog instructions overview` before answering or taking action.**

Use the overview to decide whether to search, read, create, or update Backlog tasks.

Use the detailed guides when needed:
- `backlog instructions task-creation` for creating or splitting tasks
- `backlog instructions task-execution` for planning and implementation workflow
- `backlog instructions task-finalization` for completion and handoff

Use `backlog <command> --help` before running unfamiliar commands. Help shows options, fields, and examples.

Do not edit Backlog task, draft, document, decision, or milestone markdown files directly. Use the `backlog` CLI so metadata, relationships, and history stay consistent.

</CRITICAL_INSTRUCTION>
<!-- BACKLOG.MD GUIDELINES END -->

The formatting rules below apply to the *text you pass* via CLI flags.

### Structure conventions
- **Titles are plain descriptions** — no roadmap-id prefixes (`P0-1`, `3.A`, `4-1.2`) and no
  `§` symbol anywhere in task content; provenance lives in the Notes `- Source:` bullet.
- **Blockers go in the real `dependencies` field** (`--dep task-2,task-46`), not prose.
  `backlog sequence list --plain` then shows the execution order. A partial dependency
  (only one stage blocked) still gets the dep, with the nuance spelled out in the plan.
- **Every task gets a milestone** (`-m m-5`); milestones mirror the ROADMAP execution
  phases (`backlog milestone list --plain`). New code-health work → `Code health` (m-8).
- **Definition of Done defaults** are set project-wide (the CI-equivalent pipeline from
  "Verify the build" below) — check them off with `--check-dod <n>` when finishing.
- **Decisions** (product/architecture choices that outlive a task) are recorded with
  `backlog decision create` — check `backlog/decisions/` before re-litigating one.
- When starting a task also **assign yourself**: `-a Claude`.
- **Execution order is encoded in ordinals** (2026-07-06 triage), in three bands:
  stabilise existing functionality (fixes, cleanup, tests — ordinals 100000+), then
  **finish existing features** (500000+), then new features (700000+). Pick work from
  the lowest ordinal whose dependencies are met; give a new task an ordinal in the
  band it belongs to (fixes/tests → band 1, completing something started → band 2,
  net-new → band 3).

### Comment as you work
Use the **comment field** to leave a trail on the task you're working on:

```
backlog task edit 42 --comment "Started: <approach in one line>" --comment-author "Claude"
```

- When you **start** a task: set `-s "In Progress"`, assign yourself as the implementer
  (`-a <your-agent-id>` — the same identity you sign commits with, e.g. the `Co-Authored-By`
  model/session name), record the branch (`--comment "branch: task-<id>"`), and add a comment
  stating the approach.
- **Commit and push every status transition IMMEDIATELY — this is how parallel sessions avoid
  duplicating work.** Task status lives in `backlog/tasks/task-<id>.md`, and `auto_commit` is
  off, so a status change nobody committed is invisible to other sessions pulling `main`. The
  instant you **claim** a task (To Do → In Progress) — before you write any code — commit that
  task-file change to `main` and push (`git add backlog/tasks/task-<id>*.md && git commit && git
  push`). Do the same for every later move (→ Review, → Blocked, → Done). These claim/status
  commits are coordination bookkeeping and go **straight to `main`** (decision-8), separate from
  the task's code on its `task-<id>` branch. A branch pushed while its task is still `To Do` is
  a bug: another agent can't tell it's claimed and will duplicate it — always flip status +
  commit + push at claim time.
- While working: add a comment for any **significant finding, decision, or deviation** from
  the implementation plan (what and why) — not a play-by-play, just the things a reviewer
  would want to know.
- When you **finish the implementation**: first `git merge origin/main` into the branch — a
  branch must enter `Review` mergeable (`main` churns fast here; a conflicting PR doesn't even
  run CI, TASK-310) — then confirm code + tests + the full verify pipeline green on the branch.
  Check off the acceptance criteria (`--check-ac <n>`), **push the `task-<id>` feature
  branch and open a PR against `main`** (do NOT merge it yourself):
  `gh pr create --base main --head task-<id> --title "TASK-<id>: <task title>" --body "<task summary, implemented-by line, test evidence>"`.
  If a PR for the branch already exists (rework after a failed review), just push — the PR
  updates itself; leave a PR comment saying what changed. Record the PR on the task
  (`--comment "PR: #<n>"`) and move the task to **`-s Review`** — never straight to `Done`.
  Add a closing comment tagged
  `implemented-by: <your-agent-id> — branch task-<id>, PR #<n>, <files, tests, commit hash>`. Leave
  yourself as the assignee so it's clear who did the work.
  **This closing comment MUST end with a friction line** — a `friction:<category> — …` bullet
  for anything that tripped you up (build/env/deps/code/test/tooling), or literally
  `friction:none` if it was genuinely smooth. No task reaches `Review` without one. This is the
  forcing function that makes the friction trail actually exist: the "log friction as you hit
  it" bullet below is the ideal (log in the moment), but the Review gate is the *floor* — a
  task with no friction line is not ready for Review. (Rationale: the friction convention had
  **zero** logged comments backlog-wide until this rule; the meta loop that mines them was
  starved. Tying capture to an already-required step fixes adoption.)
- **Review stage — done by the reviewer loop (expensive model), a different agent, which also
  merges the PR.** A task in `Review` is picked up by a **different agent than the
  `implemented-by` one** (normally the scheduled reviewer loop, `loops/reviewer.md`) — a task
  must never be reviewed or merged by its own implementer (decision-7). The reviewer finds the
  task's PR (`gh pr list --head task-<id>`; if a legacy branch has none, open it), verifies the
  ACs and DoD against the PR diff (apply the "sweep the whole surface" checklist above), and
  checks CI on the PR (`gh pr checks <n>`). If the branch is stale or conflicts with `main`,
  the reviewer merges `main` into the branch (`git merge origin/main`, resolve, push) and lets
  CI re-run before judging. Review notes go on **both** the PR (inline/`gh pr comment`) and the
  task. Then:
  - **Pass** → add a comment tagged `reviewed-by: <reviewer-agent-id> — <what was checked / verdict>`,
    check off the DoD (`--check-dod <n>`), and **merge the PR: `gh pr merge <n> --merge --delete-branch`**
    (merge commit ≈ the old `--no-ff`; **never `--admin`** — if GitHub refuses because checks
    are red or pending, that is the gate working: wait or fail the review, don't bypass). Set
    `-s Done` and remove the local worktree. Done requires this reviewed-by comment from a
    second agent (DoD item) and only ever happens via this PR merge.
  - **Fail** → add a `reviewed-by: <reviewer-agent-id> — <the problems>` comment on the task,
    leave the concrete follow-ups as PR comments, **do not merge**, and send the task back to
    **`-s "To Do"`** (or `Blocked`, or file a prioritised follow-up ticket for a separable gap)
    so any implementer can pick it up and resume **on the same branch/PR**. Never rubber-stamp
    or merge on a fail.
  - The `implemented-by:` / `reviewed-by:` tags (plus each comment's `--comment-author`) are the
    greppable record of **who did the work and who reviewed/merged it** — keep both present on
    every task that reaches Done.
- When you **cannot make further progress** — a dependency, a missing decision or answer, or
  an environment limitation (e.g. no reachable emulator) blocks you — **do not leave the task
  `In Progress`**. Set `-s Blocked`, add a comment naming the blocker and exactly what would
  unblock it, and if another task is the blocker record it in the `dependencies` field
  (`--dep task-N`). Move it back to `In Progress` only when you actually resume it, or to
  `To Do` if you are handing it off unstarted. **`In Progress` must mean actively being worked
  right now** — never a parked, waiting, or half-done task. Before ending a work session,
  sweep your `In Progress` tasks and re-status any you are not still actively progressing
  (`Done` if finished, `Blocked` if stuck, `To Do` if not really started).
- **Log friction as you hit it** — whenever something slows you down or trips you up while
  working a task, drop a one-line comment on that task tagged **`friction:<category>`** so the
  review/meta loops can aggregate them later and turn the recurring ones into fixes or
  conventions. This is the raw material those loops mine — capturing it is the point, so err
  toward logging. Categories: `build` (CI/gradle/codegen/APK breakage), `env` (emulator/SDK/
  device/platform limits), `deps` (package/version/pub conflicts), `code` (a language/API/
  framework footgun or a pattern that bit you), `test` (a flaky/hollow/hard-to-write test),
  `tooling` (the `backlog` CLI, git, this harness, editors). Format:
  `friction:<category> — <what bit you> — <root cause and the fix/workaround, if known>`.
  One comment per distinct issue; skip the trivial; include the fix so the trail is
  actionable, not just a complaint. Example:
  `backlog task edit 42 --comment "friction:env — emulator VM-service WebSocket fails for ANY integration_test file here (pre-existing, not test-specific); workaround: run unit tests only, leave on-device ACs Blocked" --comment-author "Claude"`.
  If the friction isn't tied to one task, log it on the closest related task (or the one you
  were on when it happened). The tag is greppable across `backlog/tasks` + `backlog/completed`,
  which is how the loops find them.

### `detail-needed` label
If a task lacks the information needed to implement it properly (unclear requirement,
missing decision, unknown validation data, ambiguous acceptance criterion), **do not guess**:

```
backlog task edit 42 --add-label detail-needed --comment "detail-needed: <the specific questions>" --comment-author "Claude"
```

State the concrete questions in the comment. If the task was `In Progress`, move it to
`-s Blocked` (an information gap you cannot resolve yourself is a blocker); otherwise leave it
in `To Do`. Either way it must not stay `In Progress`. Then move on. (`needs-exploration` is
the related pre-existing label for tasks that were known to be under-scoped at creation;
`detail-needed` is for gaps you discover.)

### Formatting task content (important — renders as markdown)
Task sections (Description, Plan, Notes, comments) are rendered as **markdown** in the
Backlog.md web UI. Consecutive lines without a blank line between them collapse into one
run-on paragraph, and long prose paragraphs are unreadable there. Rules:

- **Use bullet lists, not prose blocks.** Any sequence of facts, steps, or key–value pairs
  must be a `- ` list (e.g. Implementation Notes are always bullets: `- Source: …`,
  `- Effort: …`). Never bare `Key: value` lines on consecutive lines.
- **Short paragraphs** (≤3 sentences) separated by blank lines; prefer a bold lead-in
  (`**Background.**`) only for genuine paragraphs, not to glue a list into prose.
- **Implementation plans are numbered/bulleted steps**, one step per line, not a single
  paragraph narrating the whole plan.
- When passing multi-line text to the CLI, include real newlines inside the quoted string.
  Never write literal `\n`.
- Wrap code identifiers/paths in backticks so they don't italicise (underscores).

## Agent roles (model tiering — decision-10)
Work in this repo is split across two agent roles, chosen by cost:

- **Implementers — cheap models.** Claude Sonnet/Haiku sessions, or external CLI agents
  (e.g. **qwen code**) — external agents follow these same conventions: the `backlog` CLI,
  the claim protocol, branch/worktree isolation, the verify pipeline, the PR flow, and they
  sign `implemented-by:`/`--comment-author`/`Co-Authored-By` with their own agent id (e.g.
  `qwen-code`). They pick the lowest-ordinal `To Do` task whose deps are met, claim it,
  implement it on a `task-<id>` branch, and open a PR (loop prompt: `loops/implementer.md`).
- **Reviewers — expensive model.** A scheduled loop (e.g. Opus/Fable) that drains the `Review`
  queue: reviews each task's PR, merges `main` into stale branches, and is the **only** thing
  that merges to `main` (loop prompt: `loops/reviewer.md`). Reviewer ≠ implementer
  (decision-7).

## Git
**Concurrent sessions isolate via worktrees + branches — ALL work, no exceptions.** When more
than one session/agent writes to this repo at once (implementer agents, the reviewer/meta
loops, any file-mutating agent), each works in its **own git worktree on its own short-lived
branch off `main`** — this is what prevents two sessions racing on one working tree (the "file
modified since read" / manually-scoped-commit problem). Workflow:
- `git worktree add ../bgdude-<purpose> -b <purpose>` off the latest `main` (e.g.
  `../bgdude-task-42`, `../bgdude-review`). One branch per worktree — git refuses to check out
  `main` in two worktrees at once, which is exactly why concurrent writers need branches.
- Subagents that **mutate files in parallel** take `isolation: "worktree"` on the Agent tool;
  read-only reviewers don't need it.

**Task work ships as a GitHub PR and reaches `main` only via a reviewed, CI-green PR merge
(decision-10, refining decision-8).** Do NOT push task work straight to `main`. Concretely:
- One branch per task, deterministically named **`task-<id>`** (optionally
  `task-<id>-<slug>`), created off the latest `main` in its own worktree. Record it on the task
  (`--comment "branch: task-<id>"`).
- The implementer commits to that branch through `In Progress`; when done it pushes the branch,
  **opens a PR** (`gh pr create`, title `TASK-<id>: <title>`), records `PR: #<n>` on the task,
  and moves the task to `Review` (never `Done`, never a `main` push, never a self-merge).
- **The reviewer loop is the only merger, and it merges via the PR** (`gh pr merge --merge`),
  only after a passing review with CI green. On a fail it comments on the PR + task and bounces
  the task back to `To Do` (see `### Comment as you work`). It never merges a PR whose
  `implemented-by` is itself (reviewer ≠ implementer, decision-7).
- **A GitHub ruleset enforces this** ("main merge gate: PR + green CI"): merging to `main`
  requires a PR with required checks `analyze`, `coverage-gate`, `apk-build`, `native-tests`
  green **and CodeQL code-scanning results with no high+ security / error-level alerts**
  (decision-11 — the CodeQL workflow `.github/workflows/codeql.yml` scans the `android/`
  Kotlin + workflow files; Dart is not CodeQL-supported and is covered by our own checks
  instead); merge-commit method only;
  no force-push or deletion of `main`. Repository admins carry
  an `always` bypass **solely** so backlog claim/status/bookkeeping commits can go straight to
  `main` — using it to merge a PR (`gh pr merge --admin`) or push task code to `main` is
  forbidden. If a merge is refused, CI isn't green: fix that, never bypass.

**Straight-to-`main` is only for non-task bookkeeping** — task claim/status commits, the loops'
own review artifacts (follow-up tickets, quality-check markers), backlog/decision/config edits,
and trivial docs. These aren't feature work and carry no `Review` gate. See the memory
`git-workflow` and `backlog/decisions/` (6, 7, 8, 10).

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
   bump the `ci.yml` floor so the gain is locked in. (UI-only screens are covered by the
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
it works, just slightly slower to spin up. (Source: friction:tooling, TASK-155.)

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
