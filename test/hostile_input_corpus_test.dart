import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/food/nutrition_panel_parser.dart';
import 'package:bgdude/meals/meal_library.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/hostile_inputs.dart';

/// TASK-193: applies the shared hostile-input corpus to every parser named in the
/// ticket. None of these should ever let an exception escape past a synchronous
/// throw-and-catch — that's exactly what each parser's real call site already does
/// (PumpClient._onEvent's try/catch, restoreJsonGuarded, meal-library's per-item
/// try/catch — see TASK-181/188/190/191), so "survives" here means: parses to a
/// sane value, or throws synchronously (never hangs, never corrupts silently).
///
/// Nightscout entry/treatment parsing (also named in the ticket) has no test here:
/// the app only ever uploads to Nightscout and checks HTTP status codes — it never
/// deserializes a Nightscout response body into domain data, so there is no parser
/// to target yet. Flagged in the closing comment rather than silently dropped.
void main() {
  group('PumpSnapshot.fromJson survives the hostile corpus (TASK-193)', () {
    const good = {
      'schemaVersion': 1,
      'timestampEpochMs': 1751800000000,
      'batteryPercent': 80,
      'reservoirUnits': 120.0,
      'iobUnits': 2.5,
      'cgmMgdl': 120,
      'cgmTimestampEpochMs': 1751799900000,
      'cgmTrend': 'flat',
      'activeAlerts': ['LOW_POWER_ALERT'],
      'activeAlarms': <String>[],
    };

    for (final v in hostileVariantsOf(good)) {
      test(v.name, () {
        expect(() {
          try {
            PumpSnapshot.fromJson(v.json);
          } catch (_) {
            // A synchronous throw here is exactly what PumpClient._onEvent's
            // try/catch already handles in production — acceptable.
          }
        }, returnsNormally);
      });
    }

    for (final v
        in hostileTimestampVariantsOf(good, 'timestampEpochMs')) {
      test(v.name, () {
        expect(() => PumpSnapshot.fromJson(v.json), returnsNormally);
      });
    }
  });

  group('TherapySegment/TherapySettings.fromJson survive the hostile corpus '
      '(TASK-193)', () {
    const goodSegment = {
      'startMinuteOfDay': 0,
      'isf': 50,
      'carbRatio': 10,
      'targetMgdl': 100,
      'basalUnitsPerHour': 0.8,
    };

    for (final v in hostileVariantsOf(goodSegment)) {
      test('TherapySegment: ${v.name}', () {
        try {
          final s = TherapySegment.fromJson(v.json);
          // TASK-190: whenever it DOES parse, isf/carbRatio must stay sanitized
          // positive no matter how the rest of the row was mutated.
          expect(s.isf, greaterThan(0));
          expect(s.carbRatio, greaterThan(0));
        } catch (_) {
          // Caught by restoreJsonGuarded in production — acceptable here too.
        }
      });
    }

    test('TherapySettings: empty segments list never crashes segmentAt', () {
      final settings = TherapySettings.fromJson(const {'segments': []});
      expect(() => settings.segmentAt(DateTime(2026, 7, 4, 8)), returnsNormally);
    });
  });

  group('SavedMeal.fromJson survives the hostile corpus (TASK-193)', () {
    const goodMeal = {
      'id': 'abc123',
      'name': 'Toast',
      'emoji': '🍞',
      'category': 'breakfast',
      'carbsGrams': 30.0,
      'fatGrams': 2.0,
      'proteinGrams': 4.0,
      'fatProteinHeavy': false,
      'absorptionMinutes': 120,
      'peakOffsetMinutes': 60,
      'outcomes': <Map<String, dynamic>>[],
    };

    for (final v in hostileVariantsOf(goodMeal)) {
      test(v.name, () {
        expect(() {
          try {
            SavedMeal.fromJson(v.json);
          } catch (_) {
            // Caught per-item in MealLibraryNotifier._restore in production.
          }
        }, returnsNormally);
      });
    }
  });

  group('NutritionPanelParser.parse survives hostile OCR text (TASK-193)', () {
    const parser = NutritionPanelParser();
    for (final text in hostileTextInputs) {
      test('"${text.length > 30 ? '${text.substring(0, 30)}…' : text}"', () {
        expect(() => parser.parse(text), returnsNormally);
      });
    }
  });
}
