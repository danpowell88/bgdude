import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_flags.dart';
import '../state/persisted_state_notifier.dart';
import '../state/providers.dart';
import 'bolus_advisor_screen.dart';
import 'db_recovery_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'meal_library_screen.dart';
import 'pairing_dialog.dart';
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

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _titles = ['Today', 'Predict', 'Insights', 'Meals'];

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // TASK-179: the day window only rolls on ingest; after hours in the
    // background (overnight, doze) re-anchor it as soon as the app resumes.
    if (lifecycle == AppLifecycleState.resumed) {
      ref.read(dayHistoryControllerProvider.notifier).reload();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Run background jobs once the first frame is up (meal-outcome loop, prediction
    // reconciliation, forecaster retraining).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appJobsProvider).runStartup();
    });
  }

  /// Leave demo mode: switch back to the real pump bridge (persisted) and kick off a
  /// scan so a paired pump reconnects — or the pairing prompt appears if none is paired.
  Future<void> _exitDemo() async {
    final messenger = ScaffoldMessenger.of(context);
    ref.read(devModeProvider.notifier).state = false;
    await (await AppFlags.load()).setDevMode(false);
    try {
      await ref.read(pumpClientProvider).startScan();
    } catch (_) {}
    messenger.showSnackBar(
      const SnackBar(content: Text('Demo mode off — connecting to your pump…')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Auto-prompt for the pairing code when the pump asks, and surface pump errors.
    PumpPairingListener.attach(ref, context);

    final devMode = ref.watch(devModeProvider);
    final dbError = ref.watch(dbOpenErrorProvider);

    final tab = switch (_index) {
      0 => const TodayTab(),
      1 => const PredictionsScreen(),
      2 => const InsightsScreen(),
      _ => const MealLibraryScreen(embedded: true),
    };
    // P1-6: a persistent banner when storage failed to open (running in-memory).
    // TASK-188: plus one per settings-reset notice (corrupt persisted state) —
    // clinical settings must be reviewed, not silently defaulted. Dismissible.
    final body = ValueListenableBuilder<List<String>>(
      valueListenable: CorruptStateNotices.notices,
      builder: (context, notices, _) {
        final banners = [
          if (dbError != null)
            (message: dbError, dismissible: false, isDbError: true),
          for (final n in notices)
            (message: n, dismissible: true, isDbError: false),
        ];
        if (banners.isEmpty) return tab;
        final cs = Theme.of(context).colorScheme;
        return Column(
          children: [
            for (final b in banners)
              Material(
                color: cs.errorContainer,
                child: InkWell(
                  // TASK-192: tap the storage banner to reach the recovery screen
                  // (retry / salvage export / reset).
                  onTap: b.isDbError
                      ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => const DbRecoveryScreen()))
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: cs.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(b.message,
                              style: TextStyle(color: cs.onErrorContainer)),
                        ),
                        if (b.isDbError)
                          Icon(Icons.chevron_right, color: cs.onErrorContainer),
                        if (b.dismissible)
                          IconButton(
                            icon: Icon(Icons.close,
                                size: 18, color: cs.onErrorContainer),
                            tooltip: 'Dismiss',
                            onPressed: () =>
                                CorruptStateNotices.dismiss(b.message),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: tab),
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(_titles[_index]),
            if (devMode) ...[
              const SizedBox(width: 8),
              const Chip(
                label: Text('DEMO'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
        actions: [
          // Convenient one-tap exit from demo mode back to the real pump.
          if (devMode)
            TextButton.icon(
              onPressed: _exitDemo,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Exit demo'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Quick log',
            onPressed: () => QuickLogSheet.show(context),
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
