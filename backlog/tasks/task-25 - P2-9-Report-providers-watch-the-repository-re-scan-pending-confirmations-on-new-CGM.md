---
id: TASK-25
title: >-
  P2-9 Report providers watch the repository; re-scan pending confirmations on
  new CGM
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 05:25'
labels:
  - roadmap
  - §1-P2
  - architecture
dependencies: []
priority: low
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude has a "demo mode" that runs on simulated data without touching your real records. The report screens don't re-read the data source when you flip demo mode on/off, and they don't re-scan for newly-detected events when a fresh glucose reading arrives.

**Reason for change.** So switching between demo and real data shows stale reports until you restart the app, and freshly-detected events aren't offered for you to confirm promptly.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Report providers ref.watch the repository so a demo-mode toggle rebuilds them
- [x] #2 Pending confirmations re-scanned when a new CGM value arrives
- [x] #3 Switching demo<->real shows correct data without an app restart
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Make the report providers `ref.watch` the repository so a demo-mode toggle rebuilds them.
- Trigger a pending-confirmation re-scan on each new CGM sample.
- Provider test: demo-real toggle rebuilds reports; a new CGM value re-scans pending confirmations.
- Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able).
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §1 P2-9
- Effort: S
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
In `lib/state/providers.dart`, report/journal providers now `ref.watch(historyRepositoryProvider)` instead of `ref.read`, so a demo-mode toggle rebuilds the reports without an app restart; `pendingConfirmationsProvider` watches the CGM timestamp via `select` so it re-scans when a new reading lands without re-scanning on same-snapshot IOB ticks. Verified: analyze clean, full suite of 460 tests green (commit f895b68).
<!-- SECTION:FINAL_SUMMARY:END -->
