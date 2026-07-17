import 'package:flutter/material.dart';

import '../../timeline/day_event.dart';

/// A thin strip of tappable event-icon markers aligned to a chart's own x-domain
/// (TASK-155), so a glucose curve's shape can be read against *why* it moved —
/// meals, boluses, detected rises, highs/lows, compression artefacts.
///
/// Positioned as its own row directly under the chart it annotates (rather than
/// drawn inside the chart itself) so it never competes with fl_chart's own touch
/// handling. [minX]/[maxX] and [leftAxisWidth]/[rightAxisWidth] must match the
/// values the chart above it was built with, or markers will drift out of
/// alignment with the curve.
class EventMarkerBar extends StatelessWidget {
  const EventMarkerBar({
    super.key,
    required this.events,
    required this.minX,
    required this.maxX,
    required this.xForTime,
    required this.onTap,
    this.leftAxisWidth = 0,
    this.rightAxisWidth = 0,
    this.height = 22,
  });

  /// Only [DayEvent.explainable] entries are shown — every marker this bar draws
  /// opens Explain-this-reading on tap, so non-explainable events (logged meals/
  /// boluses, sensor/site changes) are left out rather than rendered inert.
  final List<DayEvent> events;

  final double minX;
  final double maxX;

  /// Maps an event's time onto the same x-domain the chart above uses (e.g.
  /// minutes-from-now, or hour-of-day).
  final double Function(DateTime time) xForTime;

  final void Function(DayEvent event) onTap;

  final double leftAxisWidth;
  final double rightAxisWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final e in events)
        if (e.explainable) e,
    ]..sort((a, b) => a.time.compareTo(b.time));

    return SizedBox(
      height: height,
      child: visible.isEmpty
          ? null
          : LayoutBuilder(builder: (context, constraints) {
              final plotWidth =
                  (constraints.maxWidth - leftAxisWidth - rightAxisWidth)
                      .clamp(0.0, double.infinity);
              final span = maxX - minX;
              // A Stack with only Positioned children has no non-positioned child to
              // size itself from, so it collapses to zero width under the loose
              // constraint from the outer SizedBox -- painting still works (Clip.none
              // draws children outside that zero-width box) but hit-testing does not,
              // since RenderBox checks containment against the PARENT's own size
              // before testing children. Pinning the Stack's size to the full plot
              // width fixes tap targets without changing anything visually.
              // A Stack with only Positioned children has no non-positioned child to
              // size itself from, so it collapses to zero width under the loose
              // constraint from the outer SizedBox -- painting still works (Clip.none
              // draws children outside that zero-width box) but hit-testing does not,
              // since RenderBox checks containment against the PARENT's own size
              // before testing children. Pinning the Stack's size to the full plot
              // width fixes tap targets without changing anything visually.
              return SizedBox(
                width: constraints.maxWidth,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final e in visible)
                      if (span > 0)
                        Builder(builder: (context) {
                          final x = xForTime(e.time);
                          if (x < minX || x > maxX) {
                            return const SizedBox.shrink();
                          }
                          final left = leftAxisWidth +
                              (x - minX) / span * plotWidth -
                              (height / 2);
                          return Positioned(
                            left: left,
                            child: Tooltip(
                              message: '${e.title}\n${e.detail}',
                              child: InkWell(
                                key: ValueKey('event-marker-${e.id}'),
                                borderRadius: BorderRadius.circular(height / 2),
                                onTap: () => onTap(e),
                                child: SizedBox(
                                  width: height,
                                  height: height,
                                  child: Center(
                                    child: Text(e.type.emoji,
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                  ],
                ),
              );
            }),
    );
  }
}
