/// The meal-outcome learning loop: for each logged meal that's now ≥ [maturityHours]
/// old and not yet learned, pull the post-meal CGM from history, compute the outcome,
/// and update the saved meal's learned curve. Returns the meals it updated.
library;

import '../data/history_repository.dart';
import 'meal_library.dart';
import 'meal_log.dart';

class MealOutcomeResult {
  const MealOutcomeResult({required this.updatedLog, required this.learned});

  /// The log with matured entries marked learned.
  final List<MealLogEntry> updatedLog;

  /// (meal, outcome) pairs to apply to the library.
  final List<({SavedMeal meal, MealOutcome outcome})> learned;
}

class MealOutcomeService {
  const MealOutcomeService({this.maturityHours = 3});

  final int maturityHours;

  /// Pure-ish: reads CGM from [repo], but applies nothing — the caller updates the
  /// library and persists the log. This keeps it testable with an in-memory repo.
  Future<MealOutcomeResult> process({
    required List<MealLogEntry> log,
    required MealLibrary library,
    required HistoryRepository repo,
    required DateTime now,
  }) async {
    final updatedLog = <MealLogEntry>[];
    final learned = <({SavedMeal meal, MealOutcome outcome})>[];

    for (final entry in log) {
      if (entry.learned) {
        updatedLog.add(entry);
        continue;
      }
      final matured = now.difference(entry.eatenAt).inMinutes >= maturityHours * 60;
      final meal = library.findById(entry.mealId);
      if (!matured || meal == null) {
        updatedLog.add(entry);
        continue;
      }

      final cgm = await repo.cgm(
        entry.eatenAt.subtract(const Duration(minutes: 30)),
        entry.eatenAt.add(const Duration(hours: 3, minutes: 30)),
      );
      if (cgm.length < 6) {
        updatedLog.add(entry); // not enough data yet; try again later
        continue;
      }

      final outcome = MealOutcome.fromCgm(
        eatenAt: entry.eatenAt,
        preBolusMinutes: entry.preBolusMinutes,
        bolusUnits: entry.bolusUnits,
        postMealCgm: cgm,
      );
      learned.add((meal: meal, outcome: outcome));
      updatedLog.add(entry.copyWith(learned: true));
    }

    return MealOutcomeResult(updatedLog: updatedLog, learned: learned);
  }
}
