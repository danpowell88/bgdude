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
import '../pump/pump_snapshot.dart';
import 'bg_widget_format.dart';

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

  // SharedPreferences keys — must match BgWidgetProvider.kt.
  static const String _keyBgText = 'bg_text';
  static const String _keyTrend = 'bg_trend';
  static const String _keyUnit = 'bg_unit';
  static const String _keyIob = 'iob_text';
  static const String _keyRange = 'bg_range';
  static const String _keyCgmEpochMs = 'cgm_epoch_ms';

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

    await Future.wait([
      HomeWidget.saveWidgetData<String>(_keyBgText, data.bgText),
      HomeWidget.saveWidgetData<String>(_keyTrend, data.trendArrow),
      HomeWidget.saveWidgetData<String>(_keyUnit, data.unitLabel),
      HomeWidget.saveWidgetData<String>(_keyIob, data.iobText),
      HomeWidget.saveWidgetData<String>(_keyRange, data.range.token),
      HomeWidget.saveWidgetData<int>(
          _keyCgmEpochMs, cgmTime?.millisecondsSinceEpoch),
    ]);
    await _renderWidget();
  }

  /// Re-push the last snapshot in a new display unit (call when the user
  /// toggles mg/dL ↔ mmol/L). No-op until the first snapshot arrives.
  Future<void> setUnit(GlucoseUnit unit) async {
    _unit = unit;
    final last = _lastSnapshot;
    if (last != null) await pushUpdate(last, unit);
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

  Future<void> _renderWidget() =>
      HomeWidget.updateWidget(qualifiedAndroidName: _qualifiedProviderName);
}
