import 'package:bgdude/analytics/insulin_totals.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/logging/device_changes.dart';
import 'package:bgdude/pump/history_backfill.dart';
import 'package:bgdude/pump/pump_client.dart';
import 'package:bgdude/pump/pump_events.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('insulinTotals', () {
    final from = DateTime(2026, 7, 4, 0);
    final to = DateTime(2026, 7, 4, 24);

    test('sums boluses in-window and integrates basal', () {
      final totals = insulinTotals(
        boluses: [
          BolusEvent(time: DateTime(2026, 7, 4, 8), units: 5),
          BolusEvent(time: DateTime(2026, 7, 4, 18), units: 3),
          // Out of window — ignored.
          BolusEvent(time: DateTime(2026, 7, 3, 23), units: 10),
        ],
        basal: [
          // 1.0 U/hr for the whole 24h day = 24 U.
          BasalSegment(start: from, end: to, unitsPerHour: 1.0),
        ],
        from: from,
        to: to,
      );
      expect(totals.bolus, 8);
      expect(totals.basal, closeTo(24, 1e-9));
      expect(totals.total, closeTo(32, 1e-9));
      expect(totals.basalFraction, closeTo(24 / 32, 1e-9));
    });

    test('clips basal segments straddling the window edges', () {
      final totals = insulinTotals(
        boluses: const [],
        basal: [
          // Starts before window: only the in-window 2h counts (0.5 U/hr → 1 U).
          BasalSegment(
              start: DateTime(2026, 7, 3, 22),
              end: DateTime(2026, 7, 4, 2),
              unitsPerHour: 0.5),
        ],
        from: from,
        to: to,
      );
      expect(totals.basal, closeTo(1.0, 1e-9)); // 2h × 0.5
    });

    test('empty is zero, no divide-by-zero', () {
      final t = insulinTotals(
          boluses: const [], basal: const [], from: from, to: to);
      expect(t.total, 0);
      expect(t.basalFraction, 0);
    });
  });

  group('PumpSnapshot alerts', () {
    test('parses active alerts/alarms arrays from JSON', () {
      final s = PumpSnapshot.fromJson({
        'timestampEpochMs': 1_700_000_000_000,
        'reservoirUnits': 12.0,
        'activeAlarms': ['LOW_INSULIN_ALARM'],
        'activeAlerts': ['LOW_POWER_ALERT', 'CGM_SIGNAL_LOSS'],
      });
      expect(s.activeAlarms, ['LOW_INSULIN_ALARM']);
      expect(s.activeAlerts, hasLength(2));
      expect(s.reservoirUnits, 12.0);
    });

    test('defaults to empty lists when absent', () {
      final s = PumpSnapshot.fromJson({'timestampEpochMs': 1_700_000_000_000});
      expect(s.activeAlarms, isEmpty);
      expect(s.activeAlerts, isEmpty);
    });
  });

  group('PumpEventLog', () {
    setUp(KvStore.useMemory);

    test('appends, sorts newest-first, and de-dups on re-append', () async {
      final a = PumpEvent(
          time: DateTime(2026, 7, 4, 8),
          kind: PumpEventKind.alarm,
          detail: 'LOW_INSULIN');
      final b = PumpEvent(
          time: DateTime(2026, 7, 4, 10),
          kind: PumpEventKind.cannulaChange,
          detail: 'Cannula filled');
      await PumpEventLog.append([a, b]);
      await PumpEventLog.append([a]); // duplicate
      final events = await PumpEventLog.load();
      expect(events, hasLength(2));
      expect(events.first.time, b.time); // newest first
    });

    test('caps at maxEvents', () async {
      await PumpEventLog.append([
        for (var i = 0; i < PumpEventLog.maxEvents + 20; i++)
          PumpEvent(
              time: DateTime(2026, 7, 4).add(Duration(minutes: i)),
              kind: PumpEventKind.alert,
              detail: 'a$i'),
      ]);
      expect((await PumpEventLog.load()).length, PumpEventLog.maxEvents);
    });
  });

  group('HistoryBackfillService routing', () {
    setUp(KvStore.useMemory);

    test('routes new history types to repo + callbacks', () async {
      const channel = MethodChannel('bgdude/pump_commands');
      final t = DateTime(2026, 7, 4, 12).millisecondsSinceEpoch;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'fetchHistory') return null;
        return <Map<Object?, Object?>>[
          {'epochMs': t, 'type': 'bolus', 'units': 4.0, 'carbsGrams': 40.0},
          {'epochMs': t + 1000, 'type': 'carb', 'carbsGrams': 30.0},
          {'epochMs': t + 2000, 'type': 'cannulaFilled', 'primeSize': 0.3},
          {'epochMs': t + 3000, 'type': 'cartridgeFilled', 'units': 200.0},
          {'epochMs': t + 4000, 'type': 'alarm', 'name': 'LOW_INSULIN_ALARM'},
          {'epochMs': t + 5000, 'type': 'alert', 'name': 'LOW_POWER_ALERT'},
        ];
      });

      final repo = InMemoryHistoryRepository();
      final deviceChanges = <(DeviceKind, DateTime)>[];
      final events = <PumpEvent>[];
      final imported = await HistoryBackfillService(
        repo,
        PumpClient(commands: channel),
      ).backfill(
        from: DateTime(2026, 7, 4),
        to: DateTime(2026, 7, 5),
        onDeviceChange: (k, at) => deviceChanges.add((k, at)),
        onPumpEvent: events.add,
      );

      expect(imported, 6);
      // Carb + bolus landed in the repository.
      final carbs = await repo.carbs(DateTime(2026, 7, 4), DateTime(2026, 7, 5));
      expect(carbs, hasLength(1));
      expect(carbs.single.grams, 30.0);
      // Cannula fill → a site device-change callback.
      expect(deviceChanges, hasLength(1));
      expect(deviceChanges.single.$1, DeviceKind.site);
      // Cartridge + alarm + alert → pump events.
      expect(events.map((e) => e.kind), containsAll(<PumpEventKind>[
        PumpEventKind.cartridgeChange,
        PumpEventKind.alarm,
        PumpEventKind.alert,
      ]));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });

  group('snapshot decode guard (TASK-181)', () {
    testWidgets('a malformed event is skipped and the next good one processes',
        (tester) async {
      const events = EventChannel('bgdude/pump_events');
      final client = PumpClient(events: events);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(events, MockStreamHandler.inline(
        onListen: (arguments, sink) {
          // 1. Malformed JSON — used to throw an uncaught zone error and, for a
          //    recurring shape, quietly stop live updates.
          sink.success(<Object?, Object?>{'kind': 'snapshot', 'json': '{broken'});
          // 2. Wrong shape (valid JSON, not an object the parser accepts).
          sink.success(<Object?, Object?>{'kind': 'snapshot', 'json': '[1,2]'});
          // 3. A good snapshot MUST still come through on the same subscription.
          sink.success(<Object?, Object?>{
            'kind': 'snapshot',
            'json': '{"schemaVersion":1,"timestampEpochMs":1751800000000,'
                '"cgmMgdl":120,"cgmTimestampEpochMs":1751799900000}',
          });
          // Deliberately no sink.endOfStream() call: closing the mock's sink here
          // wedges the subsequent teardown (setMockStreamHandler(events, null) /
          // client.dispose()) indefinitely in this test harness — reproduced with
          // a bare, unrelated broadcast StreamController too, so it's a
          // flutter_test-environment quirk, not a PumpClient bug. Not calling it
          // doesn't weaken the assertions below.
        },
      ));
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockStreamHandler(events, null));

      final received = <PumpSnapshot>[];
      final sub = client.snapshots.listen(received.add);
      addTearDown(sub.cancel);
      client.start();
      await tester.pump();
      await tester.pump();

      expect(received, hasLength(1),
          reason: 'the two malformed events are skipped, the good one lands');
      expect(received.single.cgmMgdl, 120);
    });
  });
}
