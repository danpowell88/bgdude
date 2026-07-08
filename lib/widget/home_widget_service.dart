/// Pushes live pump snapshots onto the Android home-screen widget.
///
/// Thin glue over the `home_widget` plugin: every new [PumpSnapshot] is formatted
/// by the pure logic in `bg_widget_format.dart` and written into the plugin's
/// SharedPreferences store, then the native `BgWidgetProvider` is asked to
/// re-render. A periodic staleness ticker re-pushes the last snapshot so the
/// "Xm ago" line and the >15-min grey-out stay honest between CGM readings
/// while the app process is alive; the native provider additionally recomputes
/// staleness from the stored CGM epoch on every render, so system-triggered
/// renders (resize, launcher restart) are correct even without the ticker.
library;

import 'dart:async';

import 'package:home_widget/home_widget.dart';

import '../core/units.dart';
import '../logging/app_log.dart';
import '../pump/pump_snapshot.dart';
import 'bg_widget_format.dart';
import 'widget_keys.dart';

class HomeWidgetService {
  HomeWidgetService({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  PumpSnapshot? _lastSnapshot;
  GlucoseUnit _unit = GlucoseUnit.mmol;
  Timer? _ticker;

  /// Fully-qualified class name of the native provider (it lives in the
  /// `.widget` subpackage, so the plugin's default `<package>.<name>`
  /// resolution would miss it).
  static const String _qualifiedProviderName = 'com.bgdude.app.widget.BgWidgetProvider';

  // SharedPreferences keys — the single-source contract lives in WidgetKeys and is
  // asserted equal to BgWidgetProvider.kt by a contract test (TASK-111).
  static const String _keyBgText = WidgetKeys.bgText;
  static const String _keyTrend = WidgetKeys.trend;
  static const String _keyUnit = WidgetKeys.unit;
  static const String _keyIob = WidgetKeys.iob;
  static const String _keyRange = WidgetKeys.range;
  static const String _keyCgmEpochMs = WidgetKeys.cgmEpochMs;

  /// Format [snapshot] for display in [unit] and re-render the widget.
  /// Call this whenever a new pump snapshot arrives.
  Future<void> pushUpdate(PumpSnapshot snapshot, GlucoseUnit unit) async {
    _lastSnapshot = snapshot;
    _unit = unit;

    final cgmTime = snapshot.cgmTime;
    final age = cgmTime == null ? null : _now().difference(cgmTime);
    final data = formatBgWidgetData(
      cgmMgdl: snapshot.cgmMgdl,
      trend: snapshot.cgmTrend,
      iobUnits: snapshot.iobUnits,
      unit: unit,
      readingAge: age,
    );

    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>(_keyBgText, data.bgText),
        HomeWidget.saveWidgetData<String>(_keyTrend, data.trendArrow),
        HomeWidget.saveWidgetData<String>(_keyUnit, data.unitLabel),
        HomeWidget.saveWidgetData<String>(_keyIob, data.iobText),
        HomeWidget.saveWidgetData<String>(_keyRange, data.range.token),
        HomeWidget.saveWidgetData<int>(
            _keyCgmEpochMs, cgmTime?.millisecondsSinceEpoch),
      ]);
    } catch (e) {
      // TASK-208: a MissingPluginException (e.g. right after an engine restart, before
      // the plugin re-registers) must not escape onto the per-reading pump-snapshot
      // listener or the once-a-minute staleness ticker.
      appLog.error('home_widget', 'saveWidgetData failed', error: e);
      return;
    }
    await _renderWidget();
  }

  /// Re-push the last snapshot in a new display unit (call when the user
  /// toggles mg/dL ↔ mmol/L). No-op until the first snapshot arrives.
  Future<void> setUnit(GlucoseUnit unit) async {
    _unit = unit;
    final last = _lastSnapshot;
    if (last != null) await pushUpdate(last, unit);
  }

  /// TASK-238: persist just the display-unit key at app boot, independent of any
  /// snapshot. [setUnit]/[pushUpdate] only write the unit as a side effect of
  /// formatting a snapshot, so before the first one arrives the native push path
  /// (`WidgetNativePush.push`, which can run with no Flutter engine alive at all)
  /// finds no stored unit and silently falls back to mmol — misformatting an
  /// mg/dL user's very first widget render. Calling this unconditionally as soon
  /// as the service is created closes that gap.
  Future<void> seedUnit(GlucoseUnit unit) async {
    _unit = unit;
    try {
      await HomeWidget.saveWidgetData<String>(_keyUnit, unit.label);
    } catch (e) {
      appLog.error('home_widget', 'seedUnit failed', error: e);
    }
  }

  /// Re-render so the minutes-ago text and stale grey-out stay current between
  /// CGM readings. The native provider derives both from the stored epoch, so a
  /// bare render request is enough even before any snapshot has been pushed.
  Future<void> refreshStaleness() async {
    final last = _lastSnapshot;
    if (last != null) {
      await pushUpdate(last, _unit);
    } else {
      await _renderWidget();
    }
  }

  /// Start the periodic staleness refresh (idempotent; restarts the timer).
  void startStalenessTicker({Duration every = const Duration(minutes: 1)}) {
    _ticker?.cancel();
    _ticker = Timer.periodic(every, (_) => refreshStaleness());
  }

  void dispose() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _renderWidget() async {
    try {
      await HomeWidget.updateWidget(qualifiedAndroidName: _qualifiedProviderName);
    } catch (e) {
      appLog.error('home_widget', 'updateWidget failed', error: e);
    }
  }
}
