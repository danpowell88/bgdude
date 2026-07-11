---
name: integration-test-harness
description: Add or run bgdude's on-device (emulator) integration tests under integration_test/. Use when you add or change a screen, panel, mode, report, or setting — every user-facing flow should have on-device coverage. Covers the shared demo-mode harness, running a single file on an emulator, and the flutter drive files. Note the emulator VM-service can be flaky in some sandboxes.
---

# Emulator (integration) tests for every feature

Every user-facing screen/flow should have on-device coverage under `integration_test/`.
Shared helpers live in `integration_test/harness.dart` and run the app in **demo mode**
(a simulated t:slim + CGM, so every screen renders without a real pump). When you add or
change a screen, panel, mode, report, or setting, add or extend an integration test so it's
exercised on a device.

## Running
```
flutter test integration_test/<file>.dart -d <device-id>
```
An emulator (e.g. `emulator-5554`) is used. Run the functional `*_test.dart` files
**explicitly** — the `screenshots_test.dart` / `walkthrough_test.dart` files need
`flutter drive`, so don't run the whole folder at once.

## Harness usage (`integration_test/harness.dart`)
- It is **not** a test file (no `_test.dart` suffix), so the runner won't execute it.
- Call `setUpDemoHarness()` from each test file's `setUp()` — it resets the process-global
  `KvStore` in-memory fallback so app flags/prefs don't leak across `testWidgets` blocks in
  the same process.
- To assert on a thrown error, use `WidgetTester.takeException()` (flutter_test's supported
  mechanism) — do **not** try to install your own `FlutterError.onError` in `setUp`; the test
  binding installs its own and overrides yours for the test body.

## Unit vs integration
UI screens (`lib/ui/**`) are covered here, on a device — not by unit tests. Don't chase their
unit-coverage lines (see the `coverage-ratchet` skill). Logic/data code is unit-tested under
`test/`.

## Environment caveat
In some sandboxed sessions the emulator integration run fails with a VM-service WebSocket
error that is pre-existing and not test-specific. If you hit it, note it rather than treating
it as a regression in your change.
