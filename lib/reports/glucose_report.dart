/// The Glucose report — the clinical anchor of the reporting feature. Composes the
/// existing [MetricsCalculator] (TIR/GMI/CV/coverage) and [AgpCalculator] (percentile
/// bands) with hypo/hyper episode detection, over the report's *confirmed* CGM data.
///
/// "Confirmed" here means sensor artifacts are removed: readings flagged as warm-up, and
/// any window the user annotated as a compression low or sensor error, are excluded so
/// the numbers reflect real glucose exposure. Site-failure highs are deliberately KEPT —
/// they are real exposure, not a sensor artifact.
library;

import '../analytics/metrics.dart';
import '../core/samples.dart';
import '../feedback/annotations.dart';
import 'report_range.dart';

/// The annotation kinds that mark *sensor artifacts* (not real glucose) and are excluded
/// from glucose statistics.
const Set<AnnotationKind> kArtifactAnnotationKinds = {
  AnnotationKind.sensorWarmup,
  AnnotationKind.compressionLow,
};

class GlucoseEpisode {
  const GlucoseEpisode({
    required this.start,
    required this.end,
    required this.extremeMgdl,
    required this.isLow,
  });

  final DateTime start;
  final DateTime end;

  /// Nadir for a low, peak for a high (mg/dL).
  final double extremeMgdl;
  final bool isLow;

  Duration get duration => end.difference(start);
}

/// Detects hypo/hyper episodes: runs past a threshold lasting at least [minMinutes],
/// merging runs separated by less than [mergeGapMinutes] (brief blips don't split one
/// episode into several).
class EpisodeDetector {
  const EpisodeDetector({
    this.lowThresholdMgdl = 70,
    this.highThresholdMgdl = 250,
    this.minMinutes = 15,
    this.mergeGapMinutes = 15,
  });

  final double lowThresholdMgdl;
  final double highThresholdMgdl;
  final int minMinutes;
  final int mergeGapMinutes;

  List<GlucoseEpisode> detect(List<CgmSample> samples, {required bool low}) {
    final sorted = [...samples]
      ..removeWhere((s) => s.sensorWarmup || s.mgdl <= 0)
      ..sort((a, b) => a.time.compareTo(b.time));

    bool past(double v) =>
        low ? v < lowThresholdMgdl : v > highThresholdMgdl;

    // Build raw runs of consecutive past-threshold readings.
    final runs = <List<CgmSample>>[];
    List<CgmSample>? cur;
    for (final s in sorted) {
      if (past(s.mgdl)) {
        (cur ??= <CgmSample>[]).add(s);
      } else if (cur != null) {
        runs.add(cur);
        cur = null;
      }
    }
    if (cur != null) runs.add(cur);

    // Merge runs whose gap is small.
    final merged = <List<CgmSample>>[];
    for (final r in runs) {
      if (merged.isNotEmpty) {
        final prev = merged.last;
        final gap = r.first.time.difference(prev.last.time).inMinutes;
        if (gap <= mergeGapMinutes) {
          prev.addAll(r);
          continue;
        }
      }
      merged.add([...r]);
    }

    final out = <GlucoseEpisode>[];
    for (final run in merged) {
      final dur = run.last.time.difference(run.first.time);
      if (dur.inMinutes < minMinutes) continue;
      final extreme = low
          ? run.map((s) => s.mgdl).reduce((a, b) => a < b ? a : b)
          : run.map((s) => s.mgdl).reduce((a, b) => a > b ? a : b);
      out.add(GlucoseEpisode(
        start: run.first.time,
        end: run.last.time,
        extremeMgdl: extreme,
        isLow: low,
      ));
    }
    return out;
  }
}

class GlucoseReport {
  const GlucoseReport({
    required this.range,
    required this.generatedAt,
    required this.metrics,
    required this.agp,
    required this.lowEpisodes,
    required this.highEpisodes,
    required this.daysWithData,
    required this.excludedSampleCount,
  });

  final ReportRange range;
  final DateTime generatedAt;
  final GlucoseMetrics metrics;
  final List<AgpBucket> agp;
  final List<GlucoseEpisode> lowEpisodes;
  final List<GlucoseEpisode> highEpisodes;

  /// Distinct calendar days with at least one confirmed reading.
  final int daysWithData;

  /// How many sensor-artifact readings were dropped (transparency).
  final int excludedSampleCount;

  bool get hasData => metrics.readingCount > 0;
}

class GlucoseReportBuilder {
  const GlucoseReportBuilder({
    this.metrics = const MetricsCalculator(),
    this.agp = const AgpCalculator(),
    this.episodes = const EpisodeDetector(),
  });

  final MetricsCalculator metrics;
  final AgpCalculator agp;
  final EpisodeDetector episodes;

  /// The confirmed readings: in-range, non-warm-up, and not inside a sensor-artifact
  /// annotation. Shared by [build] and by raw-CSV export so both agree exactly.
  static List<CgmSample> confirmedSamples({
    required List<CgmSample> cgm,
    required List<Annotation> annotations,
    required ReportRange range,
  }) {
    final artifacts =
        annotations.where((a) => kArtifactAnnotationKinds.contains(a.kind)).toList();
    return [
      for (final s in cgm)
        if (range.contains(s.time) &&
            !s.sensorWarmup &&
            s.mgdl > 0 &&
            !artifacts.any((a) => a.covers(s.time)))
          s,
    ];
  }

  GlucoseReport build({
    required List<CgmSample> cgm,
    required List<Annotation> annotations,
    required ReportRange range,
    required DateTime now,
  }) {
    final confirmed =
        confirmedSamples(cgm: cgm, annotations: annotations, range: range);
    final inRangeValid =
        cgm.where((s) => range.contains(s.time) && !s.sensorWarmup && s.mgdl > 0);
    final excluded = inRangeValid.length - confirmed.length;

    final days = <String>{
      for (final s in confirmed) '${s.time.year}-${s.time.month}-${s.time.day}',
    };

    return GlucoseReport(
      range: range,
      generatedAt: now,
      metrics: metrics.compute(confirmed),
      agp: agp.compute(confirmed),
      lowEpisodes: episodes.detect(confirmed, low: true),
      highEpisodes: episodes.detect(confirmed, low: false),
      daysWithData: days.length,
      excludedSampleCount: excluded,
    );
  }
}
