/// Repository over the encrypted store: persists and queries the domain time-series
/// (CGM, boluses, basal, carbs, health context, annotations, predictions, model runs)
/// as plain value types, so the rest of the app never touches drift rows.
///
/// An in-memory implementation ([InMemoryHistoryRepository]) backs tests and any
/// context without the native SQLCipher database (e.g. host widget tests).
library;

import '../core/units.dart';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/samples.dart';
import '../feedback/annotations.dart';
import '../logging/app_log.dart';
import 'database.dart';
import 'health_sync.dart';

/// A persisted glucose prediction, later back-filled with the actual outcome so the
/// model-accuracy view can score it.
class StoredPrediction {
  /// Glucose params arrive as raw doubles (DB columns stay `double`; the
  /// conversion to [Mgdl] happens only here in the mapping — TASK-119).
  StoredPrediction({
    required this.madeAt,
    required this.horizonMinutes,
    required double predictedMgdl,
    required double lowerMgdl,
    required double upperMgdl,
    required this.modelId,
    double? actualMgdl,
  })  : predictedMgdl = Mgdl(predictedMgdl),
        lowerMgdl = Mgdl(lowerMgdl),
        upperMgdl = Mgdl(upperMgdl),
        actualMgdl = actualMgdl == null ? null : Mgdl(actualMgdl);

  final DateTime madeAt;
  final int horizonMinutes;
  final Mgdl predictedMgdl;
  final Mgdl lowerMgdl;
  final Mgdl upperMgdl;
  final String modelId;
  final Mgdl? actualMgdl;

  DateTime get targetTime => madeAt.add(Duration(minutes: horizonMinutes));
}

/// A recorded model-training run (version history for the forecaster registry).
class ModelRunRecord {
  const ModelRunRecord({
    required this.id,
    required this.stage,
    required this.createdAt,
    required this.trainedOnDays,
    this.metricsJson = '{}',
  });
  final String id;
  final String stage;
  final DateTime createdAt;
  final int trainedOnDays;
  final String metricsJson;
}

abstract interface class HistoryRepository {
  Future<void> saveCgm(List<CgmSample> samples);
  Future<List<CgmSample>> cgm(DateTime from, DateTime to);

  Future<void> saveModelRun(ModelRunRecord run);
  Future<List<ModelRunRecord>> modelRuns();

  Future<void> saveBolus(BolusEvent bolus);
  Future<List<BolusEvent>> boluses(DateTime from, DateTime to);

  Future<void> saveCarb(CarbEntry carb);
  Future<List<CarbEntry>> carbs(DateTime from, DateTime to);

  Future<void> saveBasal(BasalSegment segment);
  Future<List<BasalSegment>> basal(DateTime from, DateTime to);

  Future<void> saveHealth(List<HealthSample> samples);
  Future<List<HealthSample>> health(DateTime from, DateTime to);

  Future<void> saveAnnotation(Annotation annotation);
  Future<List<Annotation>> annotations(DateTime from, DateTime to);

  Future<void> savePrediction(StoredPrediction prediction);
  Future<List<StoredPrediction>> predictions(DateTime from, DateTime to);

  /// Fill in the actual glucose for matured predictions whose target time has passed,
  /// using the stored CGM. Returns how many were updated.
  Future<int> reconcilePredictions(DateTime now);

  /// Prune stale rows to keep the DB lean (TASK-62): predictions older than 90 days and
  /// health samples older than 180 days. Glucose and insulin history (CGM/bolus/carb/basal)
  /// is the training corpus and is always kept. Returns the number of rows deleted.
  Future<int> pruneOldData(DateTime now);

  /// Earliest CGM timestamp on record (null when empty) — used to decide backfill.
  Future<DateTime?> earliestCgm();
}

