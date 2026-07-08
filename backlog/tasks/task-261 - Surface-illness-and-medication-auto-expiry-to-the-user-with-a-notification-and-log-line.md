---
id: TASK-261
title: >-
  Surface illness and medication auto-expiry to the user with a notification and
  log line
status: In Progress
assignee:
  - Claude
created_date: '2026-07-07 16:27'
updated_date: '2026-07-08 10:16'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 535000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When a 7-day illness or 14-day medication mode auto-expires via checkModeExpiry, the resistance overlay (up to about 1.5x, confidence floored at 0.7) silently switches off and dosing hints shift, with no notification and no log line. The app DOES notify on illness auto-detection, so silent auto-expiry is inconsistent: a user who relied on the elevated hints gets no signal that they reverted. Medication expiry additionally produces no annotation at all (MedicationMode has no annotation concept even on manual stop), so those days are untagged for retraining.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Illness and medication auto-expiry emit a user-facing notification (or at minimum a persisted log line) noting the mode ended and hints reverted
- [x] #2 Behaviour is consistent with the auto-detection notification path
- [x] #3 Confirm whether medication-mode days should be annotated for retraining like illness days; wire it or record the decision
<!-- AC:END -->



## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-197)
- File: lib/state/providers.dart checkModeExpiry ~1910, illness ~1030, medication ~1104
- Related: TASK-258 (illness annotation never persisted)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 10:16
---
Started: mirror the illness auto-detection notification path (NotificationCategory.modeExpired) onto both deactivateIfExpired() call sites; only auto-expiry notifies, manual deactivate()/stop() doesn't since the user already knows. AC#3: decided to wire full annotation support for MedicationMode (previously had none, even on manual stop), exactly mirroring illness mode's TASK-258 pattern rather than treating this as detail-needed -- the pattern was directly analogous and already established.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [x] #8 backlog item updated with comments
<!-- DOD:END -->
