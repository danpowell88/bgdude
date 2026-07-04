import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../meals/meal_library.dart';
import '../state/providers.dart';
import 'meal_detail_screen.dart';

/// The saved-meal library: searchable list plus an add-meal sheet. Each meal carries
/// its personally learned absorption curve; tapping through opens the detail screen
/// with insights and the pre-bolus coach.
class MealLibraryScreen extends ConsumerStatefulWidget {
  const MealLibraryScreen({super.key, this.embedded = false});

  /// When embedded in the tab shell, drop the Scaffold/AppBar (the shell provides
  /// them) and render just the list + add button.
  final bool embedded;

  @override
  ConsumerState<MealLibraryScreen> createState() => _MealLibraryScreenState();
}

class _MealLibraryScreenState extends ConsumerState<MealLibraryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(mealLibraryProvider);
    final meals = library.search(_query);

    final fab = FloatingActionButton.extended(
      heroTag: 'meal-add-fab',
      onPressed: () => _showAddMealSheet(context),
      icon: const Icon(Icons.add),
      label: const Text('Add meal'),
    );

    final content = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchBar(
              hintText: 'Search meals…',
              leading: const Icon(Icons.search),
              onChanged: (q) => setState(() => _query = q),
            ),
          ),
          Expanded(
            child: meals.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No meals yet — add the ones you eat often and the '
                              'app will learn how each one treats you.'
                          : 'No meals match "$_query".',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: meals.length,
                    itemBuilder: (context, i) {
                      final meal = meals[i];
                      return Card(
                        child: ListTile(
                          leading: Text(meal.emoji,
                              style: const TextStyle(fontSize: 28)),
                          title: Text(meal.name),
                          subtitle: Text(
                            '${meal.carbsGrams.toStringAsFixed(0)} g · '
                            'peak ~+${meal.peakOffsetMinutes} min · '
                            '${meal.outcomes.length} logged',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MealDetailScreen(mealId: meal.id),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );

    if (widget.embedded) {
      return Stack(
        children: [
          content,
          Positioned(right: 16, bottom: 16, child: fab),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Meals')),
      body: content,
      floatingActionButton: fab,
    );
  }

  Future<void> _showAddMealSheet(BuildContext context) async {
    final result = await showModalBottomSheet<SavedMeal>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddMealSheet(),
    );
    if (result != null) {
      ref.read(mealLibraryProvider.notifier).add(result);
    }
  }
}

class _AddMealSheet extends StatefulWidget {
  const _AddMealSheet();

  @override
  State<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<_AddMealSheet> {
  final _name = TextEditingController();
  final _carbs = TextEditingController();
  MealCategory _category = MealCategory.other;
  bool _fatProteinHeavy = false;

  @override
  void dispose() {
    _name.dispose();
    _carbs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final carbs = double.tryParse(_carbs.text);
    final valid = _name.text.trim().isNotEmpty && carbs != null && carbs > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New meal', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            key: const Key('meal-name-field'),
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'Name', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('meal-carbs-field'),
            controller: _carbs,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Carbs (g)', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownMenu<MealCategory>(
            initialSelection: _category,
            label: const Text('Category'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              for (final c in MealCategory.values)
                DropdownMenuEntry(
                    value: c, label: '${c.defaultEmoji}  ${c.label}'),
            ],
            onSelected: (c) =>
                setState(() => _category = c ?? MealCategory.other),
          ),
          SwitchListTile(
            title: const Text('Fat/protein heavy'),
            subtitle: const Text('Pizza-style late absorption'),
            value: _fatProteinHeavy,
            onChanged: (v) => setState(() => _fatProteinHeavy = v),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: valid
                ? () => Navigator.of(context).pop(
                      SavedMeal(
                        id: newMealId(),
                        name: _name.text.trim(),
                        emoji: _category.defaultEmoji,
                        category: _category,
                        carbsGrams: carbs,
                        fatProteinHeavy: _fatProteinHeavy,
                      ),
                    )
                : null,
            child: const Text('Save meal'),
          ),
        ],
      ),
    );
  }
}
