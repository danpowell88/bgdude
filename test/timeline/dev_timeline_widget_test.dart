import 'package:bgdude/state/providers.dart';
import 'package:bgdude/timeline/day_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('dev mode produces meal events from the simulated day',
      (tester) async {
    late List<DayEvent> events;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [devModeProvider.overrideWith((ref) => true)],
        child: Consumer(builder: (context, ref, _) {
          events = ref.watch(dayEventsProvider);
          return const SizedBox();
        }),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(events, isNotEmpty);
    expect(events.any((e) => e.type == DayEventType.meal), isTrue,
        reason: 'expected meal events from the 3 simulated meals; '
            'got: ${events.map((e) => e.type).toList()}');
  });
}
