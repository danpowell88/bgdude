---
id: TASK-191
title: Fix unsafe empty-iterable operations (meter transport firstWhere)
status: Done
assignee:
  - Claude
created_date: '2026-07-06 12:56'
updated_date: '2026-07-07 13:16'
labels:
  - code-health
  - cleanup
milestone: m-8
dependencies: []
priority: medium
ordinal: 108800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/integrations/glucose_meter_transport_fbp.dart:90` calls `services.firstWhere(...)` with no `orElse` — pairing against a BLE device that lacks the Glucose service throws an uncaught `StateError` mid-connect. Audit of the other `.reduce(`/`.first` sites shows most are guarded (`alert_monitor.dart:47` checks isEmpty; `predictor.dart:33-35` ternary) but the sweep should confirm each remaining site.

**Reason for change.** A user pairing the wrong device should get a clean "not a glucose meter" failure, not a crash.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 firstWhere has orElse and the connect flow surfaces a clean incompatible-device error
- [x] #2 Remaining reduce/first/single sites in lib/ audited; each unguarded one fixed or proven unreachable-empty with a comment
- [x] #3 Test: service list without Glucose service → typed failure, no throw
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Fix the transport site with orElse + typed error.
- Grep-audit the ~10 remaining sites; fix or annotate.
- Add the wrong-device unit test.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep 2026-07-06 (verified: one unguarded firstWhere)
- Effort: S
- Where: lib/integrations/glucose_meter_transport_fbp.dart:90 + audited sites
- Related: TASK-30 (meter field test)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 13:16
---
Done. AC#1: the firstWhere at glucose_meter_transport_fbp.dart:90 already had an orElse throwing a StateError, and glucose_meter_controller.dart's _friendly(e) already string-matches 'No Glucose Service' into a clean 'That device isn't a standard glucose meter.' message — confirmed with a new end-to-end test (test/glucose_meter_controller_test.dart) using a fake transport, rather than assuming the prior audit's 'no orElse' claim still held. AC#2: delegated a full lib/-wide grep audit (86 reduce/first/firstWhere/single/last call sites) to a research pass; 85 were already safe (isEmpty/length guards, provably-non-empty-by-construction collections, or caller-side minExamples floors) and one real gap was found: TherapySettings.fromJson built  from persisted/external JSON with no non-emptiness check, so a structurally-valid-but-empty 'segments': [] from a corrupted KV blob would decode silently and crash every segmentAt() call (bolus advisor, rescue-carb advice, alert cycle, reading explainer) via sorted.first with no guard. Fixed: fromJson now falls back to TherapySettings.placeholder().segments when the parsed list is empty, matching the same sanitize-corrupt-data pattern from TASK-190. AC#3: both the wrong-device test and a TherapySettings empty-segments regression test added (test/therapy_settings_test.dart). Pipeline green: analyze clean, 774 tests passed, apk debug build succeeds.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
