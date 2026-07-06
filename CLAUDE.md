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

## Backlog (task tracking)
Actionable work is tracked with [Backlog.md](https://github.com/MrLesk/Backlog.md) under
`backlog/tasks/` (CLI: `backlog`, e.g. `backlog task list --plain`, `backlog task 42 --plain`).
`ROADMAP.md` stays the strategic narrative; tasks are the unit of execution.

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

### Comment as you work
Use the **comment field** to leave a trail on the task you're working on:

```
backlog task edit 42 --comment "Started: <approach in one line>" --comment-author "Claude"
```

- When you **start** a task: set `-s "In Progress"` and add a comment stating the approach.
- While working: add a comment for any **significant finding, decision, or deviation** from
  the implementation plan (what and why) — not a play-by-play, just the things a reviewer
  would want to know.
- When you **finish**: check off the acceptance criteria (`--check-ac <n>`), set
  `-s Done`, and add a closing comment summarising what changed (files, tests, commit hash).

### `detail-needed` label
If a task lacks the information needed to implement it properly (unclear requirement,
missing decision, unknown validation data, ambiguous acceptance criterion), **do not guess**:

```
backlog task edit 42 --add-label detail-needed --comment "detail-needed: <the specific questions>" --comment-author "Claude"
```

State the concrete questions in the comment, leave the task in its current status, and move
on. (`needs-exploration` is the related pre-existing label for tasks that were known to be
under-scoped at creation; `detail-needed` is for gaps you discover.)

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

## Git
Commit directly to `main` (no feature branches) and push to `main` when a remote exists.
See the memory `git-workflow`.

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
4. `flutter test test/` — green (this is the scope CI uses; the `integration_test/` suite
   needs an emulator and is separate).
5. `flutter build apk --debug` — **required**: this catches Android/Gradle/manifest
   breakage that analyze and unit tests miss. Do not skip it.
6. When native Kotlin changed: `cd android && ./gradlew :app:testDebugUnitTest`.

If any step fails, fix it before committing — do not push a change that would turn CI
red. If CI is already red on `main`, treat getting it green as part of the current task.
Native code is buildable/testable here (JDK + Android SDK present); verify pumpx2 APIs via
`javap` on the cached jar before writing.

## Emulator (integration) tests for every feature
Every user-facing screen/flow should have on-device coverage under `integration_test/`
(shared helpers in `integration_test/harness.dart`; run in demo mode). When you add or
change a screen, panel, mode, report, or setting, add/extend an integration test so it's
exercised on a device. Run: `flutter test integration_test/<file>.dart -d <device-id>`
(an emulator, e.g. `emulator-5554`, is available). The `screenshots_test.dart` /
`walkthrough_test.dart` files need `flutter drive`, so run the functional `*_test.dart`
files explicitly rather than the whole folder.
