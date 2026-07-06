/// Emulator coverage for the Protocol Explorer (read-only pump-probe console). Boots the
/// app in demo mode, opens the screen, fires a request, and asserts the synthetic response
/// lands in the log with decoded content.
///
/// Run with: flutter test integration_test/features_protocol_explorer_test.dart -d <device-id>
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Protocol Explorer opens with catalog + read-only banner',
      (tester) async {
    await pumpDemoApp(tester);
    // Now lives behind the Developer menu in Settings.
    await openSettingsScreen(tester, 'Developer');
    await tester.tap(find.text('Protocol Explorer'));
    await tester.pumpAndSettle();

    expect(find.text('Protocol Explorer'), findsWidgets);
    // The read-only guarantee is surfaced to the user.
    expect(find.textContaining('Read-only'), findsOneWidget);
    // Tabs present.
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);
    // A documented-opportunity request is listed.
    expect(find.textContaining('Home-screen mirror'), findsWidgets);
  });

  testWidgets('Sending a request logs a decoded response', (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Developer');
    await tester.tap(find.text('Protocol Explorer'));
    await tester.pumpAndSettle();

    // Fire the first available request via its Send button.
    final send = find.text('Send').first;
    await tester.scrollUntilVisible(send, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(send);
    await tester.pumpAndSettle();

    // Switch to the Log tab and confirm a response was captured and decodes.
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Response'), findsWidgets);

    // Expand the first log card and confirm decoded JSON shows.
    await tester.tap(find.textContaining('Response').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('simulated'), findsWidgets);
  });
}
