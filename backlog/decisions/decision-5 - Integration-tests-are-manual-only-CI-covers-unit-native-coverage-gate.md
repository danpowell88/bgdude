---
id: decision-5
title: Integration tests are manual-only; CI covers unit + native + coverage gate
date: '2026-07-06 22:11'
status: accepted
---
## Context

TASK-159: CI ran the native Kotlin tests with `continue-on-error: true` (so the
read-only-pump guard `ProtocolProbeTest` could go red while main stayed green), had no
coverage measurement, and never executed `integration_test/`. The suite needs an Android
emulator; GitHub-hosted emulator jobs are slow (~10+ min) and flaky, and this is a
personal single-user project (decision-2) where every feature is exercised on a real
device/emulator locally anyway (CLAUDE.md mandates on-device integration tests per
feature).

## Decision

- Native Kotlin unit tests are **blocking** in CI, with `local.properties` written
  deterministically before Gradle runs.
- CI measures line coverage (`flutter test --coverage test/`) and **fails below 60%**
  (a floor, not a target — raise it as coverage grows; 63.1% when introduced).
- `integration_test/` stays **manual-only**: run locally against an emulator per
  CLAUDE.md before/after feature work. No scheduled emulator job in CI.

## Consequences

- A red native suite or a coverage collapse now turns main red — fix before merging.
- The coverage threshold lives in `.github/workflows/ci.yml` (Coverage gate step) and
  should be ratcheted up deliberately, never down without revisiting this decision.
- Integration-test regressions are caught locally, not by CI; keep running them when
  screens/flows change (CLAUDE.md workflow).

