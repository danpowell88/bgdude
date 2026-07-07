/// Shared helpers for the on-device (emulator) integration suite. Boots the real app in
/// demo mode so every screen renders against the simulated t:slim + CGM, and provides
/// small navigation helpers used across the feature tests.
///
/// Not a test file itself (no `_test.dart` suffix), so the runner won't execute it.
library;

import 'package:bgdude/app.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-220: call from each integration test file's `setUp()`. The process-global
/// `KvStore` in-memory fallback otherwise leaks app flags/prefs across `testWidgets`
/// blocks that share the same file/process.
void setUpDemoHarness() => KvStore.useMemory();

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

/// Scroll the current (Settings/hub) list until [label] is visible, then tap it.
Future<void> tapListItem(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Open Settings, then navigate into the sub-screen whose ListTile reads [label].
Future<void> openSettingsScreen(WidgetTester tester, String label) async {
  await openSettings(tester);
  await tapListItem(tester, label);
}
