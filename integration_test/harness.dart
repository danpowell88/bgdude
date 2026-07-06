/// Shared helpers for the on-device (emulator) integration suite. Boots the real app in
/// demo mode so every screen renders against the simulated t:slim + CGM, and provides
/// small navigation helpers used across the feature tests.
///
/// Not a test file itself (no `_test.dart` suffix), so the runner won't execute it.
library;

import 'package:bgdude/app.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boot the app (demo mode by default) and let the first simulated reading land.
Future<void> pumpDemoApp(
  WidgetTester tester, {
  bool onboarded = true,
  bool devMode = true,
  String? dbOpenError,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(NotificationService()),
        onboardingDoneProvider.overrideWith((ref) => onboarded),
        devModeProvider.overrideWith((ref) => devMode),
        dbOpenErrorProvider.overrideWithValue(dbOpenError),
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
