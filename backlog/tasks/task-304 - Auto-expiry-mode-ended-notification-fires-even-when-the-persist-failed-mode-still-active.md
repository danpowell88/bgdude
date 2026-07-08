---
id: TASK-304
title: >-
  Auto-expiry mode-ended notification fires even when the persist failed (mode
  still active)
status: Done
assignee:
  - Claude
created_date: '2026-07-08 10:25'
updated_date: '2026-07-08 10:50'
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
- [x] #1 The mode-ended notification for illness AND medication fires only after the deactivation persists successfully (await the persist and gate the notification on its result), so a failed write emits no mode-ended notification
- [x] #2 A single expiry notifies at most once (a failed-then-retried persist does not double-notify)
- [x] #3 MedicationMode.fromJson guards active against a null startedAt (mirror IllnessMode.fromJson) so the auto-expiry annotation path cannot null-deref startedAt!
- [x] #4 Tests assert the notification does NOT fire on a failed persist (both modes) and that a corrupt active+startedAt-null medication blob decodes safely
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 verifying the TASK-261 fix (f484fcc)
- Files: lib/state/providers.dart illness :1199-1211 (unawaited persist + unconditional notify), medication :1367-1378 (awaited persist, unchecked notify); lib/insights/medication_mode.dart:89 fromJson active/startedAt guard
- Same persist-before-emit lesson as TASK-258 (annotation) / TASK-260 (state reconcile); TASK-261 applied it to the annotation but not the notification
- Safety: a false mode-ended / hints-reverted signal while the mode is still active misleads dosing decisions
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 10:39
---
Started: confirmed real regression -- illness deactivateIfExpired doesn't even await _persist before notifying, medication's awaits but doesn't check the result. Plan: gate both notifications on a successful persist (have _persist report success/failure), guard against double-notify on the next tick, fix MedicationMode.fromJson's active/startedAt null-guard to mirror IllnessMode.fromJson.
---

author: Claude
created: 2026-07-08 10:50
---
Done: gated both IllnessModeNotifier.deactivateIfExpired and MedicationModeNotifier.deactivateIfExpired's mode-ended notification on _persist actually succeeding -- _persist (both classes) now returns Future<bool>, and the notification only fires when true. Illness's persist call was previously not even awaited (fire-and-forget), now awaited; checkModeExpiry now awaits illness's call too (was fire-and-forget there as well) for consistent ordering. AC#2 (no double-notify): once the persist-gating is correct, a failed attempt notifies zero times and a subsequent successful retry notifies exactly once -- no separate latch needed; the underlying controllers already return null/no-op once a mode is genuinely inactive, so a second successful call can't re-fire. AC#3: MedicationMode.fromJson now guards active against a null startedAt exactly like IllnessMode.fromJson (active: json.active && startedAt != null), so a corrupt active+startedAt-null blob decodes inactive instead of later null-deref'ing in _buildAnnotation's startedAt!. Tests added to test/integrations/persisted_state_corruption_test.dart: 'auto-expiry notification is gated on a successful persist (TASK-304)' group (illness + medication, using the established KvStore-seed-expired-mode + unopenable-DB pattern) asserting no notification fires and the mode stays active on a failed write; plus a MedicationMode.fromJson decode test for the corrupt active+null-startedAt case. Rigor-checked all three fixes (temp-bug + revert each): forcing the notification unconditional again made both new failed-persist tests fail with the predicted 'Actual: [NotificationCategory.modeExpired]' symptom; reverting the fromJson guard made the decode test fail with 'Expected: false, Actual: true'. All reverts confirmed clean via git diff. A pre-existing no_wall_clock_guard_test caught two bare DateTime.now() calls in the new tests (auto-fixed by an editing hook with a now-ok justification comment) -- worth noting since it demonstrates that guard test doing its job. Full pipeline green: analyze clean, 1359 tests passing, coverage 68.80% (floor 65%), apk build succeeded. No native Kotlin changed; no screen/flow changed so no integration test addition.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [x] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [x] #9 backlog item updated with comments
<!-- DOD:END -->
