import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/kv_store.dart';
import '../food/food_item.dart';
import '../meals/meal_library.dart';
import '../state/providers.dart';
import 'barcode_scan_screen.dart';
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

class _AddMealSheet extends ConsumerStatefulWidget {
  const _AddMealSheet();

  @override
  ConsumerState<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends ConsumerState<_AddMealSheet> {
  final _name = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _protein = TextEditingController();
  MealCategory _category = MealCategory.other;
  bool _fatProteinHeavy = false;

  @override
  void dispose() {
    _name.dispose();
    _carbs.dispose();
    _fat.dispose();
    _protein.dispose();
    super.dispose();
  }

  /// Prefill the form from a looked-up food. Uses the product's serving size when known,
  /// else per-100 g, keeping carbs and fat/protein on the same basis for the FPU coach.
  /// Every value lands in an editable field, so the user can override anything the
  /// database got wrong (or adjust to their actual portion).
  void _prefill(FoodItem item) {
    final grams = item.servingSizeG ?? 100.0;
    setState(() {
      _name.text = item.displayName;
      final carbs = item.carbsForGrams(grams);
      if (carbs != null) _carbs.text = carbs.round().toString();
      final fat = item.fatForGrams(grams);
      final protein = item.proteinForGrams(grams);
      _fat.text = fat == null ? '' : fat.round().toString();
      _protein.text = protein == null ? '' : protein.round().toString();
      _refreshFatProteinHeavy();
    });
  }

  /// Auto-toggle fat/protein-heavy when the entered fat+protein add ≥1 fat-protein unit.
  void _refreshFatProteinHeavy() {
    final fat = double.tryParse(_fat.text) ?? 0;
    final protein = double.tryParse(_protein.text) ?? 0;
    _fatProteinHeavy = (fat * 9 + protein * 4) / 100.0 >= 1.0;
  }

  /// Show the one-time notice before the first online (Open Food Facts) lookup.
  Future<bool> _confirmOnlineLookup() async {
    if (!ref.read(barcodeLookupEnabledProvider)) return true; // offline-only, no notice
    const key = 'off_notice_shown';
    if ((await KvStore.getBool(key)) == true) return true;
    if (!mounted) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Food lookup'),
        content: const Text(
            'Looking up a barcode or food name sends just that code/text to Open Food '
            'Facts, a free public database. No personal or health data is sent. You can '
            'turn this off in Settings (offline Australian foods still work).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK')),
        ],
      ),
    );
    if (ok == true) await KvStore.setBool(key, true);
    return ok ?? false;
  }

  Future<void> _scan() async {
    if (!await _confirmOnlineLookup()) return;
    if (!mounted) return;
    final gtin = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (gtin == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final db = await ref.read(foodDatabaseProvider.future);
    final item = await db.lookupBarcode(gtin);
    if (!mounted) return;
    if (item == null || !item.hasCarbs) {
      messenger.showSnackBar(SnackBar(
          content: Text(item == null
              ? 'Barcode not found — enter it manually.'
              : 'Found "${item.name}" but no carbs on record — enter manually.')));
      if (item != null) _prefill(item);
      return;
    }
    _prefill(item);
  }

  Future<void> _search() async {
    if (!await _confirmOnlineLookup()) return;
    if (!mounted) return;
    final item = await showDialog<FoodItem>(
      context: context,
      builder: (_) => _FoodSearchDialog(ref: ref),
    );
    if (item != null && mounted) _prefill(item);
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan barcode'),
                  onPressed: _scan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Search foods'),
                  onPressed: _search,
                ),
              ),
            ],
          ),
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('meal-fat-field'),
                  controller: _fat,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Fat (g)',
                      helperText: 'optional',
                      border: OutlineInputBorder()),
                  onChanged: (_) => setState(_refreshFatProteinHeavy),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('meal-protein-field'),
                  controller: _protein,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Protein (g)',
                      helperText: 'optional',
                      border: OutlineInputBorder()),
                  onChanged: (_) => setState(_refreshFatProteinHeavy),
                ),
              ),
            ],
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
                        fatGrams: double.tryParse(_fat.text) ?? 0,
                        proteinGrams: double.tryParse(_protein.text) ?? 0,
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

/// A simple food-name search dialog backed by the active [foodDatabaseProvider].
class _FoodSearchDialog extends StatefulWidget {
  const _FoodSearchDialog({required this.ref});
  final WidgetRef ref;
  @override
  State<_FoodSearchDialog> createState() => _FoodSearchDialogState();
}

class _FoodSearchDialogState extends State<_FoodSearchDialog> {
  final _q = TextEditingController();
  List<FoodItem> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _q.text.trim();
    if (q.length < 2) return;
    setState(() => _loading = true);
    try {
      final db = await widget.ref.read(foodDatabaseProvider.future);
      final r = await db.searchByName(q);
      if (mounted) setState(() => _results = r);
    } catch (_) {
      // ignore — leave results as-is
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search foods'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _q,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'e.g. white rice',
                suffixIcon: IconButton(
                    icon: const Icon(Icons.search), onPressed: _run),
              ),
              onSubmitted: (_) => _run(),
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final f in _results)
                    ListTile(
                      dense: true,
                      title: Text(f.displayName),
                      subtitle: Text(f.hasCarbs
                          ? '${f.carbsPer100g!.round()} g carbs / 100 g · ${f.source}'
                          : f.source),
                      onTap: () => Navigator.of(context).pop(f),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
      ],
    );
  }
}
