import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'app.dart';
import 'core/local_timezone.dart';
import 'data/database.dart';
import 'data/history_repository.dart';
import 'data/kv_store.dart';
import 'data/secure_key.dart';
import 'insights/background_summary.dart';
import 'insights/notifications.dart';
import 'state/app_flags.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  // TASK-175: without this, tz.local stays UTC and every wall-clock schedule
  // fires offset by the UTC delta (the 07:00 summary at 17:00 in AEST).
  await configureLocalTimezone();

  final flags = await AppFlags.load();
  final onboarded = flags.onboardingDone;
  final devMode = flags.devMode;

  // Open the encrypted store and build the history repository. If SQLCipher can't
  // initialise (e.g. an unsupported host), fall back to in-memory so the app still
  // runs rather than crashing on launch.
  HistoryRepository repository;
  String? dbOpenError; // P1-6: surfaced to the UI instead of a silent fallback.
  try {
    final keys = await SecureKeyStore.open();
    final db = AppDatabase(openEncryptedDatabase(keys.getOrCreatePassphrase()));
    repository = DriftHistoryRepository(db);
    KvStore.init(db); // encrypted key-value store for app state
  } catch (e, st) {
    // Don't crash on launch, but don't pretend it's fine either: run in-memory and tell
    // the user their history isn't being saved.
    debugPrint('DB open failed — running in-memory (data will NOT persist): $e\n$st');
    repository = InMemoryHistoryRepository();
    dbOpenError =
        'Storage failed to open — the app is running without saving. Your data will '
        'not persist. Restart the app; if it keeps happening, reinstall.';
  }

  final notifications = NotificationService();
  // Notification setup prompts for permission — only after onboarding has
  // walked the user through why (fresh installs go through OnboardingScreen).
  if (onboarded) {
    await notifications.init();
    await notifications.scheduleDailySummary(hour: 7);
    await notifications.scheduleWeeklyReport();
    // Background morning-summary backstop for days the app isn't opened.
    try {
      await registerBackgroundSummary();
    } catch (_) {}
  }

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        onboardingDoneProvider.overrideWith((ref) => onboarded),
        devModeProvider.overrideWith((ref) => devMode),
        persistentHistoryRepositoryProvider.overrideWithValue(repository),
        dbOpenErrorProvider.overrideWithValue(dbOpenError),
      ],
      child: const BgDudeApp(),
    ),
  );
}
