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

  // TASK-255/302: the remaining restoreJsonGuarded-wrapped decoders in
  // providers.dart. lowMgdl/highMgdl/urgentLowMgdl, lat/lon, repeatMinutes,
  // startMinute/endMinute, consecutiveFailures, and birthYear/weightKg/
  // heightCm now REJECT (never clamp toward a fabricated in-range value) a
  // hostile out-of-range mutation back to a default/null -- see each class's
  // fromJson for the exact bounds. The assertions below check the actual
  // range invariant each field now guarantees, not just isFinite.

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
          // TASK-302: repeatMinutes/startMinute/endMinute reject out-of-range
          // (negative or >1440) back to a sane default rather than pass a
          // corrupt cadence/window through.
          for (final pref in p.byCategory.values) {
            expect(pref.repeatMinutes, inInclusiveRange(0, 1440));
          }
          expect(p.quietHours.startMinute, inInclusiveRange(0, 1440));
          expect(p.quietHours.endMinute, inInclusiveRange(0, 1440));
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
          // TASK-302: an out-of-range year/weight/height rejects to null
          // rather than pass a huge/negative value through as real.
          if (p.birthYear != null) {
            expect(p.birthYear, inInclusiveRange(1900, 2100));
          }
          if (p.diagnosisYear != null) {
            expect(p.diagnosisYear, inInclusiveRange(1900, 2100));
          }
          if (p.weightKg != null) expect(p.weightKg, inInclusiveRange(1, 500));
          if (p.heightCm != null) expect(p.heightCm, inInclusiveRange(30, 300));
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
          // TASK-302: AlertThresholds drives real-time alert firing -- a
          // corrupt low/high/urgentLow REJECTS to the shipped default rather
          // than becoming the real threshold, at the top level and per
          // segment. A per-segment override that doesn't structurally fit
          // (not a Map) is silently skipped rather than corrupting the whole
          // table.
          expect(t.lowMgdl, inInclusiveRange(20, 600));
          expect(t.highMgdl, inInclusiveRange(20, 600));
          expect(t.urgentLowMgdl, inInclusiveRange(20, 600));
          for (final band in t.segments.values) {
            expect(band.lowMgdl, inInclusiveRange(20, 600));
            expect(band.highMgdl, inInclusiveRange(20, 600));
            expect(band.urgentLowMgdl, inInclusiveRange(20, 600));
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
        // TASK-302: fixed a vacuous assertion here (anyOf(returnsNormally,
        // throwsA(anything)) is a tautology -- true regardless of outcome).
        // hostileTimestampVariantsOf substitutes an int epoch for the
        // ISO-8601 string startedAt/expiresAt expects; `j['startedAt'] as
        // String` throws a TypeError before DateTime.parse is ever reached,
        // deterministically, every time -- caught by restoreJsonGuarded in
        // production, a clean rejection rather than a silently-corrupt date.
        expect(() => MedicationMode.fromJson(v.json), throwsA(isA<TypeError>()));
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
          // TASK-302: an out-of-range lat/lon rejects to null rather than
          // pass a fabricated location through.
          if (w.lat != null) expect(w.lat, inInclusiveRange(-90, 90));
          if (w.lon != null) expect(w.lon, inInclusiveRange(-180, 180));
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
          // TASK-302: consecutiveFailures rejects negative to 0 rather than
          // pass a nonsensical negative count through.
          for (final s in Subsystem.values) {
            expect(r.of(s), isNotNull);
            expect(r.of(s).consecutiveFailures, greaterThanOrEqualTo(0));
          }
        }
      });
    }
  });
}
