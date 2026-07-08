---
id: TASK-304
title: >-
  Auto-expiry mode-ended notification fires even when the persist failed (mode
  still active)
status: To Do
assignee:
  - Claude
created_date: '2026-07-08 10:25'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 119500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-261 correctly gates the deactivation ANNOTATION behind a successful persist (saved inside _persist after the write lands, cleared on the catch), reusing the TASK-258/260 lesson. But the mode-ended NOTIFICATION is not gated the same way -- it fires unconditionally. Illness deactivateIfExpired (providers.dart:1204-1210): unawaited(_persist()) then unawaited(_notificationService.show(modeExpired, Illness mode ended, dosing hints reverted to normal)) -- persist is not even awaited, so the notification fires regardless of the write result; on failure _persist reverts _controller.mode to the still-active value, so illness mode stays active and boosted while the user is told it ended. Medication deactivateIfExpired (providers.dart:1373-1378): await _persist(previous) reverts state to active on failure, then show(Medication mode ended) fires with no success check. Concrete: KvStore write throws during auto-expiry (the exact fault the annotation edge test injects) -> mode stays active, dosing still boosted, annotation not saved, but the user gets dosing hints have reverted to normal -- a misleading, safety-relevant false signal that contradicts the commits own persist-before-emit invariant. Secondary: after the failed persist the mode is active again, so the next watchdog tick re-expires and notifies a SECOND time (violates no-double-notify). The notification persist-failure edge is untested (the failed-write tests assert only annotation-not-saved + state-active, never that the notification did not fire). Separately (LOW): MedicationMode.fromJson does not guard active against a null startedAt (unlike IllnessMode.fromJson), so a corrupt active+expired+startedAt-null value reaches deactivateIfExpired -> _buildAnnotation -> startedAt! and throws -- a latent null-deref asymmetry in the auto-expiry path.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The mode-ended notification for illness AND medication fires only after the deactivation persists successfully (await the persist and gate the notification on its result), so a failed write emits no mode-ended notification
- [ ] #2 A single expiry notifies at most once (a failed-then-retried persist does not double-notify)
- [ ] #3 MedicationMode.fromJson guards active against a null startedAt (mirror IllnessMode.fromJson) so the auto-expiry annotation path cannot null-deref startedAt!
- [ ] #4 Tests assert the notification does NOT fire on a failed persist (both modes) and that a corrupt active+startedAt-null medication blob decodes safely
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 verifying the TASK-261 fix (f484fcc)
- Files: lib/state/providers.dart illness :1199-1211 (unawaited persist + unconditional notify), medication :1367-1378 (awaited persist, unchecked notify); lib/insights/medication_mode.dart:89 fromJson active/startedAt guard
- Same persist-before-emit lesson as TASK-258 (annotation) / TASK-260 (state reconcile); TASK-261 applied it to the annotation but not the notification
- Safety: a false mode-ended / hints-reverted signal while the mode is still active misleads dosing decisions
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
