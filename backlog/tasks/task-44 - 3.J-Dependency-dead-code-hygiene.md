---
id: TASK-44
title: 3.J Dependency & dead-code hygiene
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 04:28'
labels:
  - roadmap
  - §3
  - phase-0
  - cleanup
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
- [ ] #1 Unused deps removed
- [ ] #2 uploadTreatments wired or deleted
- [ ] #3 _basalObs capped
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Remove the unused deps; delete or wire uploadTreatments (wire only when §4-3 follower work lands, else delete); cap _basalObs with the PumpEventLog.maxEvents ring pattern.

**Testing.** `flutter pub get` + build succeed after dep removal; unit test the _basalObs cap; grep confirms no dangling references. Add/extend unit tests under `test/`. `flutter analyze` clean, `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §3.J
- Effort: S
- Roadmap status: open

- Done 2026-07-06: removed 6 unused codegen deps (riverpod_annotation/generator, freezed/_annotation, json_serializable/_annotation); capped _basalObs at 288 (ring). uploadTreatments KEPT (it's tested and TASK-61 will wire it) with an honest docstring instead of deleted.
<!-- SECTION:NOTES:END -->
