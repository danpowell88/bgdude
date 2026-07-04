/// Drift table definitions for the meal library. Kept separate from the domain types
/// in `meals/meal_library.dart` (pure Dart) — this file is the persistence shape only.
///
/// These tables are registered in the `@DriftDatabase(tables: [...])` list in
/// `data/database.dart`. Outcomes are stored as a JSON blob per meal rather than a
/// join table: the history is bounded (20 entries) and always read/written whole.
library;

import 'package:drift/drift.dart';

@DataClassName('SavedMealRow')
class SavedMeals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get emoji => text().withDefault(const Constant('🍽️'))();
  TextColumn get category => text().withDefault(const Constant('other'))();
  RealColumn get carbsGrams => real()();
  BoolColumn get fatProteinHeavy => boolean().withDefault(const Constant(false))();
  IntColumn get absorptionMinutes => integer().withDefault(const Constant(180))();
  IntColumn get peakOffsetMinutes => integer().withDefault(const Constant(90))();

  /// JSON array of MealOutcome.toJson() maps (bounded to 20 by the domain layer).
  TextColumn get outcomesJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};
}
