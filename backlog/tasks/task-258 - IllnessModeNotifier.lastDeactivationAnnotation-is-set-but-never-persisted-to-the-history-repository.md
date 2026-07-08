---
id: TASK-258
title: >-
  IllnessModeNotifier.lastDeactivationAnnotation is set but never persisted to
  the history repository
status: Done
assignee:
  - Claude
created_date: '2026-07-07 16:00'
updated_date: '2026-07-08 05:51'
labels:
  - dosing-math
milestone: m-8
dependencies: []
priority: medium
ordinal: 705200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** \`IllnessModeNotifier.deactivate()\` and the new \`deactivateIfExpired()\` (TASK-197) both set \`lastDeactivationAnnotation\` from \`IllnessModeController.deactivate()\`'s returned \`Annotation\` (an \`AnnotationKind.illness\` annotation spanning the sick period, per \`illness_mode.dart\`'s own doc comment: "so the retraining pipeline tags (rather than mislearns) those days"). Nothing in the codebase ever reads \`lastDeactivationAnnotation\` — a repo-wide search finds only the two write sites, no \`ref.listen\`, no call site that reads the field and saves it via \`historyRepository.saveAnnotation(...)\`.

**Reason for change.** The annotation this mechanism exists to produce is built and then dropped on the floor every time illness mode ends (manually or via auto-expiry) — every sick-day period since this feature landed has silently NOT been tagged for the retraining pipeline, meaning sick days are mislearned as normal glucose behaviour exactly as the original design intended to prevent.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [x] #8 backlog item updated with comments
<!-- DOD:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 16:00
---
Source: discovered while implementing TASK-197 (illness/medication mode auto-expiry) -- grepped the whole repo for lastDeactivationAnnotation and found only the two write sites in providers.dart, no reader anywhere.
---

author: Claude
created: 2026-07-07 16:27
---
Recent-code review 2026-07-08 (TASK-197): note that restart_recovery_test.dart:163 asserts expect(lastDeactivationAnnotation, isNotNull), which only proves the field was set, not that the annotation reached the history repository. AC number 2 here already targets the real fix; flagging that the existing assertion is mild false confidence and should be replaced/augmented by the repository-presence assertion, not kept alongside it as if it were coverage.
---

author: Claude
created: 2026-07-08 05:27
---
Recent-code review 2026-07-08 (verifying TASK-260): when you wire lastDeactivationAnnotation to actually persist to the history repository, also handle the persist-FAILURE case. Today TASK-260 reverts _controller.mode on a failed deactivate() write but does NOT revert lastDeactivationAnnotation (set at providers.dart:1146), so the field holds an annotation for a deactivation that never persisted. Harmless now (no live reader), but once this ticket makes the field authoritative it would record a sick-day-ended annotation the mode never actually made -- so set/save the annotation only after the mode change persists, or revert it in the same catch that reverts _controller.mode.
---

author: Claude
created: 2026-07-08 05:40
---
Started: wiring IllnessModeNotifier.lastDeactivationAnnotation to actually save into the history repository, and handling the persist-failure interaction flagged in comment #3 (don't record/save an annotation for a mode change that never persisted).
---

author: Claude
created: 2026-07-08 05:51
---
Done. lastDeactivationAnnotation is now saved via HistoryRepository.saveAnnotation in IllnessModeNotifier._persist, once the mode change it belongs to has actually persisted (constructor now takes an optional HistoryRepository, wired from historyRepositoryProvider). On a failed persist write, the annotation field is cleared alongside the controller-mode revert (comment #3), so a deactivation that never stuck cannot later ride along on some unrelated successful persist. Two new tests in test/persisted_state_corruption_test.dart cover the save-on-success and clear-on-failure paths; restart_recovery_test.dart TASK-197 case now asserts the annotation actually lands in the repository (sim.repo.annotations(...)) instead of only checking the transient field. Both new-logic paths rigor-checked (temp-bug reintroduced, confirmed the exact test failure, reverted). No existing reader of the field was found (AC3) -- this was genuinely dead output before this change. Full pipeline green: analyze clean, 1185 tests pass, coverage 67.92% (floor 65%), flutter build apk --debug succeeds. No native Kotlin touched, no user-visible UI change, no new screen/flow -- DoD 5/6/7 not applicable.
---
<!-- COMMENTS:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A caller (a Riverpod ref.listen, or the notifier itself) saves lastDeactivationAnnotation into the history repository via saveAnnotation when it's set
- [x] #2 A regression test: deactivating (manually or via auto-expiry) results in the annotation actually present in the repository, not just held in a field
- [x] #3 Confirm no existing annotation-save path already covers this (e.g. a UI screen reading the field) before assuming it's fully missing
<!-- AC:END -->
