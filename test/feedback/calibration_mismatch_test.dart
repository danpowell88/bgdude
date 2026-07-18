/// Fingerstick/sensor disagreements queued for confirmation (issue #77).
library;

import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/feedback/confirmation_service.dart';
import 'package:bgdude/feedback/pending_confirmation.dart';
import 'package:flutter_test/flutter_test.dart';

final _noon = DateTime(2026, 7, 4, 12);

/// A flat sensor trace at [sensorMgdl], with one finger-prick at [meterMgdl]
/// [offsetMinutes] after noon.
List<CgmSample> _trace({
  required double sensorMgdl,
  required double meterMgdl,
  int offsetMinutes = 2,
}) =>
    [
      for (var i = 0; i <= 6; i++)
        CgmSample(time: _noon.add(Duration(minutes: 5 * i)), mgdl: sensorMgdl),
      CgmSample(
        time: _noon.add(Duration(minutes: offsetMinutes)),
        mgdl: meterMgdl,
        source: GlucoseSource.meter,
      ),
    ];

List<PendingConfirmation> _scan(
  List<CgmSample> cgm, {
  List<Annotation> annotations = const [],
}) =>
    const ConfirmationService()
        .scan(
          now: _noon.add(const Duration(hours: 1)),
          cgm: cgm,
          boluses: const [],
          basal: const [],
          carbs: const [],
          settings: TherapySettings.placeholder(),
          annotations: annotations,
          decidedIds: const {},
        )
        .where((i) => i.type == ConfirmationType.calibrationMismatch)
        .toList();

void main() {
  test('a disagreeing finger-prick is queued for confirmation', () {
    // Meter 150 against a sensor reading 100 — 50% higher, well outside the ±20%
    // agreement band.
    final items = _scan(_trace(sensorMgdl: 100, meterMgdl: 150));

    expect(items, hasLength(1));
    expect(items.single.suggestedKind, AnnotationKind.sensorInaccurate);
    // The detail must state both numbers: the user is being asked which to believe,
    // and can't answer that without seeing them.
    expect(items.single.detail, contains('150'));
    expect(items.single.detail, contains('100'));
    expect(items.single.detail, contains('higher'));
  });

  test('an AGREEING finger-prick is not queued', () {
    // The important half. A match that agrees needs no decision from anyone, and
    // queueing it would bury the mismatches under routine confirmations.
    expect(_scan(_trace(sensorMgdl: 100, meterMgdl: 105)), isEmpty);
  });

  test('a lower meter reading is described as lower', () {
    final items = _scan(_trace(sensorMgdl: 150, meterMgdl: 90));

    expect(items.single.detail, contains('lower'));
  });

  test('a bigger disagreement carries more confidence', () {
    final small = _scan(_trace(sensorMgdl: 100, meterMgdl: 130)).single;
    final large = _scan(_trace(sensorMgdl: 100, meterMgdl: 200)).single;

    expect(large.confidence, greaterThan(small.confidence));
    expect(large.confidence, lessThanOrEqualTo(1.0));
    expect(small.confidence, greaterThanOrEqualTo(0.3));
  });

  test('a finger-prick with no sensor reading nearby is not queued', () {
    // Nothing to disagree WITH — queueing it would ask the user to adjudicate a
    // comparison that was never made.
    final items = _scan([
      for (var i = 0; i <= 6; i++)
        CgmSample(time: _noon.add(Duration(minutes: 5 * i)), mgdl: 100),
      CgmSample(
        time: _noon.add(const Duration(hours: 3)),
        mgdl: 200,
        source: GlucoseSource.meter,
      ),
    ]);

    expect(items, isEmpty);
  });

  test('an already-annotated period is not re-queued', () {
    // Otherwise every rescan re-asks a question the user has already answered.
    final items = _scan(
      _trace(sensorMgdl: 100, meterMgdl: 150),
      annotations: [
        Annotation(
          id: 'a',
          kind: AnnotationKind.sensorInaccurate,
          start: _noon.subtract(const Duration(minutes: 30)),
          end: _noon.add(const Duration(minutes: 30)),
        ),
      ],
    );

    expect(items, isEmpty);
  });

  test('a confirmed sensor-inaccurate period is excluded from training', () {
    // The reason confirming is worth anything: training on a stretch where the
    // sensor was demonstrably wrong teaches the model to reproduce the error.
    expect(AnnotationKind.sensorInaccurate.excludesFromTraining, isTrue);
  });

  test('no finger-pricks means nothing queued', () {
    expect(
      _scan([
        for (var i = 0; i <= 6; i++)
          CgmSample(time: _noon.add(Duration(minutes: 5 * i)), mgdl: 100),
      ]),
      isEmpty,
    );
  });
}
