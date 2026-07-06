---
id: TASK-112
title: 'Garmin: shared background-app base + draw helpers in source-common'
status: To Do
assignee: []
created_date: '2026-07-06 04:56'
updated_date: '2026-07-06 08:08'
labels:
  - code-health
  - garmin
  - cleanup
milestone: m-8
dependencies: []
priority: low
ordinal: 112000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `BgDudeWatchFaceApp.mc` and `BgDudeDataFieldApp.mc` are identical except the class name and the getInitialView() return type — onStart, onStop, getServiceDelegate and onBackgroundData are duplicated verbatim (confirmed by diff). The three Views (BgDudeView, BgDudeWatchFaceView, BgDudeDataFieldView) each re-derive the same stale-colour selection (stale then DK_GRAY else BgData.bgColor()) and the value+arrow centering width math.

**Reason for change.** A fix to background-registration logic currently has to be applied twice; the colour/centering snippet three times. source-common/BgData.mc already proves the barrel pattern works here.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A BgBackgroundApp base in source-common provides onStart/onStop/getServiceDelegate/onBackgroundData; both apps extend it and only supply their view
- [ ] #2 valueColorFor(stale) and a drawValueWithArrow(...) helper live in BgData (or a sibling); the three Views use them
- [ ] #3 All 3 products still build and run in the simulator; garmin/tools/run_tests passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add the base class to source-common (it is on every product jungle path).
- Collapse the two App files; extract the draw helpers.
- Build all 3 products in the sim; run the Garmin unit tests.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (test finding 5)
- Effort: S–M
- Where: garmin/source-watchface/BgDudeWatchFaceApp.mc, garmin/source-datafield/BgDudeDataFieldApp.mc, the 3 View files
<!-- SECTION:NOTES:END -->
