import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/reports/correlation_report.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:bgdude/weather/weather.dart';
import 'package:bgdude/weather/weather_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeatherService parsing', () {
    test('geocode picks the first result', () {
      final loc = WeatherService.parseGeocode(
          '{"results":[{"name":"Sydney","latitude":-33.87,"longitude":151.21}]}');
      expect(loc, isNotNull);
      expect(loc!.name, 'Sydney');
      expect(loc.lat, closeTo(-33.87, 1e-6));
    });

    test('geocode with no results → null', () {
      expect(WeatherService.parseGeocode('{"results":[]}'), isNull);
      expect(WeatherService.parseGeocode('{}'), isNull);
    });

    test('current parses temperature + humidity', () {
      final w = WeatherService.parseCurrent(
          '{"current":{"temperature_2m":31.2,"relative_humidity_2m":55}}',
          now: DateTime(2026, 7, 4));
      expect(w, isNotNull);
      expect(w!.tempC, 31.2);
      expect(w.humidity, 55);
    });

    test('current without temperature → null', () {
      expect(WeatherService.parseCurrent('{"current":{}}'), isNull);
    });

    // The parsers used to hard-cast `jsonDecode(body) as Map` / `results.first
    // as Map` — a shape change (or a non-JSON-object error body) would throw a TypeError
    // straight out of the parser instead of degrading to "no result".
    test('geocode with a non-object body (e.g. a bare JSON array) → null, not a throw',
        () {
      expect(WeatherService.parseGeocode('[]'), isNull);
    });

    test('geocode whose results entries are not objects → null, not a throw', () {
      expect(WeatherService.parseGeocode('{"results":["Sydney"]}'), isNull);
    });

    test('current with a non-object body → null, not a throw', () {
      expect(WeatherService.parseCurrent('null'), isNull);
    });

    test('current whose "current" field is not an object → null, not a throw', () {
      expect(WeatherService.parseCurrent('{"current":"unexpected"}'), isNull);
    });

    // jsonDecode itself ran unguarded before the is-Map check -- a
    // non-JSON body (captive-portal HTML, a truncated/empty HTTP-200 response)
    // threw FormatException straight out of the parser, the exact
    // throws-out-of-a-parser-at-the-source case above was meant to
    // close but didn't reach.
    test('geocode with a non-JSON body (e.g. captive-portal HTML) → null, not a '
        'throw', () {
      expect(
          WeatherService.parseGeocode(
              '<html><body>Connect to Wi-Fi</body></html>'),
          isNull);
      expect(WeatherService.parseGeocode(''), isNull);
      expect(WeatherService.parseGeocode('{truncated'), isNull);
    });

    test('current with a non-JSON body → null, not a throw', () {
      expect(
          WeatherService.parseCurrent(
              '<html><body>Connect to Wi-Fi</body></html>'),
          isNull);
      expect(WeatherService.parseCurrent(''), isNull);
      expect(WeatherService.parseCurrent('{truncated'), isNull);
    });
  });

  group('WeatherRiskModifier', () {
    const m = WeatherRiskModifier();
    test('hot and very hot raise the low line; extreme raises it more', () {
      expect(m.lowThresholdBump(20), 0);
      expect(m.lowThresholdBump(30), 5); // hot
      expect(m.lowThresholdBump(36), 8); // very hot
    });
    test('cold also raises the low line', () {
      expect(m.lowThresholdBump(2), 3);
    });
    test('null temperature → no bump', () {
      expect(m.lowThresholdBump(null), 0);
    });
  });

  group('WeatherHistoryStore', () {
    setUp(KvStore.useMemory);
    test('records per day and reloads', () async {
      await WeatherHistoryStore.record(DateTime(2026, 7, 4, 10), 28.0);
      await WeatherHistoryStore.record(DateTime(2026, 7, 4, 16), 32.0); // same day, overwrites
      await WeatherHistoryStore.record(DateTime(2026, 7, 5, 10), 20.0);
      final daily = await WeatherHistoryStore.loadDaily();
      expect(daily['2026-7-4'], 32.0);
      expect(daily['2026-7-5'], 20.0);
    });
  });

  group('Correlation with ambient temperature', () {
    test('surfaces a temperature↔TIR association', () {
      final base = DateTime(2026, 7, 1);
      final cgm = <CgmSample>[];
      final temps = <String, double>{};
      // 8 days: hotter days have more highs (lower TIR).
      for (var d = 0; d < 8; d++) {
        final day = base.add(Duration(days: d));
        for (var i = 0; i < 120; i++) {
          final high = i < d * 15;
          cgm.add(CgmSample(
              time: day.add(Duration(minutes: 5 * i)),
              mgdl: high ? 250 : 120));
        }
        temps['${day.year}-${day.month}-${day.day}'] = 20.0 + d; // rising temp
      }
      final report = const CorrelationReportBuilder().build(
        cgm: cgm,
        health: const [],
        range: ReportRange(from: base, to: base.add(const Duration(days: 8)),
            preset: ReportPreset.custom),
        now: base.add(const Duration(days: 8)),
        dailyTempC: temps,
      );
      final f = report.findings.firstWhere(
        (x) => x.predictorLabel == 'ambient temperature' &&
            x.outcomeLabel == 'time-in-range',
      );
      expect(f.r, lessThan(0)); // hotter → lower TIR here
    });
  });
}
