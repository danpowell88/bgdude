---
id: TASK-144
title: Rescue-carb and ketone alerts must bypass quiet hours
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:41'
updated_date: '2026-07-06 21:58'
labels:
  - code-health
  - alerts
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 100600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `bypassesQuietHours` (`lib/insights/notification_prefs.dart:156-162`) contains only `urgentLow`, `predictedLow`, `pumpAlarm`; the acute "take rescue carbs NOW" alert (fired only when a real hypo is present, `lib/state/providers.dart:1494-1505`) and the ketone/DKA alert (`:1570-1578`) are muted overnight while the predicted urgent low is not — the safety ordering is inverted.

**Reason for change.** The two most acute alerts in the app can be silenced by quiet hours while a mere prediction cannot; overnight is exactly when they matter most.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `rescueCarb` and `ketoneCheck` bypass quiet hours
- [x] #2 A test asserts every acute urgent/high-importance category either bypasses quiet hours or is explicitly excluded with a comment
- [x] #3 The user guide notification table is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `rescueCarb` and `ketoneCheck` to `bypassesQuietHours`.
- Add a test enumerating acute categories: each bypasses or carries an explicit exclusion comment.
- Update the notification table in `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/insights/notification_prefs.dart:156-162`)
- Effort: S
- Where: `lib/insights/notification_prefs.dart`, `doc/user-guide.html`
- Related: TASK-93
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 21:55
---
Started: add rescueCarb + ketoneCheck to bypassesQuietHours, add an acute-category guard test, update the user-guide notification table.
---

author: Claude
created: 2026-07-06 21:58
---
Done (commit 2e00bca). DoD 5/7 vacuous (no native change, notifications behavior covered by unit tests; the Notifications screen itself is unchanged).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
rescueCarb and ketoneCheck added to bypassesQuietHours (lib/insights/notification_prefs.dart) with the reviewed exclusions documented in the extension comment (missedBolus: retrospective nudge; preBolusTimer: user-initiated, not fired asleep). Guard test enumerates every high/urgent-default category and fails if a new acute category is quiet-hours-muted without a reviewed exclusion; plus explicit bypass/muted assertions. User guide quiet-hours paragraph + notification table (dagger marks) updated. Verified: analyze clean, 617 tests green, debug APK builds. Commit 2e00bca.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
