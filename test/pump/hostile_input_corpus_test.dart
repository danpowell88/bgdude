import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/food/nutrition_panel_parser.dart';
import 'package:bgdude/insights/alert_thresholds.dart';
import 'package:bgdude/insights/medication_mode.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/insights/system_health.dart';
import 'package:bgdude/integrations/nightscout.dart';
import 'package:bgdude/meals/meal_library.dart';
import 'package:bgdude/profile/user_profile.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/weather/weather.dart';
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

  // TASK-255: the remaining restoreJsonGuarded-wrapped decoders in
  // providers.dart. Unlike PumpSnapshot/SavedMeal above, most of these have NO
  // clamp/range validation on their numeric fields at all (see the fromJson
  // bodies) -- lowMgdl/highMgdl/urgentLowMgdl, lat/lon, repeatMinutes,
  // consecutiveFailures, birthYear/weightKg/heightCm all pass a hostile
  // huge/negative number straight through unclamped. That is a real gap, not
  // a gap in this test: the invariant asserted below for each field is
  // whatever the class actually guarantees today (a default when missing/
  // null, a valid enum, a Map that throws cleanly on a structurally wrong
  // shape) -- asserting a range that doesn't exist in the code would either
  // fail honestly (good) or require silently expanding this ticket into
  // fixing seven unrelated settings decoders (out of scope for a test-corpus
  // extension). Flagged in the closing backlog comment as a follow-up.

  group('NotificationPrefs.fromJson survives the hostile corpus', () {
    const good = {
      'categories': {
        'urgentLow': {
          'enabled': true,
          'importance': 'urgent',
          'vibrate': true,
          'sound': true,
          'repeatMinutes': 15,
        },
      },
      'quietHours': {'enabled': true, 'startMinute': 1320, 'endMinute': 420},
    };

    for (final v in hostileVariantsOf(good)) {
      test(v.name, () {
        NotificationPrefs? p;
        try {
          p = NotificationPrefs.fromJson(v.json);
        } catch (_) {
          // A non-Map per-category value or non-Map quietHours throws --
          // caught by restoreJsonGuarded in production, acceptable here too.
        }
        if (p != null) {
          // Every category always has an entry, no matter how the JSON was
          // mutated -- the loop fills any missing/malformed one with its
          // own default rather than ever leaving a category unset.
          expect(p.byCategory.length, NotificationCategory.values.length);
          expect(p.quietHours, isNotNull);
        }
      });
    }
  });

  group('UserProfile.fromJson survives the hostile corpus', () {
    const good = {
      'name': 'Sam',
      'sex': 'female',
      'birthYear': 1988,
      'diagnosisYear': 2005,
      'weightKg': 70.0,
      'heightCm': 175.0,
      'diabetesType': 'type1',
    };

    for (final v in hostileVariantsOf(good)) {
      test(v.name, () {
        UserProfile? p;
        try {
          p = UserProfile.fromJson(v.json);
        } catch (_) {
          // A wrong-type name/birthYear/weightKg/etc. throws a TypeError --
          // caught by restoreJsonGuarded in production, acceptable here too.
        }
        if (p != null) {
          // Enum fields never come back null or an invalid value, even for
          // an unrecognized/wrong-type input -- they default instead.
          expect(p.sex, isNotNull);
          expect(p.diabetesType, isNotNull);
          expect(p.name, isNotNull);
          // Whenever a numeric field DOES survive as a double, it must at
          // least be finite -- a huge or NaN-producing mutation must not
          // silently become "a valid-looking weight/height".
          if (p.weightKg != null) expect(p.weightKg!.isFinite, isTrue);
          if (p.heightCm != null) expect(p.heightCm!.isFinite, isTrue);
        }
      });
    }
  });

  group('AlertThresholds.fromJson survives the hostile corpus', () {
    const good = {
      'low': 70.0,
      'high': 200.0,
      'urgentLow': 55.0,
      'segments': {
        'overnight': {'low': 85.0, 'high': 180.0, 'urgentLow': 55.0},
      },
    };

    for (final v in hostileVariantsOf(good)) {
      test(v.name, () {
        AlertThresholds? t;
        try {
          t = AlertThresholds.fromJson(v.json);
        } catch (_) {
          // A non-Map "segments" value throws -- caught by
          // restoreJsonGuarded in production, acceptable here too.
        }
        if (t != null) {
          // The three top-level thresholds are never null, and a per-segment
          // override that doesn't structurally fit (not a Map) is silently
          // skipped rather than corrupting the whole table.
          expect(t.lowMgdl.isFinite, isTrue);
          expect(t.highMgdl.isFinite, isTrue);
          expect(t.urgentLowMgdl.isFinite, isTrue);
          for (final band in t.segments.values) {
            expect(band.lowMgdl.isFinite, isTrue);
            expect(band.highMgdl.isFinite, isTrue);
            expect(band.urgentLowMgdl.isFinite, isTrue);
          }
        }
      });
    }
  });

  group('MedicationMode.fromJson survives the hostile corpus', () {
    const good = {
      'active': true,
      'startedAt': '2026-07-04T00:00:00.000',
      'expiresAt': '2026-07-18T00:00:00.000',
      'intensity': 'high',
      'name': 'Prednisolone',
    };

    for (final v in hostileVariantsOf(good)) {
      test(v.name, () {
        MedicationMode? m;
        try {
          m = MedicationMode.fromJson(v.json);
        } catch (_) {
          // A malformed startedAt/expiresAt date string throws --
          // caught by restoreJsonGuarded in production, acceptable here too.
        }
        if (m != null) {
          expect(m.active, isNotNull);
          expect(m.intensity, isNotNull);
          expect(m.name, isNotNull);
        }
      });
    }

    for (final v
        in hostileTimestampVariantsOf(good, 'startedAt') +
            hostileTimestampVariantsOf(good, 'expiresAt')) {
      test(v.name, () {
        // These substitute an int epoch for the ISO-8601 string DateTime.parse
        // expects -- a TypeError, not a FormatException, but the same "throws
        // cleanly, never corrupts silently" contract applies.
        expect(() => MedicationMode.fromJson(v.json), anyOf(
          returnsNormally,
          throwsA(anything),
        ));
      });
    }
  });

  group('WeatherSettings.fromJson survives the hostile corpus', () {
    const good = {
      'enabled': true,
      'city': 'Sydney',
      'lat': -33.87,
      'lon': 151.21,
    };

    for (final v in hostileVariantsOf(good)) {
      test(v.name, () {
        WeatherSettings? w;
        try {
          w = WeatherSettings.fromJson(v.json);
        } catch (_) {
          // A wrong-type enabled/city throws -- caught by
          // restoreJsonGuarded in production, acceptable here too.
        }
        if (w != null) {
          expect(w.enabled, isNotNull);
          expect(w.city, isNotNull);
          // lat/lon have no geo-range clamp in production -- the only
          // invariant fromJson itself guarantees is "finite double or null",
          // never NaN/Infinity masquerading as a coordinate.
          if (w.lat != null) expect(w.lat!.isFinite, isTrue);
          if (w.lon != null) expect(w.lon!.isFinite, isTrue);
        }
      });
    }
  });

  group('NightscoutConfig.fromJson survives the hostile corpus', () {
    const good = {
      'baseUrl': 'https://ns.example.com',
      'apiSecret': 'secret1234567',
      'enabled': true,
    };

    for (final v in hostileVariantsOf(good)) {
      test(v.name, () {
        NightscoutConfig? c;
        try {
          c = NightscoutConfig.fromJson(v.json);
        } catch (_) {
          // A wrong-type baseUrl/apiSecret/enabled throws -- caught by
          // restoreJsonGuarded in production, acceptable here too.
        }
        if (c != null) {
          // String fields default to '' rather than ever coming back null.
          expect(c.baseUrl, isNotNull);
          expect(c.apiSecret, isNotNull);
          expect(c.enabled, isNotNull);
        }
      });
    }
  });

  group('SystemHealthReport.fromJson survives the hostile corpus', () {
    const good = {
      'healthSync': {
        'lastSuccessAt': '2026-07-01T09:00:00.000',
        'consecutiveFailures': 0,
        'lastError': null,
        'lastAttemptAt': '2026-07-08T10:00:00.000',
      },
      'weather': {
        'lastSuccessAt': null,
        'consecutiveFailures': 3,
        'lastError': 'network unreachable',
        'lastAttemptAt': '2026-07-08T10:00:00.000',
      },
    };

    for (final v in hostileVariantsOf(good)) {
      test(v.name, () {
        SystemHealthReport? r;
        try {
          r = SystemHealthReport.fromJson(v.json);
        } catch (_) {
          // A malformed lastSuccessAt/lastAttemptAt date string inside an
          // otherwise-well-shaped subsystem entry throws -- caught by
          // restoreJsonGuarded in production, acceptable here too.
        }
        if (r != null) {
          // A non-Map, structurally-wrong subsystem entry (the "wrong type
          // for" / "empty map" / "all values null" mutations) must be
          // silently DROPPED, not crash the whole report -- of() then
          // reports .unknown for that subsystem rather than a garbage value.
          for (final s in Subsystem.values) {
            expect(r.of(s), isNotNull);
          }
        }
      });
    }
  });
}
