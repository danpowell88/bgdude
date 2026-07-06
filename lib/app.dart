import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics/therapy_settings.dart';
import 'state/app_flags.dart';
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
        // Persist the reading and keep today's history current, THEN run the alert
        // service so it evaluates against the just-arrived reading (not the previous
        // one). Ordered via the future rather than fire-and-forget.
        ref
            .read(dayHistoryControllerProvider.notifier)
            .ingestSnapshot(snapshot)
            .then((_) => ref.read(alertServiceProvider).onSnapshot());
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
      // TASK-24: keep the Garmin watch on the user's chosen unit.
      ref.read(pumpClientProvider).setGarminUnit(unit);
    });
    // Alert if the pump stays disconnected.
    ref.listen(pumpConnectionProvider, (_, next) async {
      final c = next.valueOrNull;
      if (c != null) ref.read(connectionAlertServiceProvider).onConnection(c);
      // Remember that a pump has been paired at least once, so onboarding's pair path is
      // pre-satisfied for a returning user.
      if (c != null && c.isConnected) {
        await (await AppFlags.load()).setPumpPaired(true);
      }
    });
    // Apply notification-preference changes to the live channels.
    ref.listen(notificationPrefsProvider, (_, prefs) {
      ref.read(notificationServiceProvider).applyPrefs(prefs);
    });
    // Import the pump's therapy profile (IDP) when it's read from the pump.
    ref.listen(pumpTherapyProfileProvider, (_, next) {
      final json = next.valueOrNull;
      if (json != null) {
        try {
          final settings =
              TherapySettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
          if (settings.segments.isNotEmpty) {
            ref.read(therapySettingsProvider.notifier).save(settings);
          }
        } catch (_) {}
      }
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
                await (await AppFlags.load()).setOnboardingDone(true);
              },
            ),
    );
  }
}
