/// Clinic-visit prep (§4-4.4): turns the [GlucoseReport] models into a plain-language
/// summary plus a short list of suggested questions to raise at a diabetes appointment.
///
/// Everything here is a deterministic **template** built from the report numbers, so it
/// works with no LLM installed. An optional [ClinicPhraser] can re-word the summary into
/// warmer prose when an on-device model is available; if it returns null (no model, or it
/// declined), the template text is used unchanged.
///
/// Targets referenced are the international consensus (ADA/ATTD): time-in-range ≥70%, time
/// below 70 <4%, below 54 <1%, time above 180 <25%, CV ≤36%. These are conversation
/// starters, not clinical advice.
library;

import '../core/sleep_window.dart';
import '../core/units.dart';
import 'glucose_report.dart';

class ClinicPrep {
  const ClinicPrep({
    required this.rangeLabel,
    required this.summary,
    required this.questions,
  });

  final String rangeLabel;

  /// Plain-language paragraph(s) describing the period.
  final String summary;

  /// Suggested questions, most clinically relevant first.
  final List<String> questions;

  ClinicPrep copyWith({String? summary}) => ClinicPrep(
        rangeLabel: rangeLabel,
        summary: summary ?? this.summary,
        questions: questions,
      );
}

/// Optional warmer-phrasing seam. Default wiring uses [NoopClinicPhraser] so the feature
/// is fully functional with no model installed.
abstract interface class ClinicPhraser {
  /// Return a re-worded [template], or null to keep the template as-is.
  Future<String?> polish(String template);
}

class NoopClinicPhraser implements ClinicPhraser {
  const NoopClinicPhraser();
  @override
  Future<String?> polish(String template) async => null;
}

class ClinicPrepBuilder {
  const ClinicPrepBuilder();

  // Consensus targets (fractions of time / percent).
  static const double _tirGoal = 0.70;
  static const double _tbr70Goal = 0.04;
  static const double _tbr54Goal = 0.01;
  static const double _tar180Goal = 0.25;
  static const double _cvGoal = 36;

  ClinicPrep build({required GlucoseReport report, required GlucoseUnit unit}) {
    final m = report.metrics;
    String g(double mgdl) => '${Mgdl(mgdl).display(unit)} ${unit.label}';
    String pct(double frac) => '${(frac * 100).round()}%';

    final summary = StringBuffer()
      ..write('Over the last ${report.range.label.toLowerCase()} '
          '(${report.daysWithData} ${report.daysWithData == 1 ? 'day' : 'days'} with data), '
          'my time in range (70-180 mg/dL) was ${pct(m.timeInRange)}, '
          'average glucose ${g(m.meanMgdl)}, estimated GMI ${m.gmi.toStringAsFixed(1)}% '
          '(a lab-A1c proxy). ')
      ..write('I was below 70 for ${pct(m.timeBelow70)} of the time '
          '(below 54 for ${pct(m.timeBelow54)}) and above 180 for ${pct(m.timeAbove180)}. ')
      ..write('Glucose variability (CV) was ${m.cvPercent.round()}%. ')
      ..write('There ${report.lowEpisodes.length == 1 ? 'was' : 'were'} '
          '${report.lowEpisodes.length} low and ${report.highEpisodes.length} high '
          'episode${report.highEpisodes.length == 1 ? '' : 's'} lasting at least 15 minutes.');

    // Most notable episodes for the conversation.
    final worstLow = _extreme(report.lowEpisodes, low: true);
    if (worstLow != null) {
      summary.write(' My lowest dip reached ${g(worstLow.extremeMgdl)} '
          '(${_fmtDay(worstLow.start)}, ${worstLow.duration.inMinutes} min).');
    }
    final longestHigh = _longest(report.highEpisodes);
    if (longestHigh != null) {
      summary.write(' My longest high was ${longestHigh.duration.inMinutes} min, '
          'peaking at ${g(longestHigh.extremeMgdl)} (${_fmtDay(longestHigh.start)}).');
    }
    if (!m.sufficient) {
      summary.write(' Note: CGM was only active ${(m.activeFraction * 100).round()}% of '
          'the period, so these numbers are less certain than a full 14-day-or-longer window.');
    }

    final questions = _questions(report);
    return ClinicPrep(
      rangeLabel: report.range.label,
      summary: summary.toString(),
      questions: questions,
    );
  }

  List<String> _questions(GlucoseReport report) {
    final m = report.metrics;
    final qs = <String>[];

    if (m.timeInRange < _tirGoal) {
      qs.add('My time in range is ${(m.timeInRange * 100).round()}%, below the 70% goal - '
          'what changes could help me reach it?');
    }
    // Overnight-weighted lows get a targeted basal question.
    final overnightLows =
        report.lowEpisodes.where((e) => defaultAsleepAt(e.start)).length;
    if (m.timeBelow70 > _tbr70Goal) {
      final where = report.lowEpisodes.isNotEmpty &&
              overnightLows >= (report.lowEpisodes.length + 1) ~/ 2
          ? ' Many of them are overnight - should we look at my overnight basal?'
          : '';
      qs.add('I\'m below 70 mg/dL ${(m.timeBelow70 * 100).round()}% of the time '
          '(goal <4%) - how can we reduce the lows?$where');
    }
    if (m.timeBelow54 > _tbr54Goal) {
      qs.add('I\'ve had readings below 54 mg/dL ${(m.timeBelow54 * 100).toStringAsFixed(1)}% '
          'of the time - how do we prevent serious lows?');
    }
    if (m.timeAbove180 > _tar180Goal) {
      qs.add('I\'m above 180 mg/dL ${(m.timeAbove180 * 100).round()}% of the time '
          '(goal <25%) - what would bring my highs down (basal, carb ratios, corrections)?');
    }
    if (m.cvPercent >= _cvGoal) {
      qs.add('My glucose is quite variable (CV ${m.cvPercent.round()}%, goal 36% or lower) - '
          'could meal timing or basal changes steady it?');
    }
    // Always-useful closers.
    qs.add('Do my pump settings (basal, insulin-to-carb ratios, correction factor) still '
        'look right for these numbers?');
    qs.add('Are my CGM alert thresholds and my overall targets set appropriately?');
    return qs;
  }

  static GlucoseEpisode? _extreme(List<GlucoseEpisode> eps, {required bool low}) {
    if (eps.isEmpty) return null;
    return eps.reduce((a, b) => low
        ? (a.extremeMgdl <= b.extremeMgdl ? a : b)
        : (a.extremeMgdl >= b.extremeMgdl ? a : b));
  }

  static GlucoseEpisode? _longest(List<GlucoseEpisode> eps) {
    if (eps.isEmpty) return null;
    return eps.reduce((a, b) => a.duration >= b.duration ? a : b);
  }

  static String _fmtDay(DateTime d) =>
      '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

/// Apply optional LLM phrasing. If [phraser] returns null the template summary is kept, so
/// this is safe to call with [NoopClinicPhraser] when no model is installed (§4-4.4 AC#4).
Future<ClinicPrep> polishClinicPrep(ClinicPrep prep, ClinicPhraser phraser) async {
  final polished = await phraser.polish(prep.summary);
  if (polished == null || polished.trim().isEmpty) return prep;
  return prep.copyWith(summary: polished.trim());
}
