import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/units.dart';
import 'package:bgdude/widget/bg_widget_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the pure home-screen-widget formatting logic
/// (lib/widget/bg_widget_format.dart). The plugin glue in
/// HomeWidgetService just persists these outputs, and the native
/// BgWidgetProvider mirrors the same rules, so this is the contract.
void main() {
  BgWidgetData format({
    int? mgdl = 112,
    GlucoseTrend? trend = GlucoseTrend.flat,
    double? iob = 1.2,
    GlucoseUnit unit = GlucoseUnit.mmol,
    Duration? age = const Duration(minutes: 3),
  }) =>
      formatBgWidgetData(
        cgmMgdl: mgdl,
        trend: trend,
        iobUnits: iob,
        unit: unit,
        readingAge: age,
      );

  group('BG value formatting', () {
    test('renders mmol/L with one decimal', () {
      // 112 / 18.0182 = 6.216 → '6.2'
      final d = format(mgdl: 112, unit: GlucoseUnit.mmol);
      expect(d.bgText, '6.2');
      expect(d.unitLabel, 'mmol/L');
    });

    test('renders mg/dL as a whole number', () {
      final d = format(mgdl: 112, unit: GlucoseUnit.mgdl);
      expect(d.bgText, '112');
      expect(d.unitLabel, 'mg/dL');
    });

    test('missing reading renders placeholder with no arrow', () {
      final d = format(mgdl: null, age: null);
      expect(d.bgText, '--');
      expect(d.trendArrow, '');
      expect(d.range, BgRange.unknown);
      expect(d.isStale, isTrue);
      expect(d.updatedText, 'no data');
    });
  });

  group('Range colouring buckets', () {
    test('low below 70, inclusive bounds in range, high above 180', () {
      expect(format(mgdl: 54).range, BgRange.low);
      expect(format(mgdl: 69).range, BgRange.low);
      expect(format(mgdl: 70).range, BgRange.inRange);
      expect(format(mgdl: 112).range, BgRange.inRange);
      expect(format(mgdl: 180).range, BgRange.inRange);
      expect(format(mgdl: 181).range, BgRange.high);
      expect(format(mgdl: 320).range, BgRange.high);
    });

    test('range bucket is still reported when stale (renderer greys it out)', () {
      final d = format(mgdl: 250, age: const Duration(minutes: 40));
      expect(d.range, BgRange.high);
      expect(d.isStale, isTrue);
    });
  });

  group('Trend arrows', () {
    test('maps every trend to its arrow', () {
      expect(trendArrowChar(GlucoseTrend.doubleUp), '⇈');
      expect(trendArrowChar(GlucoseTrend.singleUp), '↑');
      expect(trendArrowChar(GlucoseTrend.fortyFiveUp), '↗');
      expect(trendArrowChar(GlucoseTrend.flat), '→');
      expect(trendArrowChar(GlucoseTrend.fortyFiveDown), '↘');
      expect(trendArrowChar(GlucoseTrend.singleDown), '↓');
      expect(trendArrowChar(GlucoseTrend.doubleDown), '⇊');
      expect(trendArrowChar(GlucoseTrend.unknown), '');
    });

    test('null trend renders as no arrow', () {
      expect(format(trend: null).trendArrow, '');
    });
  });

  group('Staleness and updated-ago text', () {
    test('fresh reading is not stale', () {
      final d = format(age: const Duration(minutes: 5));
      expect(d.isStale, isFalse);
      expect(d.updatedText, '5m ago');
    });

    test('under a minute reads "just now"', () {
      expect(format(age: const Duration(seconds: 30)).updatedText, 'just now');
    });

    test('exactly 15 minutes is still fresh; beyond it is stale', () {
      final at15 = format(age: const Duration(minutes: 15));
      expect(at15.isStale, isFalse);
      expect(at15.updatedText, '15m ago');

      final at16 = format(age: const Duration(minutes: 16));
      expect(at16.isStale, isTrue);
      expect(at16.updatedText, 'Stale · 16m ago');
    });

    test('old readings collapse to hours', () {
      final d = format(age: const Duration(minutes: 130));
      expect(d.isStale, isTrue);
      expect(d.updatedText, 'Stale · 2h ago');
    });

    test('missing timestamp is stale even with a BG value', () {
      final d = format(mgdl: 112, age: null);
      expect(d.isStale, isTrue);
      expect(d.updatedText, 'no data');
      expect(d.bgText, '6.2');
    });
  });

  group('IOB line', () {
    test('formats units to one decimal', () {
      expect(format(iob: 1.2).iobText, 'IOB 1.2 U');
      expect(format(iob: 0.0).iobText, 'IOB 0.0 U');
      expect(format(iob: 10.55).iobText, 'IOB 10.6 U');
    });

    test('missing IOB renders placeholder', () {
      expect(format(iob: null).iobText, 'IOB --');
    });
  });

  group('Persisted range tokens (native contract)', () {
    test('tokens match the strings BgWidgetProvider.kt expects', () {
      expect(BgRange.low.token, 'low');
      expect(BgRange.inRange.token, 'inRange');
      expect(BgRange.high.token, 'high');
      expect(BgRange.unknown.token, 'unknown');
    });
  });
}
