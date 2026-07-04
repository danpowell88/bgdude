import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state/providers.dart';
import 'ui/main_shell.dart';
import 'ui/onboarding_screen.dart';

class BgDudeApp extends ConsumerWidget {
  const BgDudeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mirror every pump snapshot onto the home-screen widget (and re-push when the
    // display unit changes).
    ref.listen(pumpSnapshotProvider, (_, next) {
      final snapshot = next.valueOrNull;
      if (snapshot != null) {
        ref
            .read(homeWidgetServiceProvider)
            .pushUpdate(snapshot, ref.read(glucoseUnitProvider));
        // Persist the reading and keep today's history current.
        ref
            .read(dayHistoryControllerProvider.notifier)
            .ingestSnapshot(snapshot);
        // Predicted low/high nudges + prediction logging.
        ref.read(alertServiceProvider).onSnapshot();
        // Best-effort Nightscout push (no-op unless configured + enabled).
        final sample = snapshot.toCgmSample();
        final ns = ref.read(nightscoutClientProvider);
        if (sample != null) ns.uploadEntries([sample]);
        if (snapshot.iobUnits != null) {
          ns.uploadDeviceStatus(iob: snapshot.iobUnits!);
        }
      }
    });
    ref.listen(glucoseUnitProvider, (_, unit) {
      ref.read(homeWidgetServiceProvider).setUnit(unit);
    });
    // Alert if the pump stays disconnected.
    ref.listen(pumpConnectionProvider, (_, next) {
      final c = next.valueOrNull;
      if (c != null) ref.read(connectionAlertServiceProvider).onConnection(c);
    });

    final onboarded = ref.watch(onboardingDoneProvider);

    return MaterialApp(
      title: 'bgdude',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D6DF2),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D6DF2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: onboarded
          ? const MainShell()
          : OnboardingScreen(
              onDone: () async {
                ref.read(onboardingDoneProvider.notifier).state = true;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_done', true);
              },
            ),
    );
  }
}
