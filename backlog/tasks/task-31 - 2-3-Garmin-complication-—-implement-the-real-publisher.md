---
id: TASK-31
title: Garmin complication — implement the real publisher
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-07 22:02'
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

author: Claude
created: 2026-07-07 22:02
---
detail-needed: ground-truthed the Complications API against the installed Connect IQ SDK (9.2.0) before writing any code (per CLAUDE.md's pumpx2/javap convention, applied here too) -- verified real signatures in doc/Toybox/Complications.html, bin/resources.xsd and bin/projectInfo.xml rather than trusting garmin/COMPLICATIONS.md's own prior analysis (which turned out to ALSO be wrong on one point, see below).

Confirmed workable: Complications.updateComplication(index, data) where data is a plain Dictionary literal {:value, :shortLabel, :unit, :ranges} (NOT 'new Complications.Data(...)' as COMPLICATIONS.md speculated -- Data is a structural typedef, not a class). Resource schema (resources.xsd complicationType): id/access/icon/longLabel required, shortLabel/glancePreview/units/value/range/faceIt all optional -- private access needs no SVG icon (only public/protected do) and no faceIt element, so the existing PNG launcher icon would work.

BLOCKING new finding: bin/projectInfo.xml's permissionMap shows ComplicationPublisher is valid ONLY for appType="watch-app" and "audio-content-provider-app" -- NOT "widget", which is what garmin/manifest.xml's BgDudeApp actually is. COMPLICATIONS.md's own claim ('Publishing is only valid for app/widget product types') is wrong on this specific point. This means AC#1/#2 can't be added to the existing widget at all -- publishing a complication requires standing up a BRAND NEW Connect IQ product with type="watch-app" (its own UUID, its own manifest/jungle, its own visible entry view since watch-apps aren't headless like widgets, its own phone-message wiring duplicating BgDudeApp's, and a corresponding new UUID registered in GarminSender.kt on the Android side) -- not a small addition to the current widget.

Questions for a decision before implementing: (1) is a 4th Garmin product (a new watch-app, appearing separately in the watch's app list) worth it just to publish glucose as a complication for third-party faces, given the watch face already surfaces BG prominently (per COMPLICATIONS.md's own closing rationale for why this was deferred)? (2) if yes, what UUID/name should the new watch-app use? Leaving AC#1-3 unchecked and not guessing at a new product's scope/UUID without that decision.
---
<!-- COMMENTS:END -->
