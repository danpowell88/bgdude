import 'package:bgdude/insights/sleep_insight.dart';
import 'package:flutter_test/flutter_test.dart';

SleepNight _night(int day, double hours, double cv, double tir) => SleepNight(
      night: DateTime(2026, 6, day),
      sleepHours: hours,
      overnightCvPercent: cv,
      overnightTir: tir,
    );

void main() {
  group('SleepInsightAnalyzer', () {
    test('more sleep clearly correlates with lower CV → negative, steadier',
        () {
      // Longer sleep → lower CV, higher TIR. 12 nights, both groups populated.
      final nights = <SleepNight>[
        _night(1, 5.0, 44, 0.60),
        _night(2, 5.5, 42, 0.62),
        _night(3, 6.0, 40, 0.65),
        _night(4, 6.0, 41, 0.63),
        _night(5, 6.5, 38, 0.68),
        _night(6, 6.8, 37, 0.70),
        _night(7, 7.0, 34, 0.78),
        _night(8, 7.2, 33, 0.80),
        _night(9, 7.5, 32, 0.82),
        _night(10, 7.8, 31, 0.83),
        _night(11, 8.0, 30, 0.85),
        _night(12, 8.5, 29, 0.88),
      ];

      final insight = const SleepInsightAnalyzer().analyze(nights);

      expect(insight.hasSignal, isTrue);
      expect(insight.correlation, lessThan(0)); // more sleep → lower CV
      expect(insight.correlation, inInclusiveRange(-1.0, 1.0));
      expect(insight.nights, 12);
      expect(insight.message.toLowerCase(), contains('steadier'));
      expect(insight.message, contains('CV'));
      expect(insight.message, contains('time in range'));
    });

    test('too few nights → hasSignal false', () {
      final nights = <SleepNight>[
        _night(1, 6.0, 40, 0.60),
        _night(2, 7.5, 32, 0.80),
        _night(3, 8.0, 30, 0.85),
      ];

      final insight = const SleepInsightAnalyzer().analyze(nights);

      expect(insight.hasSignal, isFalse);
      expect(insight.correlation, 0);
      expect(insight.nights, 3);
      expect(insight.message.toLowerCase(), contains('not enough nights'));
    });

    test('only one sleep group populated → hasSignal false', () {
      // 10 nights but all short-sleep — no ≥7h group to compare.
      final nights = List.generate(
        10,
        (i) => _night(i + 1, 5.0 + i * 0.1, 42 - i.toDouble(), 0.60),
      );

      final insight = const SleepInsightAnalyzer().analyze(nights);

      expect(insight.hasSignal, isFalse);
      expect(insight.message.toLowerCase(), contains('not enough nights'));
    });

    test('constant sleep series → correlation guarded to 0', () {
      // All 7.5h (constant x → zero variance), so Pearson is undefined → 0.
      final nights = List.generate(
        12,
        (i) => _night(i + 1, 7.5, 30 + (i.isEven ? 2.0 : -2.0), 0.80),
      );

      final insight = const SleepInsightAnalyzer().analyze(nights);

      expect(insight.correlation, 0);
      // Constant sleep means everyone is in the "good" group → no short group.
      expect(insight.hasSignal, isFalse);
    });

    test('correlation stays within [-1, 1]', () {
      final nights = List.generate(
        14,
        (i) => _night(i + 1, 5.0 + i * 0.25, 45 - i * 1.0, 0.55 + i * 0.02),
      );
      final insight = const SleepInsightAnalyzer().analyze(nights);
      expect(insight.correlation, inInclusiveRange(-1.0, 1.0));
    });
  });
}
