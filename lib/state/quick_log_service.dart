/// Quick-log domain policy (TASK-124). The illness resistance boosts and mood
/// levels used to be magic numbers wired inside the bottom-sheet widget; they are
/// clinical/model policy and live here, testable without a widget tree. The sheet
/// only picks an option and calls [QuickLogService].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feedback/annotations.dart';
import 'providers.dart';

/// How rough a sick day feels — maps to the expected insulin-resistance boost
/// the models apply while illness mode is on.
enum IllnessSeverity { mild, moderate, severe }

extension IllnessSeverityX on IllnessSeverity {
  /// Expected resistance multiplier while ill. Illness reliably raises insulin
  /// needs; the tiers are deliberately conservative (×1.1–×1.35).
  double get resistanceBoost => switch (this) {
        IllnessSeverity.mild => 1.1,
        IllnessSeverity.moderate => 1.2,
        IllnessSeverity.severe => 1.35,
      };

  String get label => switch (this) {
        IllnessSeverity.mild => 'Mild',
        IllnessSeverity.moderate => 'Moderate',
        IllnessSeverity.severe => 'Severe',
      };
}

/// Wellbeing note levels for the mood annotation (drives context correlation).
enum MoodLevel { good, ok, low }

extension MoodLevelX on MoodLevel {
  /// The note string persisted on the mood annotation (kept identical to the
  /// pre-extraction strings so existing annotations keep matching).
  String get note => switch (this) {
        MoodLevel.good => 'Good',
        MoodLevel.ok => 'OK',
        MoodLevel.low => 'Low',
      };

  String get label => switch (this) {
        MoodLevel.good => '🙂 Good',
        MoodLevel.ok => '😐 OK',
        MoodLevel.low => '😟 Low',
      };
}

/// Thin orchestration over the illness/mood flows so the UI never touches the
/// policy directly.
class QuickLogService {
  QuickLogService(this._ref);
  final Ref _ref;

  /// Turn illness mode on at [severity]'s boost (tags the sick period for
  /// retraining as a side effect of the mode).
  void startIllness(IllnessSeverity severity) => _ref
      .read(illnessModeProvider.notifier)
      .activate(boost: severity.resistanceBoost);

  void endIllness() => _ref.read(illnessModeProvider.notifier).deactivate();

  Future<void> logMood(MoodLevel level) => _ref
      .read(appJobsProvider)
      .logContext(AnnotationKind.mood, note: level.note);
}

final quickLogServiceProvider =
    Provider<QuickLogService>((ref) => QuickLogService(ref));
