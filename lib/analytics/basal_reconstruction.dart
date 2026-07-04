/// Reconstructs basal-rate segments from a stream of point observations.
///
/// In real mode the pump reports only the *current* basal rate per snapshot (Control-IQ
/// modulates it continuously); to compute basal IOB we need it as time segments. This
/// turns an ordered list of (time, unitsPerHour) observations into contiguous
/// [BasalSegment]s, each spanning from one observation until the rate next changes.
library;

import '../core/samples.dart';

class BasalReconstructor {
  const BasalReconstructor({this.maxGap = const Duration(minutes: 30)});

  /// If two observations are further apart than this, the segment is closed at
  /// observation+maxGap rather than assuming the rate held across a long data gap.
  final Duration maxGap;

  /// Build segments from ordered (time, rate) observations. [until] closes the final
  /// open segment (defaults to the last observation time).
  List<BasalSegment> reconstruct(
    List<({DateTime time, double unitsPerHour})> observations, {
    DateTime? until,
  }) {
    final obs = [...observations]..sort((a, b) => a.time.compareTo(b.time));
    if (obs.isEmpty) return const [];

    final segments = <BasalSegment>[];
    for (var i = 0; i < obs.length; i++) {
      final start = obs[i].time;
      final rate = obs[i].unitsPerHour;
      DateTime end;
      if (i + 1 < obs.length) {
        final next = obs[i + 1].time;
        end = next.difference(start) > maxGap ? start.add(maxGap) : next;
      } else {
        final u = until ?? start;
        end = u.difference(start) > maxGap ? start.add(maxGap) : u;
        if (!end.isAfter(start)) continue; // no duration for a lone final point
      }
      // Merge with the previous segment if the rate is unchanged and contiguous.
      if (segments.isNotEmpty &&
          (segments.last.unitsPerHour - rate).abs() < 1e-6 &&
          segments.last.end == start) {
        final prev = segments.removeLast();
        segments.add(BasalSegment(
            start: prev.start, end: end, unitsPerHour: rate));
      } else {
        segments.add(BasalSegment(start: start, end: end, unitsPerHour: rate));
      }
    }
    return segments;
  }
}
