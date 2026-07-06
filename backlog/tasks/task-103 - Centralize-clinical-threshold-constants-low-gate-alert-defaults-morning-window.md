---
id: TASK-103
title: >-
  Centralize clinical threshold constants (low gate, alert defaults, morning
  window)
status: To Do
assignee: []
created_date: '2026-07-06 04:53'
labels:
  - code-health
  - cleanup
  - "\U0001F512 safety"
dependencies: []
priority: medium
ordinal: 103000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `core/units.dart` has a good `GlucoseThresholds` class, but several clinical gates live outside it:

- `lib/insights/reading_explainer.dart:111` defines a private `_lowGateMgdl = 80` (deliberately different from `GlucoseThresholds.low = 70`, but defined privately)
- `lib/insights/alert_thresholds.dart:9-11,33-35` writes the defaults `70/200/55` twice — once in the constructor, once in `fromJson`
- `lib/insights/background_summary.dart:31,45` embeds the morning-window hours `6/11/7` as bare literals

**Reason for change.** Clinical thresholds should be auditable from one place. Duplicated defaults can silently drift between the constructor and `fromJson`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Low-gate and alert defaults live in (or beside) GlucoseThresholds as named consts with doc comments explaining any deliberate difference
- [ ] #2 AlertThresholds constructor and fromJson reference the same static consts
- [ ] #3 No behavioural change: flutter test green with no test edits other than imports
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add named consts (e.g. `GlucoseThresholds.explainerLowGate`, `AlertThresholds.defaultLow/High/UrgentLow`) with one-line rationale comments.
- Point the explainer, the constructor and `fromJson` at them; move the morning-window hours to named consts in background_summary.
- `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (lib finding 10)
- Effort: S
- Where: reading_explainer.dart:111, alert_thresholds.dart:9-11+33-35, background_summary.dart:31+45
<!-- SECTION:NOTES:END -->
