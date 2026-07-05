/// Backfills historical pump data (boluses, carbs, CGM, basal changes) from the pump's
/// on-device History Log into the encrypted store, so metrics and model training have
/// material from day one rather than only accruing forward.
///
/// The native side (`fetchHistory`) streams decoded entries; pumpx2's history decoding
/// is partial, so this is best-effort — undecodable entries are skipped. Entries are
/// deduped by the repository (CGM by timestamp) and by a persisted high-water mark so a
/// re-run doesn't double-insert boluses/carbs.
library;

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../core/samples.dart';
import '../data/history_repository.dart';
import '../data/kv_store.dart';
import '../logging/device_changes.dart';
import 'pump_events.dart';

class HistoryBackfillService {
  HistoryBackfillService(this._repo, {MethodChannel? commands})
      : _commands = commands ?? const MethodChannel('bgdude/pump_commands');

  final HistoryRepository _repo;
  final MethodChannel _commands;
  final _log = Logger('HistoryBackfill');
  static const _hwmKey = 'history_backfill_hwm_ms';

  /// Fetch and persist history in [from, to). Returns the number of entries imported.
  /// Only fetches entries newer than the stored high-water mark unless [force].
  ///
  /// [onDeviceChange] is invoked for infusion-site changes decoded from the log (so site
  /// age tracks reality without manual logging); [onPumpEvent] for alarms/alerts and
  /// cartridge changes (the Pump screen's timeline).
  Future<int> backfill({
    required DateTime from,
    required DateTime to,
    bool force = false,
    void Function(DeviceKind kind, DateTime at)? onDeviceChange,
    void Function(PumpEvent event)? onPumpEvent,
  }) async {
    final hwm = force ? 0 : ((await KvStore.getDouble(_hwmKey))?.toInt() ?? 0);
    final effectiveFrom = DateTime.fromMillisecondsSinceEpoch(
        hwm > from.millisecondsSinceEpoch ? hwm : from.millisecondsSinceEpoch);

    final List<dynamic> raw;
    try {
      raw = await _commands.invokeMethod<List<dynamic>>('fetchHistory', {
            'fromEpochMs': effectiveFrom.millisecondsSinceEpoch,
            'toEpochMs': to.millisecondsSinceEpoch,
          }) ??
          const [];
    } on MissingPluginException {
      return 0; // command not wired (e.g. simulator/tests)
    } on PlatformException catch (e) {
      _log.warning('fetchHistory failed', e);
      return 0;
    }

    var imported = 0;
    var maxEpoch = hwm;
    final cgm = <CgmSample>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final m = entry.cast<Object?, Object?>();
      final epoch = (m['epochMs'] as num?)?.toInt();
      if (epoch == null) continue;
      final time = DateTime.fromMillisecondsSinceEpoch(epoch);
      switch (m['type']) {
        case 'bolus':
          await _repo.saveBolus(BolusEvent(
            time: time,
            units: (m['units'] as num?)?.toDouble() ?? 0,
            carbsGrams: (m['carbsGrams'] as num?)?.toDouble() ?? 0,
          ));
          imported++;
        case 'carb':
          await _repo.saveCarb(CarbEntry(
              time: time, grams: (m['carbsGrams'] as num?)?.toDouble() ?? 0));
          imported++;
        case 'cgm':
          final mgdl = (m['mgdl'] as num?)?.toDouble();
          if (mgdl != null) {
            cgm.add(CgmSample(time: time, mgdl: mgdl));
            imported++;
          }
        case 'basalChange':
          final rate = (m['units'] as num?)?.toDouble();
          if (rate != null) {
            await _repo.saveBasal(BasalSegment(
                start: time,
                end: time.add(const Duration(minutes: 30)),
                unitsPerHour: rate));
            imported++;
          }
        case 'cannulaFilled':
          onDeviceChange?.call(DeviceKind.site, time);
          onPumpEvent?.call(PumpEvent(
              time: time, kind: PumpEventKind.cannulaChange, detail: 'Cannula filled'));
          imported++;
        case 'cartridgeFilled':
          onPumpEvent?.call(PumpEvent(
              time: time,
              kind: PumpEventKind.cartridgeChange,
              detail: 'Cartridge filled'));
          imported++;
        case 'alarm':
          onPumpEvent?.call(PumpEvent(
              time: time,
              kind: PumpEventKind.alarm,
              detail: (m['name'] as String?) ?? 'Alarm'));
          imported++;
        case 'alert':
          onPumpEvent?.call(PumpEvent(
              time: time,
              kind: PumpEventKind.alert,
              detail: (m['name'] as String?) ?? 'Alert'));
          imported++;
        default:
          break; // unknown/undecodable — skip
      }
      if (epoch > maxEpoch) maxEpoch = epoch;
    }
    if (cgm.isNotEmpty) await _repo.saveCgm(cgm);

    if (maxEpoch > hwm) await KvStore.setDouble(_hwmKey, maxEpoch.toDouble());
    _log.info('backfilled $imported history entries');
    return imported;
  }
}