/// drift/SQLCipher-backed implementation.
class DriftHistoryRepository implements HistoryRepository {
  DriftHistoryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> saveCgm(List<CgmSample> samples) async {
    await _db.batch((b) {
      for (final s in samples) {
        final companion = CgmReadingsCompanion.insert(
          time: s.time,
          mgdl: s.mgdl,
          trend: Value(s.trend.index),
          sensorWarmup: Value(s.sensorWarmup),
          compressionLow: Value(s.compressionLow),
          isCalibration: Value(s.isCalibration),
          source: Value(s.source.name),
        );
        // TASK-9: a sensor reading owns its time slot (the stream dedups by updating), but a
        // meter / finger-prick reading must NEVER overwrite an existing (sensor) row — on a
        // same-time collision it is ignored rather than clobbering it.
        if (s.source == GlucoseSource.sensor) {
          b.insert(
            _db.cgmReadings,
            companion,
            onConflict: DoUpdate(
              (_) => CgmReadingsCompanion(
                mgdl: Value(s.mgdl),
                trend: Value(s.trend.index),
                compressionLow: Value(s.compressionLow),
              ),
              target: [_db.cgmReadings.time],
            ),
          );
        } else {
          b.insert(_db.cgmReadings, companion,
              onConflict:
                  DoNothing<$CgmReadingsTable, CgmRow>(target: [_db.cgmReadings.time]));
        }
      }
    });
  }

  @override
  Future<List<CgmSample>> cgm(DateTime from, DateTime to) async {
    final rows = await _db.cgmBetween(from, to);
    return [
      for (final r in rows)
        CgmSample(
          time: r.time,
          mgdl: r.mgdl,
          trend: GlucoseTrend.values[r.trend.clamp(0, GlucoseTrend.values.length - 1)],
          isCalibration: r.isCalibration,
          source: GlucoseSource.fromName(r.source),
          sensorWarmup: r.sensorWarmup,
          compressionLow: r.compressionLow,
        ),
    ];
  }

  @override
  Future<void> saveBolus(BolusEvent bolus) async {
    // Upsert on the {time, units} unique key so re-reading history doesn't double-count
    // (TASK-10). The conflict target must be named explicitly — the default is the primary
    // key (id), which would never match a re-read and would throw on the unique constraint.
    await _db.into(_db.bolusEvents).insert(
          BolusEventsCompanion.insert(
            time: bolus.time,
            units: bolus.units,
            carbsGrams: Value(bolus.carbsGrams),
            isExtended: Value(bolus.isExtended),
            durationMinutes: Value(bolus.durationMinutes),
            isAutomatic: Value(bolus.isAutomatic),
          ),
          onConflict: DoUpdate(
            (_) => BolusEventsCompanion(
              carbsGrams: Value(bolus.carbsGrams),
              isExtended: Value(bolus.isExtended),
              durationMinutes: Value(bolus.durationMinutes),
              isAutomatic: Value(bolus.isAutomatic),
            ),
            target: [_db.bolusEvents.time, _db.bolusEvents.units],
          ),
        );
  }

