import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'app.dart';
import 'data/database.dart';
import 'data/history_repository.dart';
import 'data/kv_store.dart';
import 'data/secure_key.dart';
import 'insights/background_summary.dart';
import 'insights/notifications.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  final prefs = await SharedPreferences.getInstance();
  final onboarded = prefs.getBool('onboarding_done') ?? false;
  final devMode = prefs.getBool('dev_mode') ?? false;

  // Open the encrypted store and build the history repository. If SQLCipher can't
  // initialise (e.g. an unsupported host), fall back to in-memory so the app still
  // runs rather than crashing on launch.
  HistoryRepository repository;
  try {
    final keys = await SecureKeyStore.open();
    final db = AppDatabase(openEncryptedDatabase(keys.getOrCreatePassphrase()));
    repository = DriftHistoryRepository(db);
    KvStore.init(db); // encrypted key-value store for app state
  } catch (_) {
    repository = InMemoryHistoryRepository();
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
        historyRepositoryProvider.overrideWithValue(repository),
      ],
      child: const BgDudeApp(),
    ),
  );
}
