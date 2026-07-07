---
id: TASK-166
title: Provider-graph regression tests for the demo-toggle rebuild fix
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:15'
updated_date: '2026-07-07 04:33'
labels:
  - code-health
  - testing
milestone: m-8
dependencies: []
priority: medium
ordinal: 107200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Commit f895b68 (P2-9) changed only `lib/state/providers.dart` — report providers now watch the repository and confirmations re-scan on new CGM — with no test; `pendingConfirmationsProvider` is referenced by zero tests, so the fix trivially reverts to `ref.read` with nothing failing.

**Reason for change.** The rebuild fix is unguarded; a regression would silently freeze reports and the confirmation inbox after a demo toggle.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ProviderContainer test: override the repo, read a report, swap the repo override, assert the report value changes
- [x] #2 Test: a new CGM timestamp re-scans pending confirmations while an IOB-only snapshot change does not
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 04:31
---
Started: ProviderContainer harness — repo-swap test guards report ref.watch; snapshot cgmTime-vs-IOB-only test guards the pendingConfirmations select.
---

author: Claude
created: 2026-07-07 04:33
---
Done.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
New test/provider_graph_test.dart: (1) ProviderContainer overrides historyRepositoryProvider, reads glucoseReportProvider, swaps the override via updateOverrides and asserts the report changes — a ref.read regression fails it; (2) a _CountingRepository + overridden pumpSnapshotProvider stream prove a new cgmTime triggers a confirmation re-scan while a same-cgmTime IOB-only snapshot does not (guards the .select). Verified: analyze clean, 729 tests green, APK builds.
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
