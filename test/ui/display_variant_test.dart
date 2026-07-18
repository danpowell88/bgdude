/// Layout holds up at large text, in dark mode, and on a small screen (issue #237).
///
/// These render real widgets from the app under each variant. The point is to fail here,
/// in `flutter test`, rather than on a nightly emulator run or on someone's phone.
library;

import 'package:bgdude/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/display_variants.dart';

/// Realistic worst-case content: the longest labels the app actually shows.
Widget _sampleScreen() => const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatTile(label: 'Time in tight range', value: '72.4', suffix: '%'),
            SizedBox(height: 12),
            KvRow('Battery optimisation', 'Exemption granted'),
            KvRow('Firmware version', 'sim-1.0 (build 635732141)'),
          ],
        ),
      ),
    );

void main() {
  group('common widgets survive every display variant', () {
    for (final variant in displayVariants) {
      testWidgets('$variant', (tester) async {
        await pumpVariant(tester, _sampleScreen(), variant);

        expectNoOverflow(tester, reason: variant.name);
        // Still actually rendering — a screen that drew nothing also does not
        // overflow, and would make this assertion vacuous.
        expect(find.textContaining('Time in tight range'), findsWidgets);
      });
    }
  });

  group('variants', () {
    test('the matrix covers large text, dark and compact', () {
      final names = displayVariants.map((v) => v.name).toList();
      expect(names, contains('large-text'));
      expect(names, contains('dark'));
      expect(names, contains('compact'));
      // The combination is where things actually break.
      expect(names, contains('compact-large-text'));
    });

    test('large text is scaled far enough to be a real test', () {
      // Android's accessibility slider goes past 2.0; a token 1.2 never fails and
      // therefore proves nothing.
      final large =
          displayVariants.firstWhere((v) => v.name == 'large-text');
      expect(large.textScale, greaterThanOrEqualTo(1.6));
    });

    test('variant names are unique', () {
      final names = displayVariants.map((v) => v.name).toList();
      expect(names.toSet().length, names.length);
    });
  });

  group('expectNoOverflow', () {
    testWidgets('fails when the layout overflows', (tester) async {
      // Guards the guard: a checker that never fires would make every variant test
      // above vacuous.
      tester.view.physicalSize = const Size(80, 60);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(width: 400, child: Text('far too wide for this row')),
              ],
            ),
          ),
        ),
      );

      expect(() => expectNoOverflow(tester), throwsA(isA<TestFailure>()));
    });

    testWidgets('passes on a well-behaved layout', (tester) async {
      await pumpVariant(
        tester,
        const Scaffold(body: Center(child: Text('fine'))),
        displayVariants.first,
      );

      expectNoOverflow(tester);
    });
  });
}
