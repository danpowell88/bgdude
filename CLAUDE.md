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

## Git
Commit directly to `main` (no feature branches) and push to `main` when a remote exists.
See the memory `git-workflow`.

## Verify before committing
`flutter analyze` clean, `flutter test` green, and — when native Kotlin changed —
`cd android && ./gradlew :app:testDebugUnitTest`. Native code is buildable/testable here
(JDK + Android SDK present); verify pumpx2 APIs via `javap` on the cached jar before writing.
