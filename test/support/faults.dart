/// Shared, hand-written fault-injecting test doubles.
///
/// Every key dependency in the app is already injectable (a provider override or a
/// constructor seam), but before this file the only throwing double in the suite was a
/// one-off in `food_database_test.dart` — no faulty repository/notifier/pump-source/health
/// double existed, so none of the critical failure paths (alert loop, snapshot chain,
/// runStartup, ...) could be exercised without writing an ad-hoc double per test. These are
/// deliberately hand-written (no mocking framework), matching the rest of this test suite.
library;

import 'dart:async';

import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/units.dart';
import 'package:bgdude/data/health_sync.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/insights/alarm_fatigue.dart';
import 'package:bgdude/pump/probe_event.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/pump/pump_source.dart';

/// Wraps an (in-memory, by default) [HistoryRepository] and lets a test make individual
/// methods throw — either forever ([failOn]) or exactly once ([throwOnce]) — so a
/// failure-injection test can assert the caller degrades correctly while every other
/// method keeps working normally against the same underlying store.
class FaultInjectingHistoryRepository implements HistoryRepository {
  FaultInjectingHistoryRepository([HistoryRepository? delegate])
      : _delegate = delegate ?? InMemoryHistoryRepository();

  final HistoryRepository _delegate;
  final Set<String> _failing = {};
  final Set<String> _throwOnce = {};

  /// Make [method] throw on every call from now on.
  void failOn(String method) => _failing.add(method);

  /// Clear a previously-set [failOn] for [method].
  void clearFailOn(String method) => _failing.remove(method);

  /// Make [method] throw exactly once, then behave normally again.
  void throwOnce(String method) => _throwOnce.add(method);

  void _maybeThrow(String method) {
    if (_throwOnce.remove(method)) {
      throw StateError('$method: injected single failure');
    }
    if (_failing.contains(method)) {
      throw StateError('$method: injected failure');
    }
  }

  @override
  Future<void> saveCgm(List<CgmSample> samples) async {
    _maybeThrow('saveCgm');
    return _delegate.saveCgm(samples);
  }

  @override
  Future<void> saveAlertEvent(AlertEvent event) async {
    _maybeThrow('saveAlertEvent');
    return _delegate.saveAlertEvent(event);
  }

  @override
  Future<List<AlertEvent>> alertEvents(DateTime from, DateTime to) async {
    _maybeThrow('alertEvents');
    return _delegate.alertEvents(from, to);
  }

  @override
  Future<List<CgmSample>> cgm(DateTime from, DateTime to) async {
    _maybeThrow('cgm');
    return _delegate.cgm(from, to);
  }

  @override
  Future<void> saveModelRun(ModelRunRecord run) async {
    _maybeThrow('saveModelRun');
    return _delegate.saveModelRun(run);
  }

  @override
  Future<List<ModelRunRecord>> modelRuns() async {
    _maybeThrow('modelRuns');
    return _delegate.modelRuns();
  }

  @override
  Future<void> saveBolus(BolusEvent bolus) async {
    _maybeThrow('saveBolus');
    return _delegate.saveBolus(bolus);
  }

  @override
  Future<List<BolusEvent>> boluses(DateTime from, DateTime to) async {
    _maybeThrow('boluses');
    return _delegate.boluses(from, to);
  }

  @override
  Future<void> saveCarb(CarbEntry carb) async {
    _maybeThrow('saveCarb');
    return _delegate.saveCarb(carb);
  }

  @override
  Future<List<CarbEntry>> carbs(DateTime from, DateTime to) async {
    _maybeThrow('carbs');
    return _delegate.carbs(from, to);
  }

  @override
  Future<void> saveBasal(BasalSegment segment) async {
    _maybeThrow('saveBasal');
    return _delegate.saveBasal(segment);
  }

  @override
  Future<List<BasalSegment>> basal(DateTime from, DateTime to) async {
    _maybeThrow('basal');
    return _delegate.basal(from, to);
  }

  @override
  Future<void> saveHealth(List<HealthSample> samples) async {
    _maybeThrow('saveHealth');
    return _delegate.saveHealth(samples);
  }

  @override
  Future<List<HealthSample>> health(DateTime from, DateTime to) async {
    _maybeThrow('health');
    return _delegate.health(from, to);
  }

  @override
  Future<void> saveAnnotation(Annotation annotation) async {
    _maybeThrow('saveAnnotation');
    return _delegate.saveAnnotation(annotation);
  }

  @override
  Future<List<Annotation>> annotations(DateTime from, DateTime to) async {
    _maybeThrow('annotations');
    return _delegate.annotations(from, to);
  }

  @override
  Future<void> savePrediction(StoredPrediction prediction) async {
    _maybeThrow('savePrediction');
    return _delegate.savePrediction(prediction);
  }

  @override
  Future<List<StoredPrediction>> predictions(DateTime from, DateTime to) async {
    _maybeThrow('predictions');
    return _delegate.predictions(from, to);
  }

  @override
  Future<int> reconcilePredictions(DateTime now) async {
    _maybeThrow('reconcilePredictions');
    return _delegate.reconcilePredictions(now);
  }

  @override
  Future<int> pruneOldData(DateTime now) async {
    _maybeThrow('pruneOldData');
    return _delegate.pruneOldData(now);
  }

  @override
  Future<DateTime?> earliestCgm() async {
    _maybeThrow('earliestCgm');
    return _delegate.earliestCgm();
  }
}

