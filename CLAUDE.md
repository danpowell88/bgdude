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

## Agent skills
Reusable, on-demand skills live in `.claude/skills/` and load automatically when relevant —
see `.claude/skills/README.md`. Bespoke ones encode this repo's knowledge: `verify-build`
(the CI-equivalent pipeline — the exact steps behind "Verify the build" below),
`coverage-ratchet`, `drift-sqlcipher`, and `pumpx2-native-bridge` (the read-only pump
charter). Vendored ones cover general tooling: `github` (gh CLI), the official `flutter-*`
set, and `android-cli`. Keep them current as the code evolves.

## GitHub Issues (task tracking — the single planning source)
All planning lives in **GitHub Issues** on `danpowell88/bgdude` (CLI: `gh`).

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

### Comment as you work
All agents share one GitHub account, so **every comment starts with your agent id**:
`gh issue comment 42 --body "<agent-id>: Started — <approach in one line>"`. The
`implemented-by:` / `reviewed-by:` tags and comment signatures are the greppable record of
who did what (`in:comments` search) — keep both present on every issue that reaches Reviewed.
- While working: comment any **significant finding, decision, or deviation** from the plan
  (what and why) — not a play-by-play, just what a reviewer would want to know.
- When you **finish the implementation**: first `git merge origin/main` into the branch then
  confirm code + tests + the full verify pipeline green on the branch. Tick the AC
  checkboxes (body edit), push and open a PR
  If a PR for the branch already exists (rework after a failed review), just push — the PR
  updates itself; leave a PR comment saying what changed. Add the `- **PR:** #<pr>` bullet to
  the issue body, add a closing comment tagged
  `implemented-by: <your-agent-id> — branch issue-<n>, PR #<pr>, <files, tests, commit hash>`.
  **This closing comment MUST end with a friction line** — a `friction:<category> — …` bullet
  for anything that tripped you up (build/env/deps/code/test/tooling), or literally
  `friction:none` if it was genuinely smooth.
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

## Git
**Concurrent sessions isolate via worktrees + branches — ALL work, no exceptions.** When more
than one session/agent writes to this repo at once each works in its **own git worktree on its own short-lived
branch off `main`** — this is what prevents two sessions racing on one working tree (the "file
modified since read" / manually-scoped-commit problem). 

**Task work ships as a GitHub PR and reaches `main` only via a reviewed, CI-green PR merge
(decision-10).** Do NOT push task work straight to `main`. Concretely:
- One branch per issue with a descriptive name of hte issue number and fix,

## Verify the build after EVERY task (must match CI — CI is the source of truth)
The GitHub Actions workflow (`.github/workflows/ci.yml`) is what decides if `main` is
green, and **it must never be left red**. `flutter analyze` + `flutter test` passing is
**not sufficient** — CI also generates code and builds the APK, so a change can be
"green locally" yet break CI. After finishing any task (and before committing), run the
**same pipeline CI runs, in this order**, and only commit when it all passes — the exact
steps are in the `verify-build` skill (`.claude/skills/verify-build/`).

If any step fails, fix it before committing — do not push a change that would turn CI
red. If CI is already red on `main`, treat getting it green as part of the current task.
Native code is buildable/testable here (JDK + Android SDK present); verify pumpx2 APIs via
`javap` on the cached jar before writing.

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

## Emulator (integration) tests for every feature
Every user-facing screen/flow should have on-device coverage under `integration_test/`
(shared helpers in `integration_test/harness.dart`; run in demo mode). When you add or
change a screen, panel, mode, report, or setting, add/extend an integration test so it's
exercised on a device. Run: `flutter test integration_test/<file>.dart -d <device-id>`
(an emulator, e.g. `emulator-5554`, is available). The `screenshots_test.dart` /
`walkthrough_test.dart` files need `flutter drive`, so run the functional `*_test.dart`
files explicitly rather than the whole folder.
