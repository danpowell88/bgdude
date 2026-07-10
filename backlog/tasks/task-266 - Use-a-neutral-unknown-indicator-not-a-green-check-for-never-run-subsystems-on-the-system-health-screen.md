---
id: TASK-266
title: >-
  Use a neutral unknown indicator not a green check for never-run subsystems on
  the system-health screen
status: Review
assignee:
  - Claude
created_date: '2026-07-07 17:30'
updated_date: '2026-07-10 12:20'
status: Needs Review
assignee:
  - Claude
created_date: '2026-07-07 17:30'
updated_date: '2026-07-10 14:03'
labels: []
milestone: m-8
dependencies: []
priority: low
ordinal: 720000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
On the system-health screen, when lastAttemptAt is null the subtitle says Never run yet but isUnhealthy is false, so the leading icon is a green check_circle_outline. Same for the Garmin Not available (demo mode) and no-send-attempted states. On a fresh install, or in demo mode where syncHealth is disabled, the screen is a wall of green checkmarks for subsystems that have never actually run. A green tick communicates healthy/verified, not unknown, which is false reassurance.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Never-run and not-available states render a neutral/unknown indicator distinct from the healthy green check
- [x] #2 Demo mode does not present unrun subsystems as healthy
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-201)
- File: lib/ui/system_health_screen.dart:57,60,69 and the Garmin tile :118
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-10 12:08
---
branch: task-266
---

author: Claude
created: 2026-07-10 12:20
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- code complete and pushed to branch task-266 (commit f827a69).
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- code complete and pushed to branch task-266 (commit 22c4c88).

Added a neutral (grey help_outline) state to both _SubsystemTile and _GarminTile in lib/ui/system_health_screen.dart, checked before unhealthy/stale: _SubsystemTile keys off health.lastAttemptAt==null (mirrors the existing 'Never run yet' subtitle logic); _GarminTile keys off lastSuccessMs==null && !unhealthy, which covers both the 'not available' (health==null, e.g. demo mode) and 'no send attempted yet this session' cases the ticket calls out -- both render the same neutral state. A real recorded failure still wins (red), matching the existing unhealthy-over-stale priority rule.

Tests: 5 new cases in test/ui/system_health_screen_test.dart (never-run subsystem shows neutral not green; only the row that actually succeeded turns green while the rest stay neutral; both Garmin neutral variants; a real Garmin failure still reads red not neutral). Rigor-checked by reverting each neverRun computation in turn (both the subsystem and Garmin one separately) and confirming the corresponding new tests fail with the exact predicted symptom, then restoring and confirming full green. Extended the existing System-health integration test (demo mode never runs the model-download subsystem) to assert its icon is neutral, not the green check.

flutter analyze clean, flutter test --coverage green (1371 tests), coverage 68.81% (floor 65%), flutter build apk --debug succeeded. doc/user-guide.html updated (System health bullet under Model internals).

friction:test -- SystemHealthScreen's ListView(children:...) doesn't build every row in a small widget-test surface (test viewport is far shorter than a real device) -- a Card+ListTile past the visible fold (the 5th/6th subsystem, and the Garmin tile after the Divider) is simply absent from find.* results until scrolled into view, even though ListView(children:...) is not a lazy builder. Cost ~20 min of debugging (a debug test dumping every Text widget) before recognizing it as a viewport/scroll issue rather than a real rendering bug. Also: the Garmin tile's title text ('Garmin watch delivery') collides with the Subsystem.garminDelivery _SubsystemTile's label -- same string, two different rows -- so find.text(...) alone is ambiguous; used .last to disambiguate (the _GarminTile is always painted after the Divider).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [x] #7 Integration test added or extended when a screen/flow changed
- [x] #8 backlog item updated with comments
<!-- DOD:END -->