/// Records every category it was asked to show, and throws instead of actually showing
/// one while [shouldThrow] is true (on by default) — so a caller's failure-handling path
/// (log-and-continue, not crash the alert loop) can be exercised without a real platform
/// channel. Never touches the real `FlutterLocalNotificationsPlugin` since [show] returns
/// before the superclass implementation would.
class ThrowingNotificationService extends NotificationService {
  final List<NotificationCategory> shown = [];
  bool shouldThrow = true;

  @override
  Future<bool> show(
    NotificationCategory category,
    String title,
    String body, {
    int? id,
    bool bigText = false,
  }) async {
    shown.add(category);
    if (shouldThrow) throw StateError('show: injected failure ($category)');
    return true;
  }
}

/// TASK-261: a safe default for tests that don't care whether a notification fires
/// but exercise a code path that calls NotificationService.show() as a side effect
/// (e.g. mode auto-expiry) -- the real NotificationService touches
/// FlutterLocalNotificationsPlugin's platform channel, which throws
/// MissingPluginException with no native implementation registered in a plain unit
/// test. Records what it was asked to show, same as [ThrowingNotificationService],
/// for a test that DOES want to assert a notification fired without caring about
/// failure-injection.
class NoopNotificationService extends NotificationService {
  final List<NotificationCategory> shown = [];

  @override
  Future<bool> show(
    NotificationCategory category,
    String title,
    String body, {
    int? id,
    bool bigText = false,
  }) async {
    shown.add(category);
    return true;
  }
}

/// A [PumpSource] whose command methods throw on demand (see [failOn]) and whose streams
/// are driven manually via [emitConnection]/[emitSnapshot]/[emitError] — for tests that
/// need to inject a pump-command failure without a real native bridge.
class ErroringPumpSource implements PumpSource {
  final _connectionCtrl = StreamController<PumpConnection>.broadcast();
  final _snapshotCtrl = StreamController<PumpSnapshot>.broadcast();
  final _pairingCtrl = StreamController<String>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();
  final _profileCtrl = StreamController<String>.broadcast();
  final _probeCtrl = StreamController<ProbeEvent>.broadcast();

  @override
  Stream<PumpConnection> get connection => _connectionCtrl.stream;
  @override
  Stream<PumpSnapshot> get snapshots => _snapshotCtrl.stream;
  @override
  Stream<String> get pairingRequests => _pairingCtrl.stream;
  @override
  Stream<String> get errors => _errorCtrl.stream;
  @override
  Stream<String> get therapyProfiles => _profileCtrl.stream;
  @override
  Stream<ProbeEvent> get probeEvents => _probeCtrl.stream;

  @override
  PumpConnection lastConnection = PumpConnection.idle;
  @override
  PumpSnapshot? lastSnapshot;

  void emitConnection(PumpConnection c) {
    lastConnection = c;
    _connectionCtrl.add(c);
  }

  void emitSnapshot(PumpSnapshot s) {
    lastSnapshot = s;
    _snapshotCtrl.add(s);
  }

  void emitError(String message) => _errorCtrl.add(message);
  void emitPairingRequest(String type) => _pairingCtrl.add(type);
  void emitTherapyProfile(String json) => _profileCtrl.add(json);

  /// Method names in here throw `StateError` when called; every other command is a
  /// silent no-op success, matching a healthy connection.
  final Set<String> failing = {};

  void failOn(String method) => failing.add(method);

  void _maybeThrow(String method) {
    if (failing.contains(method)) {
      throw StateError('$method: injected failure');
    }
  }

  @override
  void start() {}

  @override
  Future<void> dispose() async {
    await _connectionCtrl.close();
    await _snapshotCtrl.close();
    await _pairingCtrl.close();
    await _errorCtrl.close();
    await _profileCtrl.close();
    await _probeCtrl.close();
  }

  @override
  Future<void> startScan({String? macFilter}) async => _maybeThrow('startScan');

  @override
  Future<void> stopScan() async => _maybeThrow('stopScan');

  @override
  Future<void> requestStatus() async => _maybeThrow('requestStatus');

  @override
  Future<void> submitPairingCode(String code, {required bool long}) async =>
      _maybeThrow('submitPairingCode');

  @override
  Future<void> unpair() async => _maybeThrow('unpair');

  @override
  Future<void> setProbeCapture(bool enabled) async => _maybeThrow('setProbeCapture');

  @override
  Future<String?> sendProbe(String className, {int? arg1, int? arg2}) async {
    _maybeThrow('sendProbe');
    return null;
  }

  @override
  Future<List<dynamic>> fetchHistory(
      {required int fromEpochMs, required int toEpochMs}) async {
    _maybeThrow('fetchHistory');
    return const [];
  }

  @override
  Future<void> setGarminUnit(GlucoseUnit unit) async => _maybeThrow('setGarminUnit');

  @override
  Future<Map<String, dynamic>?> garminHealth() async {
    _maybeThrow('garminHealth');
    return null;
  }
}

/// A [HealthSyncService] whose `fetch`/`requestPermissions` throw on demand — for tests
/// exercising `AppJobs.syncHealth()`'s (or `runStartup`'s) failure-handling path without a
/// real Health Connect plugin call.
class ThrowingHealthSyncService extends HealthSyncService {
  bool failFetch = true;
  bool failPermissions = false;

  @override
  Future<bool> requestPermissions() async {
    if (failPermissions) throw StateError('requestPermissions: injected failure');
    return true;
  }

  @override
  Future<List<HealthSample>> fetch(DateTime from, DateTime to) async {
    if (failFetch) throw StateError('fetch: injected failure');
    return const [];
  }
}
