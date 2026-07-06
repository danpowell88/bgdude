---
id: TASK-7
title: P0-7 Ketone/DKA prompt earlier
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
labels:
  - roadmap
  - §1-P0
  - phase-0
  - "\U0001F512 safety"
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
- [ ] #1 Base threshold 250 mg/dL
- [ ] #2 Unconditional prompt >~300 rising / very-low IOB
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** In ketone_risk.dart:21 lower the base threshold to 250 mg/dL and add an unconditional prompt above ~300 mg/dL when rising or with very-low IOB.

**Testing.** Unit tests across (BG, trend, IOB) combinations: prompt fires at 250 base and unconditionally >~300 rising / very-low IOB. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able). `flutter analyze` clean and `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P0-7
Effort: S
Where: ketone_risk.dart:21
Flags: 🔒 safety
Roadmap status: open
<!-- SECTION:NOTES:END -->
