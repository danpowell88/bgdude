/// Issue #376 gap 2: a denied camera must explain itself and offer a way out.
///
/// Tested against [ScannerErrorView] directly rather than through `MobileScanner`,
/// which needs a real camera platform — the reason the view is its own widget.
library;

import 'package:bgdude/ui/widgets/scanner_error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<void> _pump(
  WidgetTester tester,
  MobileScannerErrorCode code, {
  VoidCallback? onOpenSettings,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ScannerErrorView(errorCode: code, onOpenSettings: onOpenSettings),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a denied camera explains WHY bgdude wants it, and where the '
      'image goes', (tester) async {
    await _pump(tester, MobileScannerErrorCode.permissionDenied);

    expect(find.text('Camera access is off'), findsOneWidget);
    // The rationale is the point of this view — a bare "permission denied" tells
    // the user nothing about whether granting it is reasonable.
    expect(find.textContaining('read a product barcode'), findsOneWidget);
    expect(find.textContaining('Nothing leaves the phone'), findsOneWidget);
  });

  testWidgets('a denied camera offers Open settings and it fires', (tester) async {
    var opened = 0;
    await _pump(tester, MobileScannerErrorCode.permissionDenied,
        onOpenSettings: () => opened++);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(opened, 1);
  });

  testWidgets('a device with no camera does NOT offer Open settings',
      (tester) async {
    await _pump(tester, MobileScannerErrorCode.unsupported);

    expect(find.text('Camera unavailable'), findsOneWidget);
    // Sending someone to system settings for hardware they don't have is a dead
    // end; the copy points at the working alternative instead.
    expect(find.text('Open settings'), findsNothing);
    expect(find.textContaining('searching for them by name'), findsOneWidget);
  });

  testWidgets('an unexpected error degrades to the generic message, not a blank',
      (tester) async {
    // Any future/unknown code must still render something actionable rather than
    // falling through to an empty view.
    await _pump(tester, MobileScannerErrorCode.controllerUninitialized);

    expect(find.text('Camera unavailable'), findsOneWidget);
    expect(find.textContaining('could not be started'), findsOneWidget);
    expect(find.text('Open settings'), findsNothing);
  });
}
