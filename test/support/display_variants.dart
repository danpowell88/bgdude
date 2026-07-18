/// Display variants for layout testing (issue #237).
///
/// Most layout bugs in this app are not "wrong on a phone" — they are "wrong at 160%
/// font scale", "wrong in dark mode", or "wrong on a small screen". Those are exactly
/// the configurations a developer never looks at, and the ones a person managing
/// diabetes with poor eyesight uses every day.
///
/// These wrappers work in ordinary widget tests, so an overflow at large text is caught
/// in `flutter test` rather than only on a nightly emulator run. The same variants are
/// reused by the on-device matrix.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One display configuration to render a screen under.
class DisplayVariant {
  const DisplayVariant({
    required this.name,
    this.textScale = 1.0,
    this.brightness = Brightness.light,
    this.size = const Size(400, 800),
  });

  final String name;
  final double textScale;
  final Brightness brightness;
  final Size size;

  @override
  String toString() => name;
}

/// The matrix worth asserting against.
///
/// 1.6 rather than a token 1.2: Android's accessibility slider goes past 2.0, and 1.6 is
/// where multi-line labels and fixed-height rows actually start to collide. A variant
/// that never fails is not a test.
const List<DisplayVariant> displayVariants = [
  DisplayVariant(name: 'default'),
  DisplayVariant(name: 'large-text', textScale: 1.6),
  DisplayVariant(name: 'dark', brightness: Brightness.dark),
  // ~a small/older phone in logical pixels.
  DisplayVariant(name: 'compact', size: Size(320, 640)),
  // The combination is where things really break, and it is a real device state.
  DisplayVariant(
      name: 'compact-large-text', textScale: 1.6, size: Size(320, 640)),
];

/// Wraps [child] in [variant]'s MediaQuery and theme.
Widget wrapInVariant(Widget child, DisplayVariant variant) {
  return MediaQuery(
    data: MediaQueryData(
      size: variant.size,
      textScaler: TextScaler.linear(variant.textScale),
      platformBrightness: variant.brightness,
    ),
    child: MaterialApp(
      theme: ThemeData(brightness: variant.brightness),
      home: child,
    ),
  );
}

/// Pumps [child] under [variant] at that variant's surface size.
Future<void> pumpVariant(
  WidgetTester tester,
  Widget child,
  DisplayVariant variant,
) async {
  tester.view.physicalSize = variant.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(wrapInVariant(child, variant));
  await tester.pumpAndSettle();
}

/// Fails if the last pump produced a RenderFlex overflow.
///
/// Overflow is reported as a framework error rather than a thrown exception, so a test
/// that only checks for exceptions will pass over a visibly broken screen — which is how
/// these bugs reach users in the first place.
void expectNoOverflow(WidgetTester tester, {String? reason}) {
  final Object? error = tester.takeException();
  if (error == null) return;
  final text = error.toString();
  if (text.contains('overflowed')) {
    fail('Layout overflowed${reason == null ? '' : ' ($reason)'}: $text');
  }
  // Not an overflow — rethrow so a real failure isn't swallowed by a layout check.
  // ignore: only_throw_errors
  throw error;
}
