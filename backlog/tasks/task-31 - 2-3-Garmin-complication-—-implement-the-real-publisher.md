---
id: TASK-31
title: Garmin complication — implement the real publisher
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-07 13:01'
labels:
  - roadmap
  - garmin
  - "\U0001F50C hardware"
  - detail-needed
milestone: m-4
dependencies: []
priority: medium
ordinal: 500300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** A Garmin "complication" is a small element you can place on a watch face (like the little date or steps readouts). bgdude's Garmin apps run in the simulator, but the complication publisher was mis-built and removed, so BG can't yet appear on the watch face itself.

**Reason for change.** A complication puts your glucose on the watch face you already glance at — the highest-value Garmin surface. It needs the real publisher, gated to watches that support complications.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Resource-defined complication + updateComplication
- [ ] #2 Gated on has :Complications
- [ ] #3 Verified on a real watch
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Implement the real publisher: resource-defined complication + `updateComplication`.
- Gate on `has :Complications`.
- On-watch test: complication shows BG and updates; falls back cleanly on devices lacking `:Complications`.
- On-device (hardware): prepare a build + an exact manual test procedure → run on the real device → report → fix.
- Verify: desk tests still green — `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 2 item 2-3
- Effort: M
- Where: garmin/COMPLICATIONS.md
- Flags: 🔌 hardware
- Roadmap status: partial
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 13:01
---
detail-needed (2026-07-07): researched the publisher-side API precisely rather than guessing at native code I can't test end-to-end. Confirmed via developer.garmin.com/connect-iq/api-docs/Toybox/Complications.html: the actual publish call is Complications.updateComplication(index as Number, data as Complications.Data), where Data has shortLabel/value/unit/ranges — call it from source-common whenever BG updates, gated on 'Toybox.Complications has :Complications' (matches the existing code comment in BgDudeWatchFaceApp.mc: 'on 4.1.0+ watches, also read as a published complication'). What's NOT yet verified: the exact resource-XML schema for DECLARING the complication (id/type) that the manifest/resources need before 'index' in updateComplication means anything — I could not find this in the locally-installed SDK's debug symbol dump (which only records symbols from previously-compiled projects, not a full API reference) nor a clear worked example in the official garmin/connectiq-apps sample repo (no complications sample folder there) or the API docs page fetched. Writing the resource XML from memory risks a complication that silently fails to register, which — needing a real watch for AC#3 anyway — I couldn't catch locally. Recommend either finding a working sample project to pattern-match against, or scoping a first real-hardware session to iterate on the resource definition directly. Left In Progress.
---
<!-- COMMENTS:END -->
