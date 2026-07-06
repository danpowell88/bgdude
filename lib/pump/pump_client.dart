/// Dart client for the native pump bridge. Listens to the `bgdude/pump_events`
/// EventChannel for connection-state changes and status snapshots, and exposes them as
/// broadcast streams the rest of the app (and Riverpod providers) can watch.
///
/// Read-only command surface (start/stop scan, submit pairing code, request status,
/// fetch history) goes over the `bgdude/pump_commands` MethodChannel.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../core/units.dart';
import 'channels.dart';
import 'probe_event.dart';
import 'pump_snapshot.dart';
import 'pump_source.dart';

class PumpClient implements PumpSource {
  PumpClient({
    EventChannel? events,
    MethodChannel? commands,
  })  : _events = events ?? const EventChannel(PumpChannels.events),
        _commands = commands ?? const MethodChannel(PumpChannels.commands);

  final EventChannel _events;
  final MethodChannel _commands;
  final _log = Logger('PumpClient');

  final _connection = StreamController<PumpConnection>.broadcast();
  final _snapshots = StreamController<PumpSnapshot>.broadcast();
  final _pairingRequests = StreamController<String>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _profiles = StreamController<String>.broadcast();
  final _probes = StreamController<ProbeEvent>.broadcast();

  StreamSubscription<dynamic>? _sub;
  PumpConnection _lastConnection = PumpConnection.idle;
  PumpSnapshot? _lastSnapshot;

  @override
  Stream<PumpConnection> get connection => _connection.stream;
  @override
  Stream<PumpSnapshot> get snapshots => _snapshots.stream;
  @override
  Stream<String> get pairingRequests => _pairingRequests.stream;
  @override
  Stream<String> get errors => _errors.stream;
  @override
  Stream<String> get therapyProfiles => _profiles.stream;
  @override
  Stream<ProbeEvent> get probeEvents => _probes.stream;

  @override
  PumpConnection get lastConnection => _lastConnection;
  @override
  PumpSnapshot? get lastSnapshot => _lastSnapshot;

  @override
  void start() {
    _sub ??= _events.receiveBroadcastStream().listen(
          _onEvent,
          onError: (Object e, StackTrace s) => _log.warning('event error', e, s),
        );
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await _connection.close();
    await _snapshots.close();
    await _pairingRequests.close();
    await _errors.close();
    await _profiles.close();
    await _probes.close();
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final map = event.cast<Object?, Object?>();
    switch (map['kind']) {
      case 'state':
        _lastConnection = PumpConnection.fromEvent(map);
        _connection.add(_lastConnection);
      case 'snapshot':
        final json = map['json'] as String?;
        if (json != null) {
          final decoded = jsonDecode(json) as Map<String, dynamic>;
          _lastSnapshot = PumpSnapshot.fromJson(decoded);
          _snapshots.add(_lastSnapshot!);
        }
      case 'pairingCode':
        _pairingRequests.add(map['type'] as String? ?? 'SHORT_6CHAR');
      case 'criticalError':
        _errors.add(map['message'] as String? ?? 'Unknown pump error');
      case 'profile':
        final json = map['json'] as String?;
        if (json != null) _profiles.add(json);
      case 'probe':
        _probes.add(ProbeEvent.fromMap(map));
    }
  }

  // --- Commands ---

  @override
  Future<void> startScan({String? macFilter}) =>
      _invoke('startScan', {'macFilter': macFilter});

  @override
  Future<void> stopScan() => _invoke('stopScan', const {});

  @override
  Future<void> requestStatus() => _invoke('requestStatus', const {});

  @override
  Future<void> submitPairingCode(String code, {required bool long}) => _invoke(
      'submitPairingCode',
      {'code': code, 'type': long ? 'LONG_16CHAR' : 'SHORT_6CHAR'});

  @override
  Future<void> unpair() => _invoke('unpair', const {});

  @override
  Future<void> setProbeCapture(bool enabled) =>
      _invoke('setProbeCapture', {'enabled': enabled});

  @override
  Future<String?> sendProbe(String className, {int? arg1, int? arg2}) async {
    try {
      return await _commands.invokeMethod<String>(
          'sendProbe', {'name': className, 'arg1': arg1, 'arg2': arg2});
    } on MissingPluginException {
      return 'native bridge not available';
    } on PlatformException catch (e) {
      _log.warning('sendProbe failed', e);
      return 'error: ${e.message}';
    }
  }

  @override
  Future<List<dynamic>> fetchHistory(
      {required int fromEpochMs, required int toEpochMs}) async {
    final raw = await _commands.invokeMethod<List<dynamic>>('fetchHistory', {
      'fromEpochMs': fromEpochMs,
      'toEpochMs': toEpochMs,
    });
    return raw ?? const [];
  }

  /// Tell the native Garmin push which display unit to send to the watch (TASK-24). The
  /// unit is a phone-side setting, so it must be plumbed to the native sender.
  @override
  Future<void> setGarminUnit(GlucoseUnit unit) =>
      _invoke('setGarminUnit', {'unit': unit.name});

  Future<void> _invoke(String method, Map<String, dynamic> args) async {
    try {
      await _commands.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // No native handler registered (e.g. running without the bridge); the read path via
      // the EventChannel still works, so a missing command is non-fatal.
      _log.info('command $method not wired');
    } on PlatformException catch (e) {
      _log.warning('command $method failed', e);
      rethrow;
    }
  }
}
