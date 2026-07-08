import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/therapy_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-198 AC#2: a save whose write fails must surface an error to the user instead
/// of silently looking saved (and then reverting on the next restart). [shouldThrow]
/// is flipped mid-test so the same notifier can demonstrate both a normal save (to
/// get a second segment on screen) and a failing one.
class _FlakyTherapyNotifier extends TherapyNotifier {
  bool shouldThrow = false;

  @override
  Future<void> store(TherapySettings v) async {
    if (shouldThrow) throw StateError('simulated write failure');
  }
}

void main() {
  testWidgets(
      'a failed save shows an error and the segment removal does not silently '
      'succeed', (tester) async {
    final notifier = _FlakyTherapyNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          therapySettingsProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: TherapySettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Add a second segment (a normal, successful save) so the delete icon appears
    // (it's hidden when there's only one segment).
    await tester.tap(find.text('Add segment'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '12'); // start hour
    await tester.enterText(fields.at(2), '54'); // ISF
    await tester.enterText(fields.at(3), '10'); // carb ratio
    await tester.enterText(fields.at(4), '100'); // target
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    final segmentsBeforeFailure = notifier.state.segments.length;
    expect(segmentsBeforeFailure, 2);

    // Now make the write fail and try to delete a segment.
    notifier.shouldThrow = true;
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump(); // start the async save
    await tester.pump(const Duration(milliseconds: 50)); // let it fail + revert

    // persist() must have reverted state — the segment count is unchanged, not
    // silently down to 1 while disk still (would-be) has 2.
    expect(notifier.state.segments.length, segmentsBeforeFailure);

    await tester.pump(const Duration(seconds: 1)); // let the SnackBar animate in
    expect(find.textContaining('Could not save'), findsOneWidget);
  });
}
