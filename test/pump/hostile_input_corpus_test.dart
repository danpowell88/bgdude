import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/food/nutrition_panel_parser.dart';
import 'package:bgdude/meals/meal_library.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/hostile_inputs.dart';

/// Applies the shared hostile-input corpus to every parser these tests cover.
/// None of these should ever let an exception escape past a synchronous
/// throw-and-catch — that's exactly what each parser's real call site already does
/// (PumpClient._onEvent's try/catch, restoreJsonGuarded, meal-library's per-item
/// try/catch), so "survives" here means: parses to a
/// sane value, or throws synchronously (never hangs, never corrupts silently).
///
/// Nightscout entry/treatment parsing (also part of the shared corpus) has no test here:
/// the app only ever uploads to Nightscout and checks HTTP status codes — it never
/// deserializes a Nightscout response body into domain data, so there is no parser
/// to target yet. Flagged in the closing comment rather than silently dropped.
void main() {
  group('PumpSnapshot.fromJson survives the hostile corpus', () {
    const good = {
      'schemaVersion': 1,
      'timestampEpochMs': 1751800000000,
      'batteryPercent': 80,
      'reservoirUnits': 120.0,
      'iobUnits': 2.5,
      'basalUnitsPerHour': 0.8,
      'maxBolusUnits': 12.0,
      'maxBasalUnitsPerHour': 3.0,
      'cgmMgdl': 120,
      'cgmTimestampEpochMs': 1751799900000,
      'cgmTrend': 'flat',
      'lastBolusUnits': 4.5,
      'lastBolusTimestampEpochMs': 1751790000000,
      'activeAlerts': ['LOW_POWER_ALERT'],
      'activeAlarms': <String>[],
    };

    // On success, assert the physically-sane invariants fromJson's clamps
    // guarantee — the previous version wrapped the try/catch INSIDE the
    // returnsNormally closure, so it always passed regardless of whether the parser
    // threw or produced garbage (e.g. batteryPercent -81, reservoirUnits 1.79e308).
    void assertSane(PumpSnapshot s) {
      if (s.batteryPercent != null) {
        expect(s.batteryPercent, inInclusiveRange(0, 100));
      }
      if (s.reservoirUnits != null) {
        expect(s.reservoirUnits, greaterThanOrEqualTo(0));
        expect(s.reservoirUnits!.isFinite, isTrue);
      }
      if (s.iobUnits != null) {
        expect(s.iobUnits, greaterThanOrEqualTo(0));
        expect(s.iobUnits!.isFinite, isTrue);
      }
      // Glucose and dosing fields are reject-to-null, not clamped (a
      // fabricated in-range value here is worse than "no reading" -- see
      // pump_snapshot.dart's _rejectOutOfRange* doc comment) -- so the invariant is
      // simply that a non-null value is never outside the physiologically-sane band.
      if (s.cgmMgdl != null) {
        expect(s.cgmMgdl, inInclusiveRange(20, 600));
      }
      if (s.basalUnitsPerHour != null) {
        expect(s.basalUnitsPerHour, inInclusiveRange(0, 15));
      }
      if (s.maxBolusUnits != null) {
        expect(s.maxBolusUnits, inInclusiveRange(0, 25));
      }
      if (s.maxBasalUnitsPerHour != null) {
        expect(s.maxBasalUnitsPerHour, inInclusiveRange(0, 15));
      }
      if (s.lastBolusUnits != null) {
        expect(s.lastBolusUnits, inInclusiveRange(0, 25));
      }
      expect(s.cgmTrend, isNotNull); // _trend() always defaults to .unknown
      expect(s.activeAlerts, isA<List<String>>());
      expect(s.activeAlarms, isA<List<String>>());
    }

    // Separates the fallible PARSE (a synchronous throw is an acceptable "clean
    // rejection" — PumpClient._onEvent already catches it in production) from the
    // invariant ASSERTION, which must run OUTSIDE any try/catch: an expect() failure
    // is itself a thrown exception, so wrapping it in the same catch as the parse
    // would silently swallow a genuine invariant violation instead of failing the test.
    PumpSnapshot? tryParse(Map<String, dynamic> json) {
      try {
        return PumpSnapshot.fromJson(json);
      } catch (_) {
        return null;
      }
    }

    for (final v in hostileVariantsOf(good)) {
      test(v.name, () {
        final s = tryParse(v.json);
        if (s != null) assertSane(s);
      });
    }

    for (final v
        in hostileTimestampVariantsOf(good, 'timestampEpochMs')) {
      test(v.name, () {
        final s = tryParse(v.json);
        if (s != null) assertSane(s);
      });
    }
  });

  group('TherapySegment/TherapySettings.fromJson survive the hostile corpus',
      () {
    const goodSegment = {
      'startMinuteOfDay': 0,
      'isf': 50,
      'carbRatio': 10,
      'targetMgdl': 100,
      'basalUnitsPerHour': 0.8,
    };

    for (final v in hostileVariantsOf(goodSegment)) {
      test('TherapySegment: ${v.name}', () {
        // The parse (try) and the invariant assertion must not share a
        // catch -- an expect() failure is itself a thrown exception, so catching it
        // alongside a genuine parse throw would silently swallow a real invariant
        // violation instead of failing the test.
        TherapySegment? s;
        try {
          s = TherapySegment.fromJson(v.json);
        } catch (_) {
          // Caught by restoreJsonGuarded in production — acceptable here too.
        }
        if (s != null) {
          // Whenever it DOES parse, isf/carbRatio must stay sanitized
          // positive no matter how the rest of the row was mutated.
          expect(s.isf, greaterThan(0));
          expect(s.carbRatio, greaterThan(0));
        }
      });
    }

    test('TherapySettings: empty segments list never crashes segmentAt', () {
      final settings = TherapySettings.fromJson(const {'segments': []});
      expect(() => settings.segmentAt(DateTime(2026, 7, 4, 8)), returnsNormally);
    });
  });

  group('SavedMeal.fromJson survives the hostile corpus', () {
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

    // On success, assert the physically-sane invariants fromJson's clamps
    // guarantee, instead of swallowing the exception inside the returnsNormally
    // closure (which passed regardless of whether the parser threw or produced a
    // negative/astronomical meal). The parse (fallible) and the assertion (must
    // never be caught) are kept in separate try/non-try sections -- an expect()
    // failure is itself a thrown exception, so a shared catch would silently
    // swallow a real invariant violation instead of failing the test.
    for (final v in hostileVariantsOf(goodMeal)) {
      test(v.name, () {
        SavedMeal? m;
        try {
          m = SavedMeal.fromJson(v.json);
        } catch (_) {
          // Caught per-item in MealLibraryNotifier._restore in production — a
          // clean rejection.
        }
        if (m != null) {
          expect(m.carbsGrams, inInclusiveRange(0, 2000));
          expect(m.fatGrams, inInclusiveRange(0, 2000));
          expect(m.proteinGrams, inInclusiveRange(0, 2000));
          expect(m.absorptionMinutes, inInclusiveRange(1, 600));
          expect(m.peakOffsetMinutes, inInclusiveRange(1, 300));
        }
      });
    }
  });

  group('NutritionPanelParser.parse survives hostile OCR text', () {
    const parser = NutritionPanelParser();
    for (final text in hostileTextInputs) {
      test('"${text.length > 30 ? '${text.substring(0, 30)}…' : text}"', () {
        expect(() => parser.parse(text), returnsNormally);
      });
    }
  });
}
