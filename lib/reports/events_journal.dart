/// The Events journal: a single, filterable, newest-first timeline of confirmed events —
/// user annotations, pump alarms/alerts/cartridge changes, infusion-site/sensor changes,
/// and hypo/hyper episodes — for the range. A clinic-visit-ready log built from real data.
library;

import '../core/units.dart';
import '../feedback/annotations.dart';
import '../logging/device_changes.dart';
import '../pump/pump_events.dart';
import 'glucose_report.dart';
import 'report_range.dart';

enum JournalCategory { annotation, pumpEvent, deviceChange, lowEpisode, highEpisode }

extension JournalCategoryX on JournalCategory {
  String get label => switch (this) {
        JournalCategory.annotation => 'Note',
        JournalCategory.pumpEvent => 'Pump',
        JournalCategory.deviceChange => 'Device',
        JournalCategory.lowEpisode => 'Low',
        JournalCategory.highEpisode => 'High',
      };
}

class JournalEntry {
  const JournalEntry({
    required this.time,
    required this.category,
    required this.title,
    required this.detail,
  });

  final DateTime time;
  final JournalCategory category;
  final String title;
  final String detail;
}

class EventsJournalBuilder {
  const EventsJournalBuilder();

  /// Merge every source into one sorted timeline. [unit] formats episode extremes.
  List<JournalEntry> build({
    required ReportRange range,
    required List<Annotation> annotations,
    required List<PumpEvent> pumpEvents,
    required List<DeviceChange> deviceChanges,
    required List<GlucoseEpisode> lowEpisodes,
    required List<GlucoseEpisode> highEpisodes,
    required GlucoseUnit unit,
  }) {
    final out = <JournalEntry>[];

    for (final a in annotations) {
      if (!range.contains(a.start)) continue;
      out.add(JournalEntry(
        time: a.start,
        category: JournalCategory.annotation,
        title: a.kind.label,
        detail: [
          if (a.kind.relabelsCarbs && a.carbsGrams > 0)
            '${a.carbsGrams.round()}g',
          if (a.note.isNotEmpty) a.note,
        ].join(' · '),
      ));
    }

    for (final e in pumpEvents) {
      if (!range.contains(e.time)) continue;
      out.add(JournalEntry(
        time: e.time,
        category: JournalCategory.pumpEvent,
        title: e.kind.label,
        detail: e.detail,
      ));
    }

    for (final c in deviceChanges) {
      if (!range.contains(c.changedAt)) continue;
      out.add(JournalEntry(
        time: c.changedAt,
        category: JournalCategory.deviceChange,
        title: '${c.kind.label} changed',
        detail: '',
      ));
    }

    void addEpisodes(List<GlucoseEpisode> eps, JournalCategory cat) {
      for (final e in eps) {
        if (!range.contains(e.start)) continue;
        out.add(JournalEntry(
          time: e.start,
          category: cat,
          title: '${e.isLow ? 'Low' : 'High'} to '
              '${Mgdl(e.extremeMgdl).display(unit)} ${unit.label}',
          detail: '${e.duration.inMinutes} min',
        ));
      }
    }

    addEpisodes(lowEpisodes, JournalCategory.lowEpisode);
    addEpisodes(highEpisodes, JournalCategory.highEpisode);

    out.sort((a, b) => b.time.compareTo(a.time));
    return out;
  }
}
