/// TASK-147: the one composed low-line policy — each modifier alone, their
/// composition (max, not stacking), and the reasons trail.
library;

import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/insights/alcohol_watch.dart';
import 'package:bgdude/insights/effective_low_threshold.dart';
import 'package:bgdude/insights/exercise_mode.dart';
import 'package:bgdude/insights/workout_classifier.dart';
import 'package:bgdude/profile/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 4, 12);

  EffectiveLowThreshold compute({
    double base = 70,
    UserProfile profile = const UserProfile(),
    Iterable<Annotation> annotations = const [],
    ExercisePlan? exercisePlan,
    double? tempC,
  }) =>
      EffectiveLowThreshold.compute(
        base: base,
        profile: profile,
        annotations: annotations,
        exercisePlan: exercisePlan,
        tempC: tempC,
        now: now,
      );

  Annotation alcoholAt(DateTime at) => Annotation(
        id: 'a',
        kind: AnnotationKind.alcohol,
        start: at,
        end: at.add(const Duration(hours: 2)),
      );

  test('no modifiers: the base line passes through with no reasons', () {
    final t = compute();
    expect(t.mgdl, 70);
    expect(t.reasons, isEmpty);
  });

  test('impaired-awareness risk adds its bump (capped at +8)', () {
    final t = compute(
        profile: const UserProfile(birthYear: 1950, diagnosisYear: 1990));
    expect(t.mgdl, 78);
    expect(t.reasons.single, contains('impaired-awareness'));
  });

  test('a recent alcohol annotation raises the line by the watch margin', () {
    final t = compute(
        annotations: [alcoholAt(now.subtract(const Duration(hours: 2)))]);
    expect(t.mgdl, 70 + const AlcoholWatch().lowBumpMgdl); // 80
    expect(t.reasons.single, contains('alcohol'));
  });

  test('an alcohol annotation outside the window does nothing', () {
    final t = compute(
        annotations: [alcoholAt(now.subtract(const Duration(hours: 20)))]);
    expect(t.mgdl, 70);
    expect(t.reasons, isEmpty);
  });

  test('an active aerobic session raises the line by 20', () {
    final t = compute(
        exercisePlan: ExercisePlan(
      startAt: now.subtract(const Duration(minutes: 30)),
      durationMinutes: 60,
      type: WorkoutType.aerobic,
    ));
    expect(t.mgdl, 90);
    expect(t.reasons.single, contains('exercise'));
  });

  test('a resistance session raises the line by only 8', () {
    final t = compute(
        exercisePlan: ExercisePlan(
      startAt: now.subtract(const Duration(minutes: 30)),
      durationMinutes: 60,
      type: WorkoutType.resistance,
    ));
    expect(t.mgdl, 78);
  });

  test('hot and cold weather each raise the line', () {
    expect(compute(tempC: 35).mgdl, 78); // very hot +8
    expect(compute(tempC: 30).mgdl, 75); // hot +5
    expect(compute(tempC: 2).mgdl, 73); // cold +3
    expect(compute(tempC: 21).mgdl, 70); // mild — no change
    expect(compute(tempC: 2).reasons.single, contains('cold'));
    expect(compute(tempC: 35).reasons.single, contains('hot'));
  });

  test('modifiers compose via max over the base, not stacking', () {
    final t = compute(
      profile: const UserProfile(birthYear: 1950, diagnosisYear: 1990), // +8
      annotations: [alcoholAt(now.subtract(const Duration(hours: 1)))], // +10
      exercisePlan: ExercisePlan(
        startAt: now.subtract(const Duration(minutes: 15)),
        durationMinutes: 45,
        type: WorkoutType.aerobic, // +20
      ),
      tempC: 35, // +8
    );
    expect(t.mgdl, 90); // base + max bump (exercise), NOT 70+8+10+20+8
    expect(t.reasons, hasLength(4)); // ...but every active reason is reported
  });

  test('a custom base line keeps its lead under every modifier', () {
    final t = compute(
      base: 85,
      annotations: [alcoholAt(now.subtract(const Duration(hours: 1)))],
    );
    expect(t.mgdl, 95); // additive margin, not the absolute 80
  });

  test('the line never drops below the base', () {
    for (final t in [
      compute(),
      compute(tempC: 21),
      compute(profile: const UserProfile(birthYear: 2010)),
    ]) {
      expect(t.mgdl, greaterThanOrEqualTo(70));
    }
  });
}
