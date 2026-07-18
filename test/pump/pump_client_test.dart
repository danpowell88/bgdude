/// PumpClient event demultiplexing and command surface (issue #378).
///
/// PumpClient looks like untestable platform plumbing, but its constructor takes
/// injectable EventChannel/MethodChannel instances, so every branch of the event
/// switch and every command's failure handling is reachable from a unit test. It
/// is deliberately NOT on the coverage exclusion list for exactly that reason —
/// see tools/coverage_exclusions.txt.
///
/// Note on the mock stream handler: `sink.endOfStream()` is never called here.
/// Closing the mock's sink wedges teardown in this harness (a flutter_test quirk
/// reproduced with a bare broadcast StreamController, documented in
/// pump_data_test.dart's snapshot-decode-guard test) — not a PumpClient bug.
library;

import 'package:bgdude/core/units.dart';
import 'package:bgdude/pump/pump_client.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A well-formed snapshot payload the real parser accepts.
const _goodSnapshotJson = '{"schemaVersion":1,"timestampEpochMs":1751800000000,'
    '"cgmMgdl":120,"cgmTimestampEpochMs":1751799900000}';

TestDefaultBinaryMessenger get messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Wires [events] to emit [payloads] on subscribe, and returns a started client.
  PumpClient clientEmitting(
    EventChannel events,
    List<Object?> payloads,
  ) {
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          for (final payload in payloads) {
            sink.success(payload);
          }
        },
      ),
    );
    addTearDown(() => messenger.setMockStreamHandler(events, null));
    return PumpClient(events: events);
  }

  group('event demultiplexing', () {
    testWidgets('a state event updates lastConnection and the connection stream',
        (tester) async {
      const events = EventChannel('test/pump_events_state');
      final client = clientEmitting(events, [
        <Object?, Object?>{
          'kind': 'state',
          'stage': 'connected',
          'pumpName': 'tslim-1234',
          'jpakeProgress': 3,
        },
      ]);

      final received = <PumpConnection>[];
      final sub = client.connection.listen(received.add);
      addTearDown(sub.cancel);

      // Before start() nothing is subscribed, so the last state is still idle.
      expect(client.lastConnection.stage, PumpConnectionStage.idle);

      client.start();
      await tester.pump();

      expect(received, hasLength(1));
      expect(received.single.pumpName, 'tslim-1234');
      expect(received.single.jpakeProgress, 3);
      // The client caches the latest state for late subscribers, not just relays it.
      expect(client.lastConnection.pumpName, 'tslim-1234');
    });

    testWidgets('a snapshot event parses, caches and publishes', (tester) async {
      const events = EventChannel('test/pump_events_snapshot');
      final client = clientEmitting(events, [
        <Object?, Object?>{'kind': 'snapshot', 'json': _goodSnapshotJson},
      ]);

      final received = <PumpSnapshot>[];
      final sub = client.snapshots.listen(received.add);
      addTearDown(sub.cancel);
      client.start();
      await tester.pump();

      expect(received, hasLength(1));
      expect(received.single.cgmMgdl, 120);
      expect(client.lastSnapshot?.cgmMgdl, 120);
    });

    testWidgets('a snapshot event with no json payload publishes nothing',
        (tester) async {
      const events = EventChannel('test/pump_events_snapshot_null');
      final client = clientEmitting(events, [
        <Object?, Object?>{'kind': 'snapshot'},
        <Object?, Object?>{'kind': 'snapshot', 'json': _goodSnapshotJson},
      ]);

      final received = <PumpSnapshot>[];
      final sub = client.snapshots.listen(received.add);
      addTearDown(sub.cancel);
      client.start();
      await tester.pump();

      // Exactly one: the null-json event is dropped, the good one still arrives.
      expect(received, hasLength(1));
      expect(received.single.cgmMgdl, 120);
    });

    testWidgets('a pairingCode event defaults to SHORT_6CHAR when type is absent',
        (tester) async {
      const events = EventChannel('test/pump_events_pairing');
      final client = clientEmitting(events, [
        <Object?, Object?>{'kind': 'pairingCode', 'type': 'LONG_16CHAR'},
        <Object?, Object?>{'kind': 'pairingCode'},
      ]);

      final received = <String>[];
      final sub = client.pairingRequests.listen(received.add);
      addTearDown(sub.cancel);
      client.start();
      await tester.pump();

      expect(received, ['LONG_16CHAR', 'SHORT_6CHAR']);
    });

    testWidgets('a criticalError event falls back to a non-empty message',
        (tester) async {
      const events = EventChannel('test/pump_events_error');
      final client = clientEmitting(events, [
        <Object?, Object?>{'kind': 'criticalError', 'message': 'occlusion'},
        <Object?, Object?>{'kind': 'criticalError'},
      ]);

      final received = <String>[];
      final sub = client.errors.listen(received.add);
      addTearDown(sub.cancel);
      client.start();
      await tester.pump();

      // The fallback matters: a blank alert banner would tell the user nothing.
      expect(received, ['occlusion', 'Unknown pump error']);
    });

    testWidgets('a profile event forwards its raw json only when present',
        (tester) async {
      const events = EventChannel('test/pump_events_profile');
      final client = clientEmitting(events, [
        <Object?, Object?>{'kind': 'profile'},
        <Object?, Object?>{'kind': 'profile', 'json': '{"name":"Weekday"}'},
      ]);

      final received = <String>[];
      final sub = client.therapyProfiles.listen(received.add);
      addTearDown(sub.cancel);
      client.start();
      await tester.pump();

      expect(received, ['{"name":"Weekday"}']);
    });

    testWidgets('non-Map events and unknown kinds are ignored, not fatal',
        (tester) async {
      const events = EventChannel('test/pump_events_junk');
      final client = clientEmitting(events, [
        'a bare string',
        42,
        <Object?, Object?>{'kind': 'somethingTheNativeSideAddedLater'},
        <Object?, Object?>{'kind': 'snapshot', 'json': _goodSnapshotJson},
      ]);

      final snapshots = <PumpSnapshot>[];
      final connections = <PumpConnection>[];
      final subA = client.snapshots.listen(snapshots.add);
      final subB = client.connection.listen(connections.add);
      addTearDown(subA.cancel);
      addTearDown(subB.cancel);
      client.start();
      await tester.pump();

      // Junk must not tear down the subscription: the good event after it lands.
      expect(snapshots, hasLength(1));
      expect(connections, isEmpty);
    });

    testWidgets('start() is idempotent — a second call does not double-subscribe',
        (tester) async {
      const events = EventChannel('test/pump_events_idempotent');
      var listenCount = 0;
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            listenCount++;
            sink.success(
                <Object?, Object?>{'kind': 'snapshot', 'json': _goodSnapshotJson});
          },
        ),
      );
      addTearDown(() => messenger.setMockStreamHandler(events, null));

      final client = PumpClient(events: events);
      final received = <PumpSnapshot>[];
      final sub = client.snapshots.listen(received.add);
      addTearDown(sub.cancel);

      client.start();
      client.start();
      client.start();
      await tester.pump();

      // Without the `??=` guard each start() adds another subscription and every
      // snapshot would be delivered (and re-parsed) once per call.
      expect(listenCount, 1);
      expect(received, hasLength(1));
    });
  });

  group('command surface', () {
    /// Records every MethodCall made on [channel] and returns [result].
    List<MethodCall> recordCalls(MethodChannel channel, {Object? result}) {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return result;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      return calls;
    }

    test('each command sends its documented method name and arguments', () async {
      const channel = MethodChannel('test/pump_commands_args');
      final calls = recordCalls(channel);
      final client = PumpClient(commands: channel);

      await client.startScan(macFilter: 'AA:BB');
      await client.stopScan();
      await client.requestStatus();
      await client.submitPairingCode('123456', long: false);
      await client.submitPairingCode('0123456789ABCDEF', long: true);
      await client.unpair();
      await client.setProbeCapture(true);
      await client.setGarminUnit(GlucoseUnit.mmol);

      expect(
        calls.map((c) => c.method),
        [
          'startScan',
          'stopScan',
          'requestStatus',
          'submitPairingCode',
          'submitPairingCode',
          'unpair',
          'setProbeCapture',
          'setGarminUnit',
        ],
      );
      expect(calls[0].arguments, {'macFilter': 'AA:BB'});
      // The long/short flag maps to the native pairing-type contract; getting this
      // wrong makes pairing fail with a valid code.
      expect(calls[3].arguments, {'code': '123456', 'type': 'SHORT_6CHAR'});
      expect(calls[4].arguments,
          {'code': '0123456789ABCDEF', 'type': 'LONG_16CHAR'});
      expect(calls[6].arguments, {'enabled': true});
      expect(calls[7].arguments, {'unit': 'mmol'});
    });

    test('a missing native handler is non-fatal for fire-and-forget commands',
        () async {
      // No mock handler registered at all => MissingPluginException. The read path
      // over the EventChannel still works, so these must not throw.
      const channel = MethodChannel('test/pump_commands_unwired');
      final client = PumpClient(commands: channel);

      await client.startScan();
      await client.stopScan();
      await client.requestStatus();
      await client.unpair();
    });

    test('a PlatformException from a command is rethrown, not swallowed',
        () async {
      const channel = MethodChannel('test/pump_commands_throwing');
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'BLE_OFF', message: 'adapter off');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final client = PumpClient(commands: channel);

      // Distinct from the MissingPlugin case above: a real native failure is a
      // signal the caller must see, not a no-op bridge.
      await expectLater(
        client.startScan(),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'BLE_OFF')),
      );
    });

    test('fetchHistory passes the window through and maps null to an empty list',
        () async {
      const channel = MethodChannel('test/pump_commands_history');
      final calls = <MethodCall>[];
      Object? result;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return result;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final client = PumpClient(commands: channel);

      result = null;
      expect(await client.fetchHistory(fromEpochMs: 10, toEpochMs: 20), isEmpty);
      expect(calls.single.arguments, {'fromEpochMs': 10, 'toEpochMs': 20});

      result = <dynamic>[
        {'epochMs': 1, 'type': 'bolus'}
      ];
      expect(await client.fetchHistory(fromEpochMs: 10, toEpochMs: 20),
          hasLength(1));
    });

    test('sendProbe reports bridge/platform failures as readable strings',
        () async {
      const ok = MethodChannel('test/pump_probe_ok');
      messenger.setMockMethodCallHandler(ok, (call) async => 'probe result');
      addTearDown(() => messenger.setMockMethodCallHandler(ok, null));
      expect(await PumpClient(commands: ok).sendProbe('Foo', arg1: 1),
          'probe result');

      // Unwired bridge => a diagnostic string, not an exception, because this is a
      // developer-surface probe whose whole job is to report what happened.
      const unwired = MethodChannel('test/pump_probe_unwired');
      expect(await PumpClient(commands: unwired).sendProbe('Foo'),
          'native bridge not available');

      const failing = MethodChannel('test/pump_probe_failing');
      messenger.setMockMethodCallHandler(failing, (call) async {
        throw PlatformException(code: 'X', message: 'nope');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(failing, null));
      expect(await PumpClient(commands: failing).sendProbe('Foo'), 'error: nope');
    });

    test('garminHealth returns null rather than throwing when unavailable',
        () async {
      const ok = MethodChannel('test/pump_garmin_ok');
      messenger.setMockMethodCallHandler(
          ok, (call) async => <String, dynamic>{'reachable': true});
      addTearDown(() => messenger.setMockMethodCallHandler(ok, null));
      expect(await PumpClient(commands: ok).garminHealth(),
          {'reachable': true});

      const unwired = MethodChannel('test/pump_garmin_unwired');
      expect(await PumpClient(commands: unwired).garminHealth(), isNull);

      const failing = MethodChannel('test/pump_garmin_failing');
      messenger.setMockMethodCallHandler(failing, (call) async {
        throw PlatformException(code: 'X', message: 'nope');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(failing, null));
      expect(await PumpClient(commands: failing).garminHealth(), isNull);
    });
  });

  group('dispose', () {
    test('closes every stream so listeners terminate', () async {
      // start() is deliberately NOT called: cancelling a subscription to a mocked
      // EventChannel never completes in this harness (the same flutter_test quirk
      // documented in pump_data_test.dart), which would wedge dispose() on its
      // `_sub?.cancel()` regardless of the stream-closing behaviour under test.
      // With no subscription that await is a no-op, leaving the six controller
      // closes — the actual contract here — fully exercised.
      final client = PumpClient(commands: const MethodChannel('test/unused'));

      final done = <String>{};
      client.connection.listen(null, onDone: () => done.add('connection'));
      client.snapshots.listen(null, onDone: () => done.add('snapshots'));
      client.pairingRequests.listen(null, onDone: () => done.add('pairing'));
      client.errors.listen(null, onDone: () => done.add('errors'));
      client.therapyProfiles.listen(null, onDone: () => done.add('profiles'));
      client.probeEvents.listen(null, onDone: () => done.add('probes'));

      await client.dispose();

      // A controller left open leaks its listener for the app's lifetime; naming
      // each one means a newly-added stream that dispose() forgets fails here.
      expect(
        done,
        {'connection', 'snapshots', 'pairing', 'errors', 'profiles', 'probes'},
      );
    });
  });
}
