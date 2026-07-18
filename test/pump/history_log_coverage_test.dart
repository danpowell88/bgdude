/// The Dart history-log coverage list, checked against the committed report (issue #94).
///
/// The Kotlin `HistoryLogCoverageTest` checks the markdown report against the pumpx2 jar
/// and `PumpHistoryMapper`. This closes the loop from the other side: the list the app
/// SHOWS must match that same report, so all three can't drift apart independently.
library;

import 'dart:io';

import 'package:bgdude/pump/history_log_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final report = File('doc/pump-history-coverage.md');

  test('the report exists where the Kotlin test writes its assertions', () {
    expect(report.existsSync(), isTrue,
        reason: 'doc/pump-history-coverage.md is the shared source of truth');
  });

  test('the totals match the committed report', () {
    final text = report.readAsStringSync();

    expect(text, contains('${historyLogTypes.length} event types'));
    expect(text, contains('**$decodedHistoryLogCount decoded**'));
  });

  test('every type the app shows appears in the report', () {
    final text = report.readAsStringSync();

    for (final t in historyLogTypes) {
      expect(text, contains(t.name), reason: t.name);
    }
  });

  test('every type the report calls decoded is decoded here', () {
    // The report lists decoded types under a "## Decoded" heading; anything named
    // there must be flagged decoded in the app's own list, or the screen would
    // understate what bgdude handles.
    final text = report.readAsStringSync();
    final decodedSection = text
        .split('## Decoded')
        .last
        .split('## Not decoded')
        .first;

    final decodedInApp = {
      for (final t in historyLogTypes)
        if (t.decoded) t.name,
    };
    for (final name in decodedInApp) {
      expect(decodedSection, contains(name), reason: '$name should be listed as decoded');
    }
    // And nothing extra is claimed as decoded in the report.
    for (final t in historyLogTypes) {
      if (!t.decoded) {
        expect(decodedSection.contains('`${t.name}`'), isFalse,
            reason: '${t.name} is listed as decoded but is not');
      }
    }
  });

  test('names are unique and non-empty', () {
    final names = historyLogTypes.map((t) => t.name).toList();
    expect(names.toSet().length, names.length);
    expect(names.every((n) => n.isNotEmpty), isTrue);
  });

  test('coverage is a real subset, not all-or-nothing', () {
    // Guards a regeneration bug that flags everything (or nothing) as decoded — either
    // would make the screen actively misleading about what the app understands.
    expect(decodedHistoryLogCount, greaterThan(0));
    expect(decodedHistoryLogCount, lessThan(historyLogTypes.length));
  });
}
