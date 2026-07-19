/// Edge-to-edge / system-bar inset testing (issue #242).
///
/// `targetSdk` is already 37, and from Android 15 the system draws app content **behind**
/// the status and navigation bars by default. Anything that assumes it owns the full
/// window can end up with a button under the gesture bar or a heading under the clock —
/// tappable in the emulator's default configuration and not on a real phone.
///
/// A widget test can reproduce that precisely: system bars are just `viewPadding` in
/// `MediaQuery`, so a screen can be rendered with realistic insets and its content
/// checked against them without a device.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Realistic Android 15 insets: status bar on top, gesture navigation bar at the bottom.
const EdgeInsets androidSystemBars = EdgeInsets.only(top: 48, bottom: 48);

/// Renders [child] as if the system bars overlay the window.
Future<void> pumpEdgeToEdge(
  WidgetTester tester,
  Widget child, {
  EdgeInsets bars = androidSystemBars,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      // viewPadding is what SafeArea consumes; padding mirrors it when nothing else
      // (a keyboard) is intruding.
      data: MediaQueryData(
        size: size,
        viewPadding: bars,
        padding: bars,
      ),
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

/// Fails if the widget found by [finder] overlaps the system bars.
///
/// Checks geometry rather than trusting that a `SafeArea` is present somewhere in the
/// tree: a `SafeArea` with `bottom: false`, or one nested inside something that already
/// consumed the padding, looks correct in the source and still leaves the button under
/// the gesture bar.
void expectClearOfSystemBars(
  WidgetTester tester,
  Finder finder, {
  EdgeInsets bars = androidSystemBars,
  Size size = const Size(400, 800),
  String? reason,
}) {
  final rect = tester.getRect(finder);
  final label = reason == null ? '' : ' ($reason)';

  expect(
    rect.top >= bars.top,
    isTrue,
    reason: 'content overlaps the status bar$label: top=${rect.top} '
        'but the bar occupies 0..${bars.top}',
  );
  expect(
    rect.bottom <= size.height - bars.bottom,
    isTrue,
    reason: 'content overlaps the navigation bar$label: bottom=${rect.bottom} '
        'but the bar starts at ${size.height - bars.bottom}',
  );
}
