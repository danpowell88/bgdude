---
id: TASK-7
title: Ketone/DKA prompt earlier
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:07'
labels:
  - roadmap
  - "\U0001F512 safety"
milestone: m-0
dependencies: []
priority: high
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** When insulin is missing (for example an occluded infusion site), glucose stays high and the body produces "ketones", which can progress to diabetic ketoacidosis (DKA) — a medical emergency. bgdude has a ketone/DKA prompt, but its trigger sits too high, so it can stay silent during an early DKA setup (a persistent high with little insulin on board).

**Reason for change.** DKA is the highest-stakes failure this app touches. Prompting earlier — to check ketones and act — is a clear safety improvement.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Base threshold 250 mg/dL
- [x] #2 Unconditional prompt >~300 rising / very-low IOB
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- In `ketone_risk.dart:21` lower the base threshold to 250 mg/dL.
- Add an unconditional prompt above ~300 mg/dL when rising or with very-low IOB.
- Unit tests across (BG, trend, IOB) combinations: prompt fires at 250 base and unconditionally >~300 rising / very-low IOB. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able).
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1, P0-7
- Effort: S
- Where: `ketone_risk.dart:21`
- Flags: 🔒 safety
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ketone/DKA prompt in `ketone_risk.dart` now uses a 250 mg/dL base threshold and fires unconditionally above ~300 mg/dL when rising or with very-low IOB. Landed in commit 5c974df (P0 dosing-math fixes) with unit tests across BG/trend/IOB combinations; `flutter analyze` clean and `flutter test` green.
<!-- SECTION:FINAL_SUMMARY:END -->
