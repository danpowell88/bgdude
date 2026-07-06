import 'package:bgdude/logging/app_log.dart';
import 'package:bgdude/ui/log_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the empty state when the log is empty', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LogViewerScreen(log: AppLog())));
    expect(find.textContaining('No diagnostics yet'), findsOneWidget);
  });

  testWidgets('lists entries newest-first with the tag and message', (tester) async {
    final log = AppLog()
      ..info('startup', 'first', at: DateTime(2026, 7, 7, 8))
      ..error('alerts', 'send failed', at: DateTime(2026, 7, 7, 9));
    await tester.pumpWidget(MaterialApp(home: LogViewerScreen(log: log)));

    expect(find.text('alerts: send failed'), findsOneWidget);
    expect(find.text('startup: first'), findsOneWidget);
    // Newest (alerts) is above oldest (startup) in the list.
    final alertsY = tester.getTopLeft(find.text('alerts: send failed')).dy;
    final startupY = tester.getTopLeft(find.text('startup: first')).dy;
    expect(alertsY, lessThan(startupY));

    // Clear empties it.
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No diagnostics yet'), findsOneWidget);
  });
}
