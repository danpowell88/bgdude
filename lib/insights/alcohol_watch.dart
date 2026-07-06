/// Alcohol raises the risk of *delayed* hypoglycemia — overnight and into the next
/// morning, up to ~12 h after drinking (suppressed hepatic glucose output + reduced
/// growth-hormone response). While an alcohol annotation is recent, we widen the
/// low-alert margin so predicted lows fire earlier and with more lead time.
library;

import '../feedback/annotations.dart';

class AlcoholWatch {
  const AlcoholWatch({
    this.window = const Duration(hours: 14),
    this.lowBumpMgdl = 10,
  });

  /// How long after an alcohol annotation the heightened watch stays active — long
  /// enough to cover an evening drink through the next morning.
  final Duration window;

  /// Additive margin on the user's base low line while the watch is active, so
  /// alerts lead earlier (the default 70 line becomes 80 — the raised threshold the
  /// delayed-hypo evidence points at). Additive rather than absolute so a custom
  /// base line keeps its lead; consumed by `EffectiveLowThreshold.compute` (TASK-147).
  final double lowBumpMgdl;

  bool activeAt(Iterable<Annotation> annotations, DateTime now) => annotations.any(
        (a) =>
            a.kind == AnnotationKind.alcohol &&
            !a.start.isAfter(now) &&
            now.difference(a.start) <= window,
      );
}
