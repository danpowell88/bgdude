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
- Preserve the `<!-- SECTION:…:BEGIN/END -->` markers; write content only between them.
- When passing multi-line text to the CLI, include real newlines inside the quoted string
  (or edit the task file directly). Never write literal `\n`.
- Wrap code identifiers/paths in backticks so they don't italicise (underscores).

## Git
Commit directly to `main` (no feature branches) and push to `main` when a remote exists.
See the memory `git-workflow`.

## Verify before committing
`flutter analyze` clean, `flutter test` green, and — when native Kotlin changed —
`cd android && ./gradlew :app:testDebugUnitTest`. Native code is buildable/testable here
(JDK + Android SDK present); verify pumpx2 APIs via `javap` on the cached jar before writing.

## Emulator (integration) tests for every feature
Every user-facing screen/flow should have on-device coverage under `integration_test/`
(shared helpers in `integration_test/harness.dart`; run in demo mode). When you add or
change a screen, panel, mode, report, or setting, add/extend an integration test so it's
exercised on a device. Run: `flutter test integration_test/<file>.dart -d <device-id>`
(an emulator, e.g. `emulator-5554`, is available). The `screenshots_test.dart` /
`walkthrough_test.dart` files need `flutter drive`, so run the functional `*_test.dart`
files explicitly rather than the whole folder.
