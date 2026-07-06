---
id: TASK-106
title: Extract onboarding gate logic; typed accessors for app flags
status: Done
assignee: []
created_date: '2026-07-06 04:54'
updated_date: '2026-07-06 09:09'
labels:
  - code-health
  - architecture
  - onboarding
milestone: m-8
dependencies: []
priority: medium
ordinal: 106000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The onboarding advance decision (`pumpReady` / `lastStepSatisfied` / `canAdvance`) is pure boolean logic buried in a widget `build()` (`lib/ui/onboarding_screen.dart:72-83`). Three app-lifecycle flags are persisted with raw magic string keys straight to `SharedPreferences` from UI code, bypassing KvStore entirely:

- `dev_mode` — written in onboarding_screen.dart:151,168, main_shell.dart:46, settings_screen.dart:130; read in main.dart:21
- `pump_paired` — written in onboarding_screen.dart:67, app.dart:52; read in onboarding_screen.dart:47
- `onboarding_done` — written in app.dart:98; read in main.dart:20

**Reason for change.** First-run gating is a correctness path with zero tests, and untyped keys duplicated across six files invite typo/desync bugs. Adjacent to but distinct from the planned KvStore DI seam (TASK-36) — coordinate so the new accessors sit behind that seam when it lands.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Pure onboarding-gate function extracted and unit-tested (each step satisfied/unsatisfied, pump-ready matrix)
- [x] #2 The three flags are read/written via typed accessors with const key names defined once
- [x] #3 No raw flag-key string literals remain in lib/ui/, lib/app.dart or lib/main.dart
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Extract `OnboardingGate` (pure) from onboarding_screen build(); unit-test it.
- Add a small `app_flags.dart` (const keys + typed read/write helpers or providers).
- Migrate the six files; grep to confirm no stray literals.
- Coordinate naming with TASK-36 so the helpers take the KeyValueStore interface when it exists.
- `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (lib finding 5)
- Effort: S–M
- Related: TASK-36 (KvStore behind the DI seam)

Implemented: (1) lib/onboarding/onboarding_gate.dart — pure OnboardingGate (pumpReady/lastStepSatisfied/canAdvance) extracted from OnboardingScreen.build(); unit-tested in test/onboarding_gate_logic_test.dart (pump-ready matrix, per-page advance, last-step). Kept the existing widget regression test (test/onboarding_gate_test.dart) untouched. (2) lib/state/app_flags.dart — AppFlags wraps SharedPreferences with const keys (kDevMode/kPumpPaired/kOnboardingDone) + typed getters/setters; documented as the swap point for the TASK-36 KvStore seam. (3) Migrated all six sites (onboarding_screen, main_shell, settings_screen, main, app x2); grep confirms zero raw 'dev_mode'/'pump_paired'/'onboarding_done' literals remain in lib/ui, lib/app.dart, lib/main.dart. analyze clean, 516 tests green, debug APK builds.
<!-- SECTION:NOTES:END -->
