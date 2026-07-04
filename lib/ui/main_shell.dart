import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/units.dart';
import '../state/providers.dart';
import 'bolus_advisor_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'meal_library_screen.dart';
import 'predictions_screen.dart';
import 'quick_log_sheet.dart';
import 'settings_screen.dart';

/// The app's home: a four-tab shell (Today · Predict · Insights · Meals) with the
/// bolus advisor always one tap away. Replaces the old pile of separate screens so
/// related things — models, sensitivity, sickness — sit together.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _titles = ['Today', 'Predict', 'Insights', 'Meals'];

  @override
  void initState() {
    super.initState();
    // Run background jobs once the first frame is up (meal-outcome loop, prediction
    // reconciliation, forecaster retraining).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appJobsProvider).runStartup();
    });
  }

  @override
  Widget build(BuildContext context) {
    final devMode = ref.watch(devModeProvider);
    final unit = ref.watch(glucoseUnitProvider);

    final body = switch (_index) {
      0 => const TodayTab(),
      1 => const PredictionsScreen(),
      2 => const InsightsScreen(),
      _ => const MealLibraryScreen(embedded: true),
    };

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(_titles[_index]),
            if (devMode) ...[
              const SizedBox(width: 8),
              const Chip(
                label: Text('DEV'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Quick log',
            onPressed: () => QuickLogSheet.show(context),
          ),
          IconButton(
            icon: Icon(
                unit == GlucoseUnit.mmol ? Icons.water_drop : Icons.science),
            tooltip: 'Toggle units',
            onPressed: () => ref.read(glucoseUnitProvider.notifier).state =
                unit == GlucoseUnit.mmol ? GlucoseUnit.mgdl : GlucoseUnit.mmol,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: body,
      // The Meals tab has its own "Add meal" FAB, so suppress the shell FAB there to
      // avoid two overlapping buttons in the same corner.
      floatingActionButton: _index == 3
          ? null
          : FloatingActionButton.extended(
              heroTag: 'shell-bolus-fab',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const BolusAdvisorScreen()),
              ),
              icon: const Icon(Icons.calculate),
              label: const Text('Bolus'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Today'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Predict'),
          NavigationDestination(
              icon: Icon(Icons.lightbulb_outline),
              selectedIcon: Icon(Icons.lightbulb),
              label: 'Insights'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_outlined),
              selectedIcon: Icon(Icons.restaurant),
              label: 'Meals'),
        ],
      ),
    );
  }
}
