---
id: TASK-250
title: 'Hostile-input corpus must assert output invariants, not just absence of throw'
status: Done
assignee:
  - Claude
created_date: '2026-07-07 14:28'
updated_date: '2026-07-07 20:42'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 152000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
In hostile_input_corpus_test.dart the PumpSnapshot and SavedMeal cases are expect with an inner try/catch that swallows any throw, so the outer closure always returns normally. The assertion passes if the parser throws, passes if it returns garbage, and can only fail on a hard isolate crash. PumpSnapshot.fromJson does no clamping, so a hostile batteryPercent -81 or reservoirUnits 1.79e308 produces a nonsensical snapshot that flows into the app unchecked. The TherapySegment block in the same file is the correct pattern: it asserts isf greater than 0 and carbRatio greater than 0 on success. The other targets should likewise assert output invariants or a clean rejection.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 PumpSnapshot and SavedMeal corpus cases assert either a clean rejection or a safe clamped output invariant, not merely returnsNormally
- [x] #2 No corpus case swallows the exception and then asserts on the swallowing closure
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-193)
- File: test/hostile_input_corpus_test.dart PumpSnapshot and SavedMeal blocks
- Model the fix on the TherapySegment block already in the file
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 20:32
---
Started: fix the PumpSnapshot/SavedMeal hostile-input corpus cases to assert real output invariants, matching the TherapySegment block's already-correct pattern.
---

author: Claude
created: 2026-07-07 20:42
---
Done -- and caught a real bug in my OWN first draft of this fix along the way. Full breakdown:

Production clamps added (needed so there's something genuine to assert, since neither PumpSnapshot.fromJson nor SavedMeal.fromJson threw for the ticket's own hostile examples -- battery -81/reservoir 1.79e308 parsed to garbage, they didn't reject):
- lib/pump/pump_snapshot.dart: batteryPercent clamped to [0,100], reservoirUnits/iobUnits clamped to [0,1000] (NaN treated as absent).
- lib/meals/meal_library.dart: carbsGrams/fatGrams/proteinGrams clamped to [0,2000], absorptionMinutes/peakOffsetMinutes clamped to [1,600]/[1,300].

Test restructuring (AC#1/#2): test/hostile_input_corpus_test.dart's PumpSnapshot and SavedMeal blocks now separate the fallible PARSE (try/catch -- a throw is a clean rejection, acceptable) from the invariant ASSERTION, which runs OUTSIDE the catch.

Found while verifying: my FIRST draft still wrapped 'parse + assert' in the SAME try/catch (assertSane(PumpSnapshot.fromJson(...)) inside one try) -- an expect() failure is itself a thrown exception, so that shared catch silently swallowed genuine invariant violations, which is the EXACT bug this ticket exists to fix, just relocated. Caught this by deliberately breaking the production clamps and rerunning -- the test suite stayed all-green, which shouldn't have happened. Restructured to parse-then-null-check-then-assert (separate steps, no shared catch) and reran with the clamps broken again -- this time 4 PumpSnapshot + 10 SavedMeal tests correctly failed with the exact garbage values (9223372036854775807, -61, etc.), then passed again once the real fix was restored. Also fixed the pre-existing TherapySegment block (the ticket's own 'correct pattern' reference) which had the identical latent structural issue, even though its invariant happens to always hold today so it wasn't otherwise caught.

Pipeline: flutter analyze clean, flutter test test/ 1040/1040, flutter build apk --debug succeeded. No native Kotlin, no user-visible change (defensive clamps).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
