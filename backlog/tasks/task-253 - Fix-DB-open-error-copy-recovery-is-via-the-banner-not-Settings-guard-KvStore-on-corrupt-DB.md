---
id: TASK-253
title: >-
  Fix DB-open error copy: recovery is via the banner not Settings; guard KvStore
  on corrupt DB
status: Done
assignee:
  - Claude
created_date: '2026-07-07 14:29'
updated_date: '2026-07-08 03:34'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 165000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The startup error banner text in main.dart tells users to open Settings to reset storage or export what is readable, but DbRecoveryScreen is reachable ONLY by tapping the banner in main_shell.dart and there is no Settings entry (none in settings_screen.dart). The instruction points at a nonexistent path and contradicts the user guide which says tap the banner. Separately, on a corruptedData verdict openDb is non-null so KvStore.init runs against a DB whose quick_check just failed: history goes in-memory which is safe, but app settings keep reading and writing the corrupt on-disk DB the recovery screen is about to delete.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Error copy matches the real recovery path (tap the banner) or a Settings entry is added and the copy points to it
- [x] #2 Banner affordance makes clear it is tappable
- [x] #3 KvStore is not initialised against a DB that failed its integrity check on the corruptedData verdict
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-192)
- Files: lib/main.dart, lib/ui/main_shell.dart, lib/ui/settings_screen.dart
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 03:30
---
Started: fixing the wrong 'open Settings' error copy (recovery is banner-tap only), making the banner's tappability clearer, and guarding KvStore.init from running against a DB that just failed its corruptedData integrity check.
---

author: Claude
created: 2026-07-08 03:34
---
Fixed all three:

AC#1 (wrong copy): lib/main.dart's _dbOpenErrorMessage -- 'open Settings to reset storage' / 'open Settings to export...' / 'open Settings and retry' all changed to 'tap this banner to...', matching the real (and only) recovery path. Confirmed doc/user-guide.html was ALREADY correct ('Tap the banner for the recovery screen') -- it was main.dart's copy that had drifted, not the guide, so no doc update needed.

AC#2 (tappability affordance): the message text itself now says 'tap this banner' directly -- the clearest possible signal, on top of the existing chevron_right icon + InkWell ripple main_shell.dart already had for db-error banners. No further UI change needed.

AC#3 (KvStore guard): lib/main.dart's  ran unconditionally, including on a corruptedData verdict where openDb is intentionally kept open for salvage export -- meaning app settings would read/write against a DB that just failed PRAGMA quick_check, the exact file DbRecoveryScreen is about to offer resetting. Narrowed to  -- only the fully-clean, quick_check-passed case initialises KvStore against the real DB. KvStore's own doc comment already anticipated this ('or a DB that failed to open' falls back to an in-memory map), so the fallback path was already safe and tested, just not reached on corruptedData before.

No new unit/integration test added -- main.dart's boot sequence (_run()) isn't unit-testable without a broader DI refactor out of this ticket's scope, and this doesn't add/change a screen or flow (same banner, same DbRecoveryScreen), so DoD#8 doesn't apply.

Verified: flutter analyze clean, flutter test --coverage green (1158 tests, 67.58% >= 65% floor), flutter build apk --debug succeeds. No native Kotlin touched.
---

author: Claude
created: 2026-07-08 03:34
---
Correction to comment #2: two code snippets were silently eaten by bash backtick command-substitution. AC#3 detail in full: lib/main.dart line 70 was "if (openDb != null) KvStore.init(openDb)" -- ran unconditionally. Changed to "if (openDb != null and dbOpenDiagnosis == null) KvStore.init(openDb)" so only the fully-clean, quick_check-passed case initialises KvStore against the real DB file.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