  @override
  Future<List<BolusEvent>> boluses(DateTime from, DateTime to) async {
    final rows = await (_db.select(_db.bolusEvents)
          ..where((t) => t.time.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm(expression: t.time)]))
        .get();
    return [
      for (final r in rows)
        BolusEvent(
          time: r.time,
          units: r.units,
          carbsGrams: r.carbsGrams,
          isExtended: r.isExtended,
          durationMinutes: r.durationMinutes,
          isAutomatic: r.isAutomatic,
        ),
    ];
  }

  @override
  Future<void> saveCarb(CarbEntry carb) async {
    await _db.into(_db.carbEntries).insert(
          CarbEntriesCompanion.insert(
            time: carb.time,
            grams: carb.grams,
            absorptionMinutes: Value(carb.absorptionMinutes),
          ),
          onConflict: DoUpdate(
            (_) => CarbEntriesCompanion(
              absorptionMinutes: Value(carb.absorptionMinutes),
            ),
            target: [_db.carbEntries.time, _db.carbEntries.grams],
          ),
        );
  }

  @override
  Future<List<CarbEntry>> carbs(DateTime from, DateTime to) async {
    final rows = await (_db.select(_db.carbEntries)
          ..where((t) => t.time.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm(expression: t.time)]))
        .get();
    return [
      for (final r in rows)
        CarbEntry(
            time: r.time, grams: r.grams, absorptionMinutes: r.absorptionMinutes),
    ];
  }

  @override
  Future<void> saveBasal(BasalSegment segment) async {
    // Upsert on {start}: a re-observed segment updates its end/rate instead of duplicating.
    await _db.into(_db.basalSegments).insert(
          BasalSegmentsCompanion.insert(
            start: segment.start,
            end: segment.end,
            unitsPerHour: segment.unitsPerHour,
          ),
          onConflict: DoUpdate(
            (_) => BasalSegmentsCompanion(
              end: Value(segment.end),
              unitsPerHour: Value(segment.unitsPerHour),
            ),
            target: [_db.basalSegments.start],
          ),
        );
  }

  @override
  Future<List<BasalSegment>> basal(DateTime from, DateTime to) async {
    final rows = await (_db.select(_db.basalSegments)
          ..where((t) => t.start.isSmallerOrEqualValue(to) &
              t.end.isBiggerOrEqualValue(from))
          ..orderBy([(t) => OrderingTerm(expression: t.start)]))
        .get();
    return [
      for (final r in rows)
        BasalSegment(start: r.start, end: r.end, unitsPerHour: r.unitsPerHour),
    ];
  }

  @override
  Future<void> saveHealth(List<HealthSample> samples) async {
    await _db.batch((b) {
      for (final s in samples) {
        b.insert(
          _db.healthSamples,
          HealthSamplesCompanion.insert(
            time: s.time,
            type: s.type.dbString,
            value: s.value,
            meta: Value(jsonEncode(s.meta)),
          ),
        );
      }
    });
  }

  @override
  Future<List<HealthSample>> health(DateTime from, DateTime to) async {
    final rows = await (_db.select(_db.healthSamples)
          ..where((t) => t.time.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm(expression: t.time)]))
        .get();
    final out = <HealthSample>[];
    for (final r in rows) {
      // Rows whose type this build doesn't know (newer schema) are skipped
      // rather than guessed (TASK-118).
      final metric = HealthMetric.fromDbString(r.type);
      if (metric == null) continue;
      out.add(HealthSample(
        time: r.time,
        type: metric,
        value: r.value,
        // TASK-207: empty/non-JSON meta on one row must not abort the whole
        // range read — every other row's context (context builder, reports,
        // training features) would silently vanish along with it.
        meta: _decodeMeta(r.meta),
      ));
    }
    return out;
  }

  static Map<String, Object?> _decodeMeta(String raw) {
    try {
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (e) {
      appLog.error('persistence', 'corrupt health-sample meta — defaulting to {}',
          error: e);
      return const {};
    }
  }

  @override
  Future<void> saveAnnotation(Annotation a) async {
    await _db.into(_db.annotations).insertOnConflictUpdate(AnnotationsCompanion.insert(
          id: a.id,
          kind: a.kind.index,
          start: a.start,
          end: a.end,
          carbsGrams: Value(a.carbsGrams),
          note: Value(a.note),
          confidence: Value(a.confidence),
        ));
  }

  @override
  Future<List<Annotation>> annotations(DateTime from, DateTime to) async {
    final rows = await (_db.select(_db.annotations)
          ..where((t) => t.start.isSmallerOrEqualValue(to) &
              t.end.isBiggerOrEqualValue(from)))
        .get();
    final out = <Annotation>[];
    for (final r in rows) {
      // TASK-268: kind is persisted as a raw enum index (saveAnnotation writes
      // a.kind.index) -- an out-of-range value (an AnnotationKind removed/reordered,
      // the exact enum-drift scenario this repository already guards elsewhere, or a
      // corrupt row) must skip just that row, not abort the whole read and silently
      // drop every confirmed annotation (reports + training labels read this).
      if (r.kind < 0 || r.kind >= AnnotationKind.values.length) {
        appLog.error('persistence',
            'annotation "${r.id}" has an out-of-range kind index (${r.kind}) — skipped');
        continue;
      }
      out.add(Annotation(
        id: r.id,
        kind: AnnotationKind.values[r.kind],
        start: r.start,
        end: r.end,
        carbsGrams: r.carbsGrams,
        note: r.note,
        confidence: r.confidence,
      ));
    }
    return out;
  }

  @override
  Future<void> savePrediction(StoredPrediction p) async {
    await _db.into(_db.predictions).insert(PredictionsCompanion.insert(
          madeAt: p.madeAt,
          horizonMinutes: p.horizonMinutes,
          predictedMgdl: p.predictedMgdl,
          lowerMgdl: p.lowerMgdl,
          upperMgdl: p.upperMgdl,
          actualMgdl: Value(p.actualMgdl),
          modelId: Value(p.modelId),
        ));
  }

  @override
  Future<List<StoredPrediction>> predictions(DateTime from, DateTime to) async {
    final rows = await (_db.select(_db.predictions)
          ..where((t) => t.madeAt.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm(expression: t.madeAt)]))
        .get();
    return [
      for (final r in rows)
        StoredPrediction(
          madeAt: r.madeAt,
          horizonMinutes: r.horizonMinutes,
          predictedMgdl: r.predictedMgdl,
          lowerMgdl: r.lowerMgdl,
          upperMgdl: r.upperMgdl,
          modelId: r.modelId,
          actualMgdl: r.actualMgdl,
        ),
    ];
  }

  @override
  Future<int> reconcilePredictions(DateTime now) async {
    const window = Duration(minutes: 5);
    final pending = await (_db.select(_db.predictions)
          ..where((t) => t.actualMgdl.isNull()))
        .get();
    // Only predictions whose target time has passed can be scored.
    final due = [
      for (final r in pending)
        if (!r.madeAt.add(Duration(minutes: r.horizonMinutes)).isAfter(now)) r,
    ];
    if (due.isEmpty) return 0;

    // TASK-42: one CGM query spanning every due target (± the match window), instead of a
    // per-row query, then match each prediction to the nearest reading in memory.
    var lo = due.first.madeAt.add(Duration(minutes: due.first.horizonMinutes));
    var hi = lo;
    for (final r in due) {
      final t = r.madeAt.add(Duration(minutes: r.horizonMinutes));
      if (t.isBefore(lo)) lo = t;
      if (t.isAfter(hi)) hi = t;
    }
    // TASK-133: only CONFIRMED readings can be ground truth — warm-up rows,
    // compression-low artifacts and non-positive values are exactly what
    // training labels exclude; scoring against them pollutes accuracy reports
    // and the live-RMSE recalibration behind the alert bands.
    final cgm = [
      for (final s in await _db.cgmBetween(lo.subtract(window), hi.add(window)))
        if (!s.sensorWarmup && !s.compressionLow && s.mgdl > 0) s,
    ];
    if (cgm.isEmpty) return 0;

    var updated = 0;
    await _db.batch((b) {
      for (final r in due) {
        final target = r.madeAt.add(Duration(minutes: r.horizonMinutes));
        CgmRow? best;
        var bestDiff = window + const Duration(seconds: 1);
        for (final s in cgm) {
          final d = s.time.difference(target).abs();
          if (d <= window && d < bestDiff) {
            best = s;
            bestDiff = d;
          }
        }
        if (best == null) continue;
        b.update(
          _db.predictions,
          PredictionsCompanion(actualMgdl: Value(best.mgdl)),
          where: (t) => t.id.equals(r.id),
        );
        updated++;
      }
    });
    return updated;
  }

  @override
  Future<int> pruneOldData(DateTime now) async {
    final predCutoff = now.subtract(const Duration(days: 90));
    final healthCutoff = now.subtract(const Duration(days: 180));
    final prunedPredictions = await (_db.delete(_db.predictions)
          ..where((t) => t.madeAt.isSmallerThanValue(predCutoff)))
        .go();
    final prunedHealth = await (_db.delete(_db.healthSamples)
          ..where((t) => t.time.isSmallerThanValue(healthCutoff)))
        .go();
    return prunedPredictions + prunedHealth;
  }

  @override
  Future<DateTime?> earliestCgm() async {
    final row = await (_db.select(_db.cgmReadings)
          ..orderBy([(t) => OrderingTerm(expression: t.time)])
          ..limit(1))
        .getSingleOrNull();
    return row?.time;
  }

  @override
  Future<void> saveModelRun(ModelRunRecord run) => _db.saveModelRunRow(
        ModelRunsCompanion.insert(
          id: run.id,
          stage: run.stage,
          createdAt: run.createdAt,
          trainedOnDays: run.trainedOnDays,
          metricsJson: Value(run.metricsJson),
        ),
      );

  @override
  Future<List<ModelRunRecord>> modelRuns() async {
    final rows = await _db.allModelRuns();
    return [
      for (final r in rows)
        ModelRunRecord(
          id: r.id,
          stage: r.stage,
          createdAt: r.createdAt,
          trainedOnDays: r.trainedOnDays,
          metricsJson: r.metricsJson,
        ),
    ];
  }
}

