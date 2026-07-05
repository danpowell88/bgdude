/// The date range a report covers, plus the presets the UI offers. Kept tiny and pure so
/// it can key report providers and travel into the PDF/CSV exporters unchanged.
library;

enum ReportPreset { last7, last14, last30, last90, custom }

extension ReportPresetX on ReportPreset {
  int get days => switch (this) {
        ReportPreset.last7 => 7,
        ReportPreset.last14 => 14,
        ReportPreset.last30 => 30,
        ReportPreset.last90 => 90,
        ReportPreset.custom => 0,
      };

  String get label => switch (this) {
        ReportPreset.last7 => 'Last 7 days',
        ReportPreset.last14 => 'Last 14 days',
        ReportPreset.last30 => 'Last 30 days',
        ReportPreset.last90 => 'Last 90 days',
        ReportPreset.custom => 'Custom',
      };
}

class ReportRange {
  const ReportRange({required this.from, required this.to, required this.preset});

  final DateTime from;
  final DateTime to;
  final ReportPreset preset;

  /// A preset range ending at [now] (defaults handled by the caller, since the runtime
  /// forbids `DateTime.now()` in some contexts — pass it in).
  factory ReportRange.preset(ReportPreset preset, {required DateTime now}) {
    final to = now;
    final from = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: preset.days - 1));
    return ReportRange(from: from, to: to, preset: preset);
  }

  int get days => to.difference(from).inDays + 1;

  String get label => preset == ReportPreset.custom
      ? '${_fmt(from)} - ${_fmt(to)}'
      : preset.label;

  bool contains(DateTime t) => !t.isBefore(from) && !t.isAfter(to);

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
