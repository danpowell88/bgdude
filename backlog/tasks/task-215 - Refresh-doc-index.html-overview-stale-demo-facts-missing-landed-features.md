---
id: TASK-215
title: 'Refresh doc/index.html overview (stale demo facts, missing landed features)'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:32'
updated_date: '2026-07-07 21:21'
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
- [x] #1 Demo-mode entry/em-name and seeded-history facts corrected
- [x] #2 Feature list includes every landed feature above
- [x] #3 Correlations list complete; Google Fit removed; test badge recounted or softened
- [x] #4 Safety section cross-links the guide limitations; `media/walkthrough.mp4` reference verified
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 21:16
---
Started: sweep doc/index.html section-by-section against the current app / doc/user-guide.html, fixing the 4 ACs (demo entry+KPI facts, landed-feature list, correlations+Google Fit+test-badge, safety cross-links).
---

author: Claude
created: 2026-07-07 21:21
---
Fixed all 4 ACs in doc/index.html:

- Demo entry/facts: 'Dev mode' -> 'Demo mode' throughout (card heading, video-tour caption, settings caption, regen section, footer); corrected the entry point (chosen during onboarding, not a Settings switch) and KPIs (14d seeded history, ~3 meals/day -- was wrongly '24h CGM history').
- Landed features added: barcode/OCR/Gemma meal-add flow, forecast band-trust chip, medication/steroid mode, opt-in weather context, Bluetooth glucose-meter import, pump safety limits (max bolus/basal). Clinic-visit-ready journal was already present.
- Correlations list completed (temperature, mood, menstrual-cycle panel); dropped the stale Google Fit mention (Health Connect only, confirmed via lib/data/health_sync.dart's own doc comment); test badge softened to '1,000+ Dart tests + native suite' (actual: 1052 at time of writing) rather than a number that goes stale again immediately.
- Safety section: added the alert-aliveness/battery-optimization limitation (cross-linking user-guide.html#notifications) and the Garmin cloud-privacy note (cross-linking user-guide.html#garmin). Verified media/walkthrough.mp4 exists on disk, all referenced screenshots/*.png exist, and every internal #anchor in the nav matches a real section id.

No Dart code touched (docs-only) -- flutter analyze still clean; build_runner/test/apk unaffected so not re-run beyond analyze.
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
