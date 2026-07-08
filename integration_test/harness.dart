/// Shared helpers for the on-device (emulator) integration suite. Boots the real app in
/// demo mode so every screen renders against the simulated t:slim + CGM, and provides
/// small navigation helpers used across the feature tests.
///
/// Not a test file itself (no `_test.dart` suffix), so the runner won't execute it.
library;

import 'dart:ui';

import 'package:bgdude/app.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/logging/app_log.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-257: `pumpDemoApp` calls `tester.pumpWidget` directly, bypassing
/// `main()` entirely -- so none of its crash-capture wiring (`FlutterError.onError`,
/// `PlatformDispatcher.instance.onError`, `runZonedGuarded`) is ever installed, and any
/// integration test asserting on `appLog`'s `crash` tag (e.g. the chaos walk) was
/// checking a log nothing could ever populate. Chains (does not replace) whatever
/// handler `IntegrationTestWidgetsFlutterBinding` already installed, so the test
/// framework's own error reporting is unaffected -- this only ADDS the same
/// `appLog.error('crash', ...)` recording `main.dart`'s `_captureCrash` does.
/// Installed once per process (guarded), not per test, since `FlutterError.onError`/
/// `PlatformDispatcher.instance.onError` are process-global statics -- re-wrapping on
/// every `testWidgets` block in a multi-test file would chain handlers ever deeper.
bool _crashCaptureInstalled = false;
void _installCrashCapture() {
  if (_crashCaptureInstalled) return;
  _crashCaptureInstalled = true;
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    previousOnError?.call(details);
    appLog.error('crash', '[FlutterError] ${details.exception}');
  };
  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    appLog.error('crash', '[PlatformDispatcher] $error');
    return previousPlatformOnError?.call(error, stack) ?? true;
  };
}

/// TASK-220: call from each integration test file's `setUp()`. The process-global
/// `KvStore` in-memory fallback otherwise leaks app flags/prefs across `testWidgets`
/// blocks that share the same file/process. TASK-257: also installs crash capture
/// (once) and clears `appLog` so an earlier `testWidgets` block's entries in the same
/// file/process can't leak into a later one's crash-log assertion.
void setUpDemoHarness() {
  KvStore.useMemory();
  _installCrashCapture();
  appLog.clear();
}

/// TASK-220: unmounts the app widget tree (rather than relying on the *next* test's
/// `pumpWidget` to do it) so a dev-mode `SimulatedPumpClient`'s 30 s re-emit ticker
/// is reliably cancelled before the next test starts. [pumpDemoApp] registers this
/// automatically via `tester.addTearDown` -- a `WidgetTester` isn't available in a
/// plain top-level `tearDown()`, so every call site gets cleanup for free rather than
/// needing to remember to wire it up individually.
Future<void> tearDownDemoHarness(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

/// Boot the app (demo mode by default) and let the first simulated reading land.
///
/// [fixedNow] threads a fixed clock into the demo seam (TASK-220): both the
/// simulated pump feed and the seeded demo history repository read it instead of
/// the wall clock, so a displayed-value assertion is stable across runs and
/// wall-clock time-of-day. Omit it to get the old "live" behaviour.
Future<void> pumpDemoApp(
  WidgetTester tester, {
  bool onboarded = true,
  bool devMode = true,
  String? dbOpenError,
  DateTime? fixedNow,
}) async {
  addTearDown(() => tearDownDemoHarness(tester));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(NotificationService()),
        onboardingDoneProvider.overrideWith((ref) => onboarded),
        devModeProvider.overrideWith((ref) => devMode),
        dbOpenErrorProvider.overrideWithValue(dbOpenError),
        if (fixedNow != null)
          demoClockProvider.overrideWithValue(() => fixedNow),
      ],
      child: const BgDudeApp(),
    ),
  );
  await tester.pumpAndSettle();
  if (devMode) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }
}

/// Open the Settings screen from the tab shell's top bar.
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

/// TASK-234/235: `scrollUntilVisible` alone stops as soon as a tile's EDGE enters
/// the viewport, so `tap()`'s center hit-test can miss (a `warnIfMissed` warning
/// in the failure log, and the expected screen never opens) -- `ensureVisible`
/// brings the whole tile fully on-screen first. Takes a [Finder] (not a label
/// string) so it works for any tile, not just ones found by exact text.
Future<void> tapListTile(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scroll the current (Settings/hub) list until [label] is visible, then tap it.
/// TASK-279: was its own scrollUntilVisible-then-tap (the same tap-miss gap
/// TASK-234 diagnosed for Diagnostics log) -- now just [tapListTile] by label.
Future<void> tapListItem(WidgetTester tester, String label) =>
    tapListTile(tester, find.text(label));

/// Open Settings, then navigate into the sub-screen whose ListTile reads [label].
Future<void> openSettingsScreen(WidgetTester tester, String label) async {
  await openSettings(tester);
  await tapListItem(tester, label);
}
