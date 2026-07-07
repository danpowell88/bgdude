---
id: TASK-41
title: Architecture guard test (+ read-only-pump check)
status: Done
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-07 10:43'
labels:
  - roadmap
  - architecture
  - testing
  - "\U0001F512 safety"
  - detail-needed
milestone: m-0
dependencies: []
priority: high
ordinal: 100200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude has a layering rule: screens may use plain data types from anywhere, but must not reach directly into the app's services or storage. Two screens currently break that rule, and the "the app never sends write/control commands to the pump" promise is only enforced by discipline, not by any check.

**Reason for change.** A tiny automated test can enforce both the layering rule and the read-only-pump guarantee, turning "we promise" into "the build fails if anyone breaks it".
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 architecture_test.dart walks lib/ui/** imports and fails on interface/store/service imports
- [x] #2 Existing violations fixed (meal_library_screen, protocol_explorer_screen)
- [x] #3 Build fails if any Kotlin imports request.control
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `test/architecture_test.dart` (~30 lines) walking `lib/ui/**` imports: UI may import value/DTO types from any layer, never interfaces/stores/services.
- Fix the two current violations (`meal_library_screen`, `protocol_explorer_screen`).
- In the same test, fail the build if any Kotlin file imports `request.control`.
- Sanity-check the guard: the test fails on a deliberately-added bad import and on a deliberately-added `request.control` import; passes once violations are fixed.
- Add/extend unit tests under `test/`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 3.G
- Effort: S
- Flags: 🔒 safety
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:24
---
detail-needed (2026-07-06, goal triage): The guard test itself is easy, but fixing the existing violation protocol_explorer_screen→PumpSource (an interface import) needs a provider-routing redesign of the probe API — want the approach confirmed so the read-only Explorer keeps working.
---

author: Claude
created: 2026-07-07 10:43
---
Done: test/architecture_test.dart walks lib/ui/**.dart source for imports against a denylist of interface/service/storage files (pump_source.dart, pump_client.dart, simulated_pump_client.dart, kv_store.dart, database.dart, history_repository.dart, notifications.dart) and separately scans android Kotlin sources for any import of com.jwoglom.pumpx2...request.control.* (verified that's the real pumpx2 write/control package via javap on the cached jar). Each guard has a sanity test proving it actually flags a bad import. Fixed both existing violations: protocol_explorer_screen.dart imported PumpSource directly — added a ProtocolProbeController facade in providers.dart (setCapture/send) so the screen only ever sees a plain controller; meal_library_screen.dart called KvStore.getBool/setBool directly for the one-time online-lookup notice — added a OneTimeNotices facade in providers.dart. Pipeline green: analyze clean, 750 tests passed (5 new architecture_test.dart tests), apk debug build succeeds.
---
<!-- COMMENTS:END -->
