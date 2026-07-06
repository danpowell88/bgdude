/// Owns "today's" [DayData], assembled from the encrypted history repository and kept
/// live as pump snapshots arrive. This is the single source of truth for the timeline,
/// analytics and predictions — sync to read (StateNotifier state), async to load/persist
/// underneath.
///
/// Dev mode seeds the repository from the simulator so history-dependent features
/// (training, meal-outcome learning, model accuracy) have material to work with, and the
/// UI shows a rich day immediately.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/basal_reconstruction.dart';
import '../analytics/context_builder.dart';
import '../analytics/therapy_settings.dart';
import '../core/samples.dart';
import '../data/history_repository.dart';
import '../dev/sim_data.dart';
import '../pump/pump_snapshot.dart';
import 'day_data.dart';

class DayHistoryController extends StateNotifier<DayData> {
  DayHistoryController({
    required HistoryRepository repo,
    required TherapySettings settings,
    SimulatedDay? sim,
    DateTime Function()? clock,
  })  : _repo = repo,
        _clock = clock ?? DateTime.now,
        _settings = settings,
        super(sim != null ? _fromSim(sim) : DayData.empty(settings)) {
    if (sim != null) {
      _seedFromSim(sim);
    } else {
      reload();
    }
  }

  final HistoryRepository _repo;
  final DateTime Function() _clock;
  final TherapySettings _settings;
  DateTime? _lastBolusTime;

  // Live basal reconstruction: accumulate rate observations, rebuild segments, and
  // persist a segment whenever the rate changes. Capped (§3.J) so a long session can't
  // grow it without bound — the persisted segments hold the full history; this only
  // feeds the in-session reconstruction (~24 h at 5-min CGM cadence).
  static const int _maxBasalObs = 288;
  final List<({DateTime time, double unitsPerHour})> _basalObs = [];
  double? _openBasalRate;
  DateTime? _openBasalStart;

  static DayData _fromSim(SimulatedDay sim) => DayData(
        start: sim.start,
        end: sim.end,
        cgm: sim.cgm,
        boluses: sim.boluses,
        basal: sim.basal,
        carbs: sim.carbs,
        settings: sim.settings,
        context: sim.context,
        isSimulated: true,
      );

  Future<void> _seedFromSim(SimulatedDay sim) async {
    // Persist the simulated day (idempotent on CGM by timestamp) so jobs can read it.
    if (await _repo.earliestCgm() == null) {
      await _repo.saveCgm(sim.cgm);
      for (final b in sim.boluses) {
        await _repo.saveBolus(b);
      }
      for (final c in sim.carbs) {
        await _repo.saveCarb(c);
      }
      for (final seg in sim.basal) {
        await _repo.saveBasal(seg);
      }
    }
  }

  /// Reload today's window from the repository (real mode).
  Future<void> reload() async {
    final now = _clock();
    final from = now.subtract(const Duration(hours: 24));
    final cgm = await _repo.cgm(from, now);
    if (cgm.isEmpty && state.isSimulated) return; // keep sim state
    final boluses = await _repo.boluses(from, now);
    final carbs = await _repo.carbs(from, now);
    final basal = await _repo.basal(from, now);

    final todayHealth = await _repo.health(from, now);
    final baselineHealth =
        await _repo.health(now.subtract(const Duration(days: 14)), now);
    final context =
        ContextBuilder.build(today: todayHealth, baseline: baselineHealth);

    state = DayData(
      start: from,
      end: now,
      cgm: cgm,
      boluses: boluses,
      basal: basal,
      carbs: carbs,
      settings: _settings,
      context: context,
      isSimulated: false,
    );
    if (boluses.isNotEmpty) _lastBolusTime = boluses.last.time;
  }

  /// Ingest a live pump snapshot: persist the CGM reading (and any newly-seen bolus)
  /// and append to today's data so the UI updates immediately.
  Future<void> ingestSnapshot(PumpSnapshot snapshot) async {
    if (state.isSimulated) return; // dev mode drives itself
    final sample = snapshot.toCgmSample();
    if (sample == null) return;

    // Dedup by timestamp.
    if (state.cgm.isNotEmpty && state.cgm.last.time == sample.time) return;

    await _repo.saveCgm([sample]);

    // Persist a newly-observed last bolus. On a fresh start _lastBolusTime is null, and the
    // first snapshot reports the pump's last bolus — which was already saved before the
    // restart. Seed _lastBolusTime from persisted history first so we don't re-insert it
    // (restart race, TASK-10); the {time, units} upsert is the backstop.
    final lb = snapshot.lastBolusTime;
    if (lb != null && snapshot.lastBolusUnits != null) {
      if (_lastBolusTime == null) {
        final now = _clock();
        final recent = await _repo.boluses(now.subtract(const Duration(days: 2)), now);
        if (recent.isNotEmpty) _lastBolusTime = recent.last.time;
      }
      if (lb != _lastBolusTime) {
        _lastBolusTime = lb;
        await _repo.saveBolus(BolusEvent(time: lb, units: snapshot.lastBolusUnits!));
      }
    }

    // Reconstruct basal from the reported rate.
    final rate = snapshot.basalUnitsPerHour;
    if (rate != null) {
      _basalObs.add((time: sample.time, unitsPerHour: rate));
      if (_basalObs.length > _maxBasalObs) {
        _basalObs.removeRange(0, _basalObs.length - _maxBasalObs);
      }
      if (_openBasalRate == null) {
        _openBasalRate = rate;
        _openBasalStart = sample.time;
      } else if ((_openBasalRate! - rate).abs() > 1e-6) {
        // Rate changed: close and persist the previous segment.
        await _repo.saveBasal(BasalSegment(
          start: _openBasalStart!,
          end: sample.time,
          unitsPerHour: _openBasalRate!,
        ));
        _openBasalRate = rate;
        _openBasalStart = sample.time;
      }
    }
    final basal =
        const BasalReconstructor().reconstruct(_basalObs, until: sample.time);

    final cgm = [...state.cgm, sample];
    state = DayData(
      start: state.start,
      end: sample.time,
      cgm: cgm,
      boluses: state.boluses,
      basal: basal.isEmpty ? state.basal : basal,
      carbs: state.carbs,
      settings: state.settings,
      context: state.context,
      isSimulated: false,
    );
  }

  /// Log a user carb entry (and persist it), reflecting it in today's data.
  Future<void> logCarb(CarbEntry carb) async {
    await _repo.saveCarb(carb);
    if (state.isSimulated) return;
    state = DayData(
      start: state.start,
      end: state.end,
      cgm: state.cgm,
      boluses: state.boluses,
      basal: state.basal,
      carbs: [...state.carbs, carb],
      settings: state.settings,
      context: state.context,
      isSimulated: false,
    );
  }

  /// Log a bolus the user actually delivered on the pump (improves IOB accuracy).
  Future<void> logBolus(BolusEvent bolus) async {
    await _repo.saveBolus(bolus);
    if (state.isSimulated) return;
    state = DayData(
      start: state.start,
      end: state.end,
      cgm: state.cgm,
      boluses: [...state.boluses, bolus],
      basal: state.basal,
      carbs: state.carbs,
      settings: state.settings,
      context: state.context,
      isSimulated: false,
    );
  }
}
