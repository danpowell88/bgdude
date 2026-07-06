---
id: TASK-215
title: 'Refresh doc/index.html overview (stale demo facts, missing landed features)'
status: To Do
assignee: []
created_date: '2026-07-06 21:32'
labels:
  - docs
  - cleanup
milestone: m-8
dependencies: []
priority: medium
ordinal: 112900
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The marketing/overview page has drifted ~two dozen feature commits behind the app, while `doc/user-guide.html` is current. Verified drift:

- Demo entry is wrong: index says Settings → Dev mode (`index.html:157,481`); the app has no Settings switch — demo is entered in onboarding, labelled Demo mode, Settings shows status + Exit (`settings_screen.dart:115-137`)
- Demo KPI stale: advertises 24h CGM history + 3 meals (`index.html:161-164`); demo seeds ~14 days (`demo_history.dart:45-50`)
- Landed features absent from the feature list: Bluetooth glucose-meter import, weather context/heat-aware alerts, medication/steroid mode, barcode + OCR/Gemma label scanning, forecast band-trust chip, pump safety limits, clinic-visit prep report
- Correlations understated (`index.html:512`): missing ambient temperature, mood, menstrual-cycle panel
- Google Fit mentioned (`index.html:241`) — Health Connect only; drop it
- Test-count badge 243 (`index.html:105`) stale (~570)
- Safety section lacks the alert-aliveness limitation + Garmin cloud-privacy cross-links the guide carries

**Reason for change.** The overview is the landing page of the now-live Pages site (danpowell88.github.io/bgdude); it must not misdescribe the app.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Demo-mode entry/em-name and seeded-history facts corrected
- [ ] #2 Feature list includes every landed feature above
- [ ] #3 Correlations list complete; Google Fit removed; test badge recounted or softened
- [ ] #4 Safety section cross-links the guide limitations; `media/walkthrough.mp4` reference verified
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Sweep section by section against the user guide (which is current) rather than the code.
- Regenerate screenshots only if a referenced one is missing.
- Verify: pages render locally; internal anchors resolve.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: docs sweep 2026-07-06 (user-doc audit ticket 1)
- Effort: M
- Where: doc/index.html
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
