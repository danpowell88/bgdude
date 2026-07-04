import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'app.dart';
import 'insights/notifications.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  final prefs = await SharedPreferences.getInstance();
  final onboarded = prefs.getBool('onboarding_done') ?? false;
  final devMode = prefs.getBool('dev_mode') ?? false;

  final notifications = NotificationService();
  // Notification setup prompts for permission — only after onboarding has
  // walked the user through why (fresh installs go through OnboardingScreen).
  if (onboarded) {
    await notifications.init();
    await notifications.scheduleDailySummary(hour: 7);
  }

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        onboardingDoneProvider.overrideWith((ref) => onboarded),
        devModeProvider.overrideWith((ref) => devMode),
      ],
      child: const BgDudeApp(),
    ),
  );
}
