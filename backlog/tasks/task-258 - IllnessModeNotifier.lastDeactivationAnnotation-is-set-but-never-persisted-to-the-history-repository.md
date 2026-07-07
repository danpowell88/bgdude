---
id: TASK-258
title: >-
  IllnessModeNotifier.lastDeactivationAnnotation is set but never persisted to
  the history repository
status: To Do
assignee: []
created_date: '2026-07-07 16:00'
updated_date: '2026-07-07 16:00'
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
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 16:00
---
Source: discovered while implementing TASK-197 (illness/medication mode auto-expiry) -- grepped the whole repo for lastDeactivationAnnotation and found only the two write sites in providers.dart, no reader anywhere.
---
<!-- COMMENTS:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A caller (a Riverpod ref.listen, or the notifier itself) saves lastDeactivationAnnotation into the history repository via saveAnnotation when it's set
- [ ] #2 A regression test: deactivating (manually or via auto-expiry) results in the annotation actually present in the repository, not just held in a field
- [ ] #3 Confirm no existing annotation-save path already covers this (e.g. a UI screen reading the field) before assuming it's fully missing
<!-- AC:END -->
