---
id: TASK-144
title: Rescue-carb and ketone alerts must bypass quiet hours
status: To Do
assignee: []
created_date: '2026-07-06 08:41'
labels:
  - code-health
  - alerts
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 144000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `bypassesQuietHours` (`lib/insights/notification_prefs.dart:156-162`) contains only `urgentLow`, `predictedLow`, `pumpAlarm`; the acute "take rescue carbs NOW" alert (fired only when a real hypo is present, `lib/state/providers.dart:1494-1505`) and the ketone/DKA alert (`:1570-1578`) are muted overnight while the predicted urgent low is not — the safety ordering is inverted.

**Reason for change.** The two most acute alerts in the app can be silenced by quiet hours while a mere prediction cannot; overnight is exactly when they matter most.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `rescueCarb` and `ketoneCheck` bypass quiet hours
- [ ] #2 A test asserts every acute urgent/high-importance category either bypasses quiet hours or is explicitly excluded with a comment
- [ ] #3 The user guide notification table is updated
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

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
