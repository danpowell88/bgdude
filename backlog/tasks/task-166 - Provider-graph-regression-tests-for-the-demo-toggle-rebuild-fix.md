---
id: TASK-166
title: Provider-graph regression tests for the demo-toggle rebuild fix
status: To Do
assignee: []
created_date: '2026-07-06 09:15'
labels:
  - code-health
  - testing
milestone: m-8
dependencies: []
priority: medium
ordinal: 166000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Commit f895b68 (P2-9) changed only `lib/state/providers.dart` — report providers now watch the repository and confirmations re-scan on new CGM — with no test; `pendingConfirmationsProvider` is referenced by zero tests, so the fix trivially reverts to `ref.read` with nothing failing.

**Reason for change.** The rebuild fix is unguarded; a regression would silently freeze reports and the confirmation inbox after a demo toggle.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ProviderContainer test: override the repo, read a report, swap the repo override, assert the report value changes
- [ ] #2 Test: a new CGM timestamp re-scans pending confirmations while an IOB-only snapshot change does not
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Build a ProviderContainer harness that overrides the repository provider.
- Test 1: read a report provider, swap the repo override, assert the report value changes (guards `ref.watch` vs `ref.read`).
- Test 2: push a snapshot with a new CGM timestamp and assert `pendingConfirmationsProvider` re-scans; push an IOB-only change and assert it does not.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 4)
- Effort: M
- Where: `lib/state/providers.dart`, new test under `test/`
- Related: TASK-25 (the fix under pin)
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
