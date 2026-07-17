import 'package:bgdude/core/units.dart';
import 'package:bgdude/ui/widgets/prediction_chart.dart';
import 'package:flutter_test/flutter_test.dart';

// TASK-155 coverage: pure data-formatting helpers behind PredictionChart's hover
// tooltip (line label, relative-time label, display-value formatting). These are
// exercised indirectly by the widget tests but not testably reached at the
// individual-branch level from a widget test alone (fl_chart only invokes the
// tooltip callbacks on an actual pointer-hover gesture) -- unit-testing the
// static helpers directly gives real branch coverage of this logic.
void main() {
  group('PredictionChart.labelForBarIndex', () {
    const labels = ['CGM', 'IOB', 'Predicted'];

    test('returns the label at a valid index', () {
      expect(PredictionChart.labelForBarIndex(labels, 0), 'CGM');
      expect(PredictionChart.labelForBarIndex(labels, 2), 'Predicted');
    });

    test('returns empty string for an out-of-range index', () {
      expect(PredictionChart.labelForBarIndex(labels, -1), '');
      expect(PredictionChart.labelForBarIndex(labels, 3), '');
      expect(PredictionChart.labelForBarIndex(const [], 0), '');
    });
  });

  group('PredictionChart.minutesFromNowLabel', () {
    test('zero minutes reads as "now"', () {
      expect(PredictionChart.minutesFromNowLabel(0), 'now');
      // Rounds to zero.
      expect(PredictionChart.minutesFromNowLabel(0.4), 'now');
    });

    test('positive sub-hour minutes get a leading +', () {
      expect(PredictionChart.minutesFromNowLabel(45), '+45m');
    });

    test('negative sub-hour minutes get a leading -', () {
      expect(PredictionChart.minutesFromNowLabel(-30), '-30m');
    });

    test('whole hours have no trailing minutes', () {
      expect(PredictionChart.minutesFromNowLabel(120), '+2h');
      expect(PredictionChart.minutesFromNowLabel(-180), '-3h');
    });

    test('hours with a remainder append the minutes', () {
      expect(PredictionChart.minutesFromNowLabel(90), '+1h30m');
      expect(PredictionChart.minutesFromNowLabel(-100), '-1h40m');
    });

    test('rounds fractional minutes before formatting', () {
      // 89.6 rounds to 90 -> +1h30m, not truncated to +1h29m.
      expect(PredictionChart.minutesFromNowLabel(89.6), '+1h30m');
    });
  });

  group('PredictionChart.formatDisplayValue', () {
    test('mg/dL rounds to a whole number', () {
      expect(PredictionChart.formatDisplayValue(120.4, GlucoseUnit.mgdl),
          '120 mg/dL');
      expect(PredictionChart.formatDisplayValue(120.6, GlucoseUnit.mgdl),
          '121 mg/dL');
    });

    test('mmol/L keeps one decimal place', () {
      expect(PredictionChart.formatDisplayValue(6.66, GlucoseUnit.mmol),
          '6.7 mmol/L');
      expect(
          PredictionChart.formatDisplayValue(6.0, GlucoseUnit.mmol), '6.0 mmol/L');
    });
  });
}
