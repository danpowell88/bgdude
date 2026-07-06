/// Dev-mode pump source: replays a [SimulatedDay] as if a real t:slim X2 + Dexcom were
/// connected. It "connects" immediately, streams the day's final CGM reading as the live
/// value, and advances a simulated clock so the trace keeps moving while you watch.
///
/// The whole simulated day (history + context) is exposed via [day] so the timeline,
/// analytics, and prediction screens have real content to render without hardware.
library;

import 'dart:async';

import '../dev/sim_data.dart';
import 'probe_event.dart';
import 'pump_snapshot.dart';
import 'pump_source.dart';
import '../core/sleep_window.dart';

class SimulatedPumpClient implements PumpSource {
  SimulatedPumpClient({SimulatedDay? day, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        day = day ?? SimulatedDay.generate(now: (clock ?? DateTime.now)());

  final DateTime Function() _clock;

  /// The generated day powering both the live feed and the history screens.
  SimulatedDay day;

  final _connection = StreamController<PumpConnection>.broadcast();
  final _snapshots = StreamController<PumpSnapshot>.broadcast();
  final _pairing = StreamController<String>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _probes = StreamController<ProbeEvent>.broadcast();

  Timer? _ticker;
  bool _probeCapture = false;
  int _cursor = 0;
  PumpConnection _lastConnection = PumpConnection.idle;
  PumpSnapshot? _lastSnapshot;

  @override
  Stream<PumpConnection> get connection => _connection.stream;
  @override
  Stream<PumpSnapshot> get snapshots => _snapshots.stream;
  @override
  Stream<String> get pairingRequests => _pairing.stream;
  @override
  Stream<String> get errors => _errors.stream;
  @override
  Stream<String> get therapyProfiles => const Stream<String>.empty();
  @override
  Stream<ProbeEvent> get probeEvents => _probes.stream;
  @override
  PumpConnection get lastConnection => _lastConnection;
  @override
  PumpSnapshot? get lastSnapshot => _lastSnapshot;

  @override
  void start() {
    _cursor = day.cgm.length - 1;
    // Emit AFTER this frame so the Riverpod stream providers have subscribed —
    // broadcast streams don't replay to late listeners, so a synchronous emit here
    // would be missed and the UI would sit on the loading state forever.
    Timer(Duration.zero, () {
      _emitConnection(const PumpConnection(
        stage: PumpConnectionStage.connected,
        pumpName: 'Simulated t:slim X2',
      ));
      _emitSnapshotAt(_cursor);
    });
    // Re-emit periodically so IOB/age tick along; the trace itself stays stable.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _advance());
  }

  void _advance() {
    // Regenerate the day anchored to the current clock so it keeps flowing, but keep
    // the same seed so the shape is continuous rather than jumping around.
    day = SimulatedDay.generate(now: _clock());
    _cursor = day.cgm.length - 1;
    _emitSnapshotAt(_cursor);
  }

  void _emitSnapshotAt(int index) {
    final sample = day.cgm[index];
    final snapshot = PumpSnapshot(
      time: _clock(),
      batteryPercent: 78,
      reservoirUnits: 132,
      iobUnits: day.iobNow(),
      basalUnitsPerHour: day.settings.segmentAt(sample.time).basalUnitsPerHour,
      controlIqActive: true,
      closedLoopEnabled: true,
      controlIqMode: _simMode(sample.time),
      cgmMgdl: sample.mgdl.round(),
      cgmTrend: sample.trend,
      cgmTime: sample.time,
      lastBolusUnits: day.boluses.isEmpty ? null : day.boluses.last.units,
      lastBolusTime: day.boluses.isEmpty ? null : day.boluses.last.time,
      apiVersion: 'sim',
      firmwareVersion: 'sim-1.0',
    );
    _lastSnapshot = snapshot;
    _snapshots.add(snapshot);
  }

  /// Simulated Control-IQ mode: Sleep overnight (23:00–07:00), Standard otherwise, so
  /// dev mode exercises the mode-aware analytics without hardware.
  ControlIqMode _simMode(DateTime t) =>
      defaultAsleepAt(t) ? ControlIqMode.sleep : ControlIqMode.standard;

  void _emitConnection(PumpConnection c) {
    _lastConnection = c;
    _connection.add(c);
  }

  @override
  Future<void> requestStatus() async => _emitSnapshotAt(_cursor);

  @override
  Future<void> startScan({String? macFilter}) async =>
      _emitConnection(const PumpConnection(
        stage: PumpConnectionStage.connected,
        pumpName: 'Simulated t:slim X2',
      ));

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> submitPairingCode(String code, {required bool long}) async {}

  @override
  Future<void> unpair() async =>
      _emitConnection(const PumpConnection(stage: PumpConnectionStage.idle));

  @override
  Future<void> setProbeCapture(bool enabled) async => _probeCapture = enabled;

  /// Demo-mode probe: echoes the request and returns a plausible synthetic response so the
  /// Protocol Explorer is fully navigable (and integration-testable) without hardware.
  @override
  Future<String?> sendProbe(String className, {int? arg1, int? arg2}) async {
    if (!_probeCapture) return null;
    final now = _clock().millisecondsSinceEpoch;
    _probes.add(ProbeEvent(
      direction: 'tx',
      name: className,
      timestampMs: now,
      characteristic: 'CURRENT_STATUS',
      cargoHex: '',
    ));
    final responseName =
        className.endsWith('Request') ? className.replaceAll('Request', 'Response') : className;
    _probes.add(ProbeEvent(
      direction: 'rx',
      name: responseName,
      timestampMs: now + 40,
      opcode: 0,
      characteristic: 'CURRENT_STATUS',
      cargoHex: '73 69 6d',
      json: '{"simulated":true,"request":"$className"}',
      verbose: '$responseName[simulated=true]',
    ));
    return null;
  }

  @override
  Future<void> dispose() async {
    _ticker?.cancel();
    await _connection.close();
    await _snapshots.close();
    await _pairing.close();
    await _errors.close();
    await _probes.close();
  }

  @override
  Future<List<dynamic>> fetchHistory(
          {required int fromEpochMs, required int toEpochMs}) async =>
      // The simulator seeds its history directly into the store, so there is no on-device
      // pump log to backfill from — an empty result (backfill imports nothing) is correct.
      const [];
}