/// In-memory repository for tests and DB-less contexts. Same contract, no persistence
/// across launches.
class InMemoryHistoryRepository implements HistoryRepository {
  final List<CgmSample> _cgm = [];
  final List<ModelRunRecord> _modelRuns = [];
  final List<BolusEvent> _boluses = [];
  final List<CarbEntry> _carbs = [];
  final List<BasalSegment> _basal = [];
  final List<HealthSample> _health = [];
  final Map<String, Annotation> _annotations = {};
  final List<StoredPrediction> _predictions = [];

  List<T> _between<T>(List<T> src, DateTime from, DateTime to, DateTime Function(T) time) =>
      [for (final e in src) if (!time(e).isBefore(from) && !time(e).isAfter(to)) e]
        ..sort((a, b) => time(a).compareTo(time(b)));

  @override
  Future<void> saveCgm(List<CgmSample> samples) async {
    final times = {for (final s in _cgm) s.time.millisecondsSinceEpoch};
    for (final s in samples) {
      if (times.add(s.time.millisecondsSinceEpoch)) _cgm.add(s);
    }
  }

  @override
  Future<List<CgmSample>> cgm(DateTime from, DateTime to) async =>
      _between(_cgm, from, to, (s) => s.time);

  @override
  Future<void> saveBolus(BolusEvent bolus) async {
    // Mirror the Drift {time, units} dedup so tests see the same idempotence (TASK-10).
    _boluses.removeWhere((b) => b.time == bolus.time && b.units == bolus.units);
    _boluses.add(bolus);
  }

