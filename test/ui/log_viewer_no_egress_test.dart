/// The diagnostics log must never leave the device (issue #95, AC#2).
///
/// A widget test can show that today's screen doesn't upload anything, but it can't stop
/// someone adding a "send to support" button later — the natural, well-meaning change
/// that would quietly turn a local diagnostics buffer into an egress path for whatever
/// the log happens to contain. So this asserts on the source: the log view and the log
/// itself may not reach for the network at all.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Imports that would give this code a way off the device.
const _networkImports = [
  'package:http/',
  'dart:io',
  'package:dio/',
  'package:web_socket_channel/',
  'firebase',
  'sentry',
];

void main() {
  final guarded = {
    'lib/ui/log_viewer_screen.dart': 'the log view',
    'lib/logging/app_log.dart': 'the log buffer itself',
  };

  for (final entry in guarded.entries) {
    test('${entry.value} has no network dependency', () {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} not found');

      final imports = file
          .readAsLinesSync()
          .where((l) => l.trimLeft().startsWith('import '))
          .toList();

      for (final banned in _networkImports) {
        final offending =
            imports.where((l) => l.toLowerCase().contains(banned)).toList();
        expect(
          offending,
          isEmpty,
          reason: '${entry.key} imports $banned — the diagnostics log is '
              'read-only and local, and nothing in it may be sent anywhere',
        );
      }
    });
  }

  test('the log view is reachable from the Developer menu', () {
    // AC#3: one developer console, rather than the log living somewhere else.
    final developer = File('lib/ui/developer_screen.dart').readAsStringSync();

    expect(developer, contains('LogViewerScreen'));
    expect(developer, contains('Diagnostics log'));
  });
}
