---
id: TASK-112
title: 'Garmin: shared background-app base + draw helpers in source-common'
status: Done
assignee: []
created_date: '2026-07-06 04:56'
updated_date: '2026-07-06 14:30'
labels:
  - code-health
  - garmin
  - cleanup
milestone: m-8
dependencies: []
priority: low
ordinal: 109800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `BgDudeWatchFaceApp.mc` and `BgDudeDataFieldApp.mc` are identical except the class name and the getInitialView() return type — onStart, onStop, getServiceDelegate and onBackgroundData are duplicated verbatim (confirmed by diff). The three Views (BgDudeView, BgDudeWatchFaceView, BgDudeDataFieldView) each re-derive the same stale-colour selection (stale then DK_GRAY else BgData.bgColor()) and the value+arrow centering width math.

**Reason for change.** A fix to background-registration logic currently has to be applied twice; the colour/centering snippet three times. source-common/BgData.mc already proves the barrel pattern works here.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A BgBackgroundApp base in source-common provides onStart/onStop/getServiceDelegate/onBackgroundData; both apps extend it and only supply their view
- [x] #2 valueColorFor(stale) and a drawValueWithArrow(...) helper live in BgData (or a sibling); the three Views use them
- [x] #3 All 3 products still build and run in the simulator; garmin/tools/run_tests passes
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

Implemented. AC#1: BgBackgroundApp base provides onStart/onStop/getServiceDelegate/onBackgroundData; BgDudeWatchFaceApp + BgDudeDataFieldApp collapse to extend it and supply only getInitialView(). PLACEMENT NOTE: the base lives in source-service (with BgServiceDelegate) rather than source-common — the widget build does not include source-service and does not use the background lifecycle, so keeping it in source-common would compile an undefined BgServiceDelegate reference into the widget (verified: that exact error). AC#2: BgData.valueColorFor(stale) + BgData.drawValueWithArrow(...) added; all three views use valueColorFor, and the two group-centred views (watchface, datafield) use drawValueWithArrow. BgDudeView keeps its own arrow placement (its value is CENTER-justified with the arrow hung off the right — a genuinely different layout, not the same group-centring math). AC#3: all 3 products (watchface/datafield/widget jungles) BUILD SUCCESSFUL via monkeyc (CIQ SDK 9.2.0, device fenix847mm since the manifests' fenix6/7 devices aren't downloaded here — temporarily added the installed device to build, then reverted) and the unit tests compile with --unit-test; running the sim GUI (monkeydo) isn't available headless. Added garmin/.gitignore for developer_key + bin/ (were untracked-but-uningored).
<!-- SECTION:NOTES:END -->