  @override
  Future<List<BolusEvent>> boluses(DateTime from, DateTime to) async =>
      _between(_boluses, from, to, (b) => b.time);

  @override
  Future<void> saveCarb(CarbEntry carb) async {
    _carbs.removeWhere((c) => c.time == carb.time && c.grams == carb.grams);
    _carbs.add(carb);
  }
  @override
  Future<List<CarbEntry>> carbs(DateTime from, DateTime to) async =>
      _between(_carbs, from, to, (c) => c.time);

  @override
  Future<void> saveBasal(BasalSegment segment) async {
    _basal.removeWhere((s) => s.start == segment.start);
    _basal.add(segment);
  }
  @override
  Future<List<BasalSegment>> basal(DateTime from, DateTime to) async => [
        for (final s in _basal)
          if (!s.start.isAfter(to) && !s.end.isBefore(from)) s,
      ];

  @override
  Future<void> saveHealth(List<HealthSample> samples) async =>
      _health.addAll(samples);
  @override
  Future<List<HealthSample>> health(DateTime from, DateTime to) async =>
      _between(_health, from, to, (s) => s.time);

  @override
  Future<void> saveAnnotation(Annotation annotation) async =>
      _annotations[annotation.id] = annotation;
  @override
  Future<List<Annotation>> annotations(DateTime from, DateTime to) async => [
        for (final a in _annotations.values)
          if (!a.start.isAfter(to) && !a.end.isBefore(from)) a,
      ];

