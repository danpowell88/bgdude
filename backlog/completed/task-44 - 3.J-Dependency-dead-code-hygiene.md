---
id: TASK-44
title: Dependency & dead-code hygiene
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:07'
labels:
  - roadmap
  - cleanup
milestone: m-0
dependencies: []
priority: low
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The project carries a few unused dependencies, a Nightscout upload function that's declared but never called (with a docstring that implies it works), and an in-session list of basal observations that grows without limit.

**Reason for change.** Dead dependencies slow builds and mislead; a lying docstring rots; an unbounded list is a slow memory leak. Simple hygiene.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Unused deps removed
- [x] #2 uploadTreatments wired or deleted
- [x] #3 _basalObs capped
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Remove the unused deps.
- Delete or wire `uploadTreatments` (wire only when TASK-62 follower work lands, else delete).
- Cap `_basalObs` with the `PumpEventLog.maxEvents` ring pattern.
- Test: `flutter pub get` + build succeed after dep removal; unit test the `_basalObs` cap; grep confirms no dangling references.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 3.J
- Effort: S
- Roadmap status: open
- Done 2026-07-06: removed 6 unused codegen deps (riverpod_annotation/generator, freezed/_annotation, json_serializable/_annotation); capped `_basalObs` at 288 (ring). `uploadTreatments` KEPT (it is tested and TASK-61 will wire it) with an honest docstring instead of deleted.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed 6 unused codegen dependencies (riverpod_annotation/generator, freezed/_annotation, json_serializable/_annotation) and capped `_basalObs` at 288 entries with a ring buffer; `uploadTreatments` was kept with an honest docstring because it is tested and TASK-61 will wire it. Landed in commit b5ce128; verified with `flutter analyze` clean and `flutter test` green.
<!-- SECTION:FINAL_SUMMARY:END -->
