/// TASK-187: uncaught errors must be captured and persisted locally. Exercises the
/// CrashLog sink with an injected directory, including a real uncaught async error
/// flowing through runZonedGuarded, and the log-viewer surface.
library;

import 'dart:async';
import 'dart:io';

import 'package:bgdude/logging/app_log.dart';
import 'package:bgdude/logging/crash_log.dart';
import 'package:bgdude/ui/log_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bgdude_crash_test');
    CrashLog.directoryProvider = () async => tmp;
  });

  tearDown(() {
    CrashLog.directoryProvider = () async => tmp; // detach before deleting
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('record persists source, error and stack; readLast returns it', () async {
    await CrashLog.record('zone', StateError('boom'), StackTrace.current);
    final crash = await CrashLog.readLast();
    expect(crash, isNotNull);
    expect(crash, contains('dart zone'));
    expect(crash, contains('boom'));
    expect(crash, contains('crash_log_test')); // the stack trace made it in
  });

  test('readLast is null before any crash; clear removes the record', () async {
    expect(await CrashLog.readLast(), isNull);
    await CrashLog.record('zone', StateError('x'), StackTrace.current);
    expect(await CrashLog.readLast(), isNotNull);
    await CrashLog.clear();
    expect(await CrashLog.readLast(), isNull);
  });

  test('an oversized file is dropped so the newest crash survives', () async {
    final f = File('${tmp.path}${Platform.pathSeparator}${CrashLog.fileName}');
    f.writeAsStringSync('old ' * 20000); // > maxBytes
    await CrashLog.record('zone', StateError('fresh'), StackTrace.current);
    final crash = await CrashLog.readLast();
    expect(crash, contains('fresh'));
    expect(crash!.length, lessThan(CrashLog.maxBytes));
  });

  test('a thrown uncaught async error is captured and persisted', () async {
    final captured = Completer<void>();
    // Mirrors main(): the zone handler routes to appLog + CrashLog.
    runZonedGuarded(() {
      // Fire-and-forget future whose error nobody awaits — the classic
      // silent-death path this task closes.
      Future<void>(() => throw StateError('uncaught-async-boom'));
    }, (e, st) async {
      appLog.error('crash', '[zone] $e');
      await CrashLog.record('zone', e, st);
      captured.complete();
    });
    await captured.future;

    final crash = await CrashLog.readLast();
    expect(crash, contains('uncaught-async-boom'));
    expect(
        appLog.entries.any(
            (e) => e.tag == 'crash' && e.message.contains('uncaught-async-boom')),
        isTrue);
  });

  testWidgets('the log screen surfaces the persisted last crash', (tester) async {
    // The record itself is round-tripped by the plain tests above; the widget
    // test uses the crashText seam (real file IO can't complete in the
    // fake-async widget-test zone).
    await tester.pumpWidget(MaterialApp(
        home: LogViewerScreen(
            log: AppLog(),
            crashText: '=== 2026-07-04 dart zone\nBad state: overnight-crash')));
    expect(find.text('Last crash (persisted)'), findsOneWidget);
    expect(find.textContaining('overnight-crash'), findsOneWidget);
    // Dismiss hides the card.
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Last crash (persisted)'), findsNothing);
  });
}
