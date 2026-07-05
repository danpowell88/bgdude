/// Repository over the encrypted store: persists and queries the domain time-series
/// (CGM, boluses, basal, carbs, health context, annotations, predictions, model runs)
/// as plain value types, so the rest of the app never touches drift rows.
///
/// An in-memory implementation ([InMemoryHistoryRepository]) backs tests and any
/// context without the native SQLCipher database (e.g. host widget tests).
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/samples.dart';
import '../feedback/annotations.dart';
import 'database.dart';
import 'health_sync.dart';

/// A persisted glucose prediction, later back-filled with the actual outcome so the
/// model-accuracy view can score it.
class StoredPrediction {
  const StoredPrediction({
    required this.madeAt,
    required this.horizonMinutes,
    required this.predictedMgdl,
    required this.lowerMgdl,
    required this.upperMgdl,
    required this.modelId,
    this.actualMgdl,
  });

  final DateTime madeAt;
  final int horizonMinutes;
  final double predictedMgdl;
  final double lowerMgdl;
  final double upperMgdl;
  final String modelId;
  final double? actualMgdl;

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
        b.insert(
          _db.cgmReadings,
          CgmReadingsCompanion.insert(
            time: s.time,
            mgdl: s.mgdl,
            trend: Value(s.trend.index),
            sensorWarmup: Value(s.sensorWarmup),
            compressionLow: Value(s.compressionLow),
          ),
          onConflict: DoUpdate(
            (_) => CgmReadingsCompanion(
              mgdl: Value(s.mgdl),
              trend: Value(s.trend.index),
              compressionLow: Value(s.compressionLow),
            ),
            target: [_db.cgmReadings.time],
          ),
        );
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
          sensorWarmup: r.sensorWarmup,
          compressionLow: r.compressionLow,
        ),
    ];
  }

  @override
  Future<void> saveBolus(BolusEvent bolus) async {
    await _db.into(_db.bolusEvents).insert(BolusEventsCompanion.insert(
          time: bolus.time,
          units: bolus.units,
          carbsGrams: Value(bolus.carbsGrams),
          isExtended: Value(bolus.isExtended),
          durationMinutes: Value(bolus.durationMinutes),
          isAutomatic: Value(bolus.isAutomatic),
        ));
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
    await _db.into(_db.carbEntries).insert(CarbEntriesCompanion.insert(
          time: carb.time,
          grams: carb.grams,
          absorptionMinutes: Value(carb.absorptionMinutes),
        ));
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
    await _db.into(_db.basalSegments).insert(BasalSegmentsCompanion.insert(
          start: segment.start,
          end: segment.end,
          unitsPerHour: segment.unitsPerHour,
        ));
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
            type: s.type,
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
    return [
      for (final r in rows)
        HealthSample(
          time: r.time,
          type: r.type,
          value: r.value,
          meta: (jsonDecode(r.meta) as Map).cast<String, Object?>(),
        ),
    ];
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
    return [
      for (final r in rows)
        Annotation(
          id: r.id,
          kind: AnnotationKind.values[r.kind],
          start: r.start,
          end: r.end,
          carbsGrams: r.carbsGrams,
          note: r.note,
          confidence: r.confidence,
        ),
    ];
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
    final pending = await (_db.select(_db.predictions)
          ..where((t) => t.actualMgdl.isNull()))
        .get();
    var updated = 0;
    for (final r in pending) {
      final target = r.madeAt.add(Duration(minutes: r.horizonMinutes));
      if (target.isAfter(now)) continue;
      final near = await _db.cgmBetween(
        target.subtract(const Duration(minutes: 5)),
        target.add(const Duration(minutes: 5)),
      );
      if (near.isEmpty) continue;
      final actual = near
          .reduce((a, b) => (a.time.difference(target).abs() <
                  b.time.difference(target).abs())
              ? a
              : b)
          .mgdl;
      await (_db.update(_db.predictions)..where((t) => t.id.equals(r.id)))
          .write(PredictionsCompanion(actualMgdl: Value(actual)));
      updated++;
    }
    return updated;
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
  Future<void> saveBolus(BolusEvent bolus) async => _boluses.add(bolus);
  @override
  Future<List<BolusEvent>> boluses(DateTime from, DateTime to) async =>
      _between(_boluses, from, to, (b) => b.time);

  @override
  Future<void> saveCarb(CarbEntry carb) async => _carbs.add(carb);
  @override
  Future<List<CarbEntry>> carbs(DateTime from, DateTime to) async =>
      _between(_carbs, from, to, (c) => c.time);

  @override
  Future<void> saveBasal(BasalSegment segment) async => _basal.add(segment);
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
      final near = _between(
          _cgm,
          p.targetTime.subtract(const Duration(minutes: 5)),
          p.targetTime.add(const Duration(minutes: 5)),
          (s) => s.time);
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