  @override
  Future<void> savePrediction(StoredPrediction prediction) async =>
      _predictions.add(prediction);
  @override
  Future<List<StoredPrediction>> predictions(DateTime from, DateTime to) async =>
      _between(_predictions, from, to, (p) => p.madeAt);

  @override
  Future<int> reconcilePredictions(DateTime now) async {
    var updated = 0;
    for (var i = 0; i < _predictions.length; i++) {
      final p = _predictions[i];
      if (p.actualMgdl != null || p.targetTime.isAfter(now)) continue;
      // TASK-133: mirror the drift implementation — artifacts are never truth.
      final near = _between(
              _cgm,
              p.targetTime.subtract(const Duration(minutes: 5)),
              p.targetTime.add(const Duration(minutes: 5)),
              (s) => s.time)
          .where((s) => !s.sensorWarmup && !s.compressionLow && s.mgdl > 0)
          .toList();
      if (near.isEmpty) continue;
      final actual = near
          .reduce((a, b) => a.time.difference(p.targetTime).abs() <
                  b.time.difference(p.targetTime).abs()
              ? a
              : b)
          .mgdl;
      _predictions[i] = StoredPrediction(
        madeAt: p.madeAt,
        horizonMinutes: p.horizonMinutes,
        predictedMgdl: p.predictedMgdl,
        lowerMgdl: p.lowerMgdl,
        upperMgdl: p.upperMgdl,
        modelId: p.modelId,
        actualMgdl: actual,
      );
      updated++;
    }
    return updated;
  }

  @override
  Future<int> pruneOldData(DateTime now) async {
    final predCutoff = now.subtract(const Duration(days: 90));
    final healthCutoff = now.subtract(const Duration(days: 180));
    final before = _predictions.length + _health.length;
    _predictions.removeWhere((p) => p.madeAt.isBefore(predCutoff));
    _health.removeWhere((h) => h.time.isBefore(healthCutoff));
    return before - (_predictions.length + _health.length);
  }

  @override
  Future<DateTime?> earliestCgm() async {
    if (_cgm.isEmpty) return null;
    return _cgm.map((s) => s.time).reduce((a, b) => a.isBefore(b) ? a : b);
  }

  @override
  Future<void> saveModelRun(ModelRunRecord run) async => _modelRuns.add(run);

  @override
  Future<List<ModelRunRecord>> modelRuns() async =>
      [..._modelRuns]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Synchronously bulk-load data (demo seeding / tests) without awaiting a series of
  /// single-item saves.
  void seed({
    List<CgmSample> cgm = const [],
    List<BolusEvent> boluses = const [],
    List<CarbEntry> carbs = const [],
    List<BasalSegment> basal = const [],
    List<HealthSample> health = const [],
    List<Annotation> annotations = const [],
    List<StoredPrediction> predictions = const [],
  }) {
    _cgm.addAll(cgm);
    _boluses.addAll(boluses);
    _carbs.addAll(carbs);
    _basal.addAll(basal);
    _health.addAll(health);
    for (final a in annotations) {
      _annotations[a.id] = a;
    }
    _predictions.addAll(predictions);
  }
}
