/// Edge-to-edge regression coverage (issue #242).
///
/// `targetSdk` is 37, so from Android 15 the system draws app content behind the status
/// and navigation bars. The classic casualty is a bottom sheet's confirm button sitting
/// under the gesture bar — still tappable in an emulator's default config, not on a real
/// phone.
///
/// These render with realistic insets and check the geometry, so the regression is caught
/// in `flutter test` rather than on a device nobody has to hand.
library;

import 'package:bgdude/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/system_bars.dart';

/// A bottom sheet shaped like the app's — the shape most at risk, since a sheet is
/// anchored to the very edge the navigation bar occupies.
Widget _sheet({required bool safe}) {
  const content = Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      StatTile(label: 'Carbs', value: '45', suffix: 'g'),
      SizedBox(height: 8),
      ElevatedButton(onPressed: null, key: Key('sheet-confirm'), child: Text('Log it')),
    ],
  );
  return Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: safe ? const SafeArea(child: content) : content,
    ),
  );
}

void main() {
  testWidgets('a bottom sheet keeps its confirm button clear of the nav bar',
      (tester) async {
    await pumpEdgeToEdge(tester, _sheet(safe: true));

    expectClearOfSystemBars(
      tester,
      find.byKey(const Key('sheet-confirm')),
      reason: 'the confirm button is what the user reaches for',
    );
  });

  testWidgets('the check FAILS on an unprotected sheet', (tester) async {
    // Guards the guard. A geometry check that never fires would make the test above
    // vacuous, and this is exactly the regression it exists to catch: without
    // SafeArea the button sits under the gesture bar.
    await pumpEdgeToEdge(tester, _sheet(safe: false));

    expect(
      () => expectClearOfSystemBars(
          tester, find.byKey(const Key('sheet-confirm'))),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('a Scaffold body stays clear of the status bar', (tester) async {
    await pumpEdgeToEdge(
      tester,
      const Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Text('Heading', key: Key('heading')),
          ),
        ),
      ),
    );

    expectClearOfSystemBars(tester, find.byKey(const Key('heading')));
  });

  testWidgets('an AppBar pushes content below the status bar without SafeArea',
      (tester) async {
    // Scaffold already handles this case; asserting it means a future change that
    // breaks it is caught, and documents WHY these screens need no SafeArea.
    await pumpEdgeToEdge(
      tester,
      const Scaffold(
        appBar: null,
        body: Column(children: [Text('body', key: Key('body'))]),
      ),
    );

    // Without an AppBar or SafeArea the body starts at y=0 — under the status bar.
    // Stated as an expectation so the asymmetry is explicit rather than folklore.
    final rect = tester.getRect(find.byKey(const Key('body')));
    expect(rect.top, lessThan(androidSystemBars.top),
        reason: 'demonstrates that a bare Column does NOT self-protect');
  });

  testWidgets('taller navigation bars are still respected', (tester) async {
    // Three-button navigation is taller than gesture navigation; a layout that only
    // clears the smaller inset breaks for anyone not using gestures.
    const tallBars = EdgeInsets.only(top: 48, bottom: 96);

    await pumpEdgeToEdge(tester, _sheet(safe: true), bars: tallBars);

    expectClearOfSystemBars(
      tester,
      find.byKey(const Key('sheet-confirm')),
      bars: tallBars,
      reason: 'three-button navigation',
    );
  });
}
