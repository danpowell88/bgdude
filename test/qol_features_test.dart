import 'package:bgdude/insights/alert_thresholds.dart';
import 'package:bgdude/insights/exercise_mode.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/insights/workout_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuietHours', () {
    test('inactive when disabled', () {
      expect(const QuietHours(enabled: false).activeAt(DateTime(2026, 7, 4, 3)),
          isFalse);
    });

    test('overnight window wraps past midnight', () {
      const q = QuietHours(enabled: true, startMinute: 22 * 60, endMinute: 7 * 60);
      expect(q.activeAt(DateTime(2026, 7, 4, 23)), isTrue); // 23:00
      expect(q.activeAt(DateTime(2026, 7, 4, 3)), isTrue); // 03:00
      expect(q.activeAt(DateTime(2026, 7, 4, 12)), isFalse); // noon
    });

    test('same-day window does not wrap', () {
      const q = QuietHours(enabled: true, startMinute: 9 * 60, endMinute: 17 * 60);
      expect(q.activeAt(DateTime(2026, 7, 4, 12)), isTrue);
      expect(q.activeAt(DateTime(2026, 7, 4, 20)), isFalse);
    });

    test('critical categories bypass quiet hours; others do not', () {
      expect(NotificationCategory.urgentLow.bypassesQuietHours, isTrue);
      expect(NotificationCategory.predictedLow.bypassesQuietHours, isTrue);
      expect(NotificationCategory.pumpAlarm.bypassesQuietHours, isTrue);
      expect(NotificationCategory.morningSummary.bypassesQuietHours, isFalse);
      expect(NotificationCategory.deviceReminder.bypassesQuietHours, isFalse);
    });

    test('quiet hours survive the notification-prefs JSON round-trip', () {
      final prefs = NotificationPrefs.defaults().withQuietHours(
          const QuietHours(enabled: true, startMinute: 1320, endMinute: 360));
      final restored = NotificationPrefs.fromJson(prefs.toJson());
      expect(restored.quietHours.enabled, isTrue);
      expect(restored.quietHours.startMinute, 1320);
      expect(restored.quietHours.endMinute, 360);
      // Categories still present.
      expect(restored.of(NotificationCategory.urgentLow).enabled, isTrue);
    });

    test('legacy flat category JSON still parses (no quietHours key)', () {
      final legacy = {
        for (final c in NotificationCategory.values)
          c.name: NotificationPrefs.defaults().of(c).toJson(),
      };
      final restored = NotificationPrefs.fromJson(legacy);
      expect(restored.quietHours.enabled, isFalse);
      expect(restored.of(NotificationCategory.urgentLow).importance,
          NotifImportance.urgent);
    });
  });

  group('AlertThresholds', () {
    test('JSON round-trip and copyWith', () {
      const t = AlertThresholds(lowMgdl: 80, highMgdl: 220);
      final r = AlertThresholds.fromJson(t.toJson());
      expect(r.lowMgdl, 80);
      expect(r.highMgdl, 220);
      expect(t.copyWith(lowMgdl: 75).lowMgdl, 75);
      expect(t.copyWith(lowMgdl: 75).highMgdl, 220);
    });
  });

  group('ExercisePlan + coach', () {
    final start = DateTime(2026, 7, 4, 18);

    test('affects from 15 min before start through end + tail', () {
      final plan = ExercisePlan(
          startAt: start, durationMinutes: 45, type: WorkoutType.aerobic);
      expect(plan.affectsAt(start.subtract(const Duration(minutes: 10))), isTrue);
      expect(plan.affectsAt(start.add(const Duration(minutes: 30))), isTrue);
      // 45 min session + 8 h aerobic tail.
      expect(plan.affectsAt(start.add(const Duration(hours: 8))), isTrue);
      expect(plan.affectsAt(start.add(const Duration(hours: 10))), isFalse);
      expect(plan.affectsAt(start.subtract(const Duration(hours: 1))), isFalse);
    });

    test('aerobic gets a bigger low-threshold bump than resistance', () {
      const coach = ExerciseModeCoach();
      expect(coach.lowBump(WorkoutType.aerobic),
          greaterThan(coach.lowBump(WorkoutType.resistance)));
    });

    test('suggests a bigger pre-snack when low-ish, high IOB, or dropping', () {
      const coach = ExerciseModeCoach();
      final lowish = coach.prep(
          currentMgdl: 95,
          iobUnits: 2.5,
          rocMgdlPerMin: -1.5,
          type: WorkoutType.aerobic);
      expect(lowish.suggestedCarbsGrams, greaterThan(0));

      final fine = coach.prep(
          currentMgdl: 160,
          iobUnits: 0.2,
          rocMgdlPerMin: 0,
          type: WorkoutType.aerobic);
      expect(fine.suggestedCarbsGrams, 0);
    });

    test('resistance-only rarely needs a pre-snack', () {
      final prep = const ExerciseModeCoach().prep(
          currentMgdl: 95,
          iobUnits: 2.5,
          rocMgdlPerMin: -1.5,
          type: WorkoutType.resistance);
      expect(prep.suggestedCarbsGrams, 0);
    });

    test('plan JSON round-trip', () {
      final plan = ExercisePlan(
          startAt: start, durationMinutes: 60, type: WorkoutType.mixed);
      final r = ExercisePlan.fromJson(plan.toJson());
      expect(r.durationMinutes, 60);
      expect(r.type, WorkoutType.mixed);
      expect(r.startAt, start);
    });
  });
}
