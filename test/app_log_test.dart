import 'package:bgdude/logging/app_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records entries newest-last with level/tag/message', () {
    final log = AppLog(capacity: 10);
    log.info('alerts', 'fired low', at: DateTime(2026, 7, 7, 8));
    log.error('pump', 'send failed',
        error: StateError('boom'), at: DateTime(2026, 7, 7, 9));
    expect(log.length, 2);
    expect(log.entries.first.tag, 'alerts');
    expect(log.entries.last.level, LogLevel.error);
    expect(log.entries.last.error, contains('boom'));
    expect(log.entries.last.line, contains('pump: send failed'));
  });

  test('caps at capacity and evicts the oldest first', () {
    final log = AppLog(capacity: 3);
    for (var i = 0; i < 5; i++) {
      log.info('t', 'm$i', at: DateTime(2026, 7, 7).add(Duration(minutes: i)));
    }
    expect(log.length, 3);
    // Oldest two (m0, m1) evicted; m2..m4 remain in order.
    expect(log.entries.map((e) => e.message).toList(), ['m2', 'm3', 'm4']);
  });

  test('clear empties the buffer', () {
    final log = AppLog(capacity: 5)..info('t', 'x');
    log.clear();
    expect(log.length, 0);
  });
}
