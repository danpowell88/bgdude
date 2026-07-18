/// TASK-127: a single typed navigation map for the app's zero-argument screens, so
/// callers push a named [AppRoute] instead of importing every destination screen
/// directly. `settings_screen.dart` alone had 15 direct screen imports just to build
/// `MaterialPageRoute`s for its own menu — this registry is the one place that maps
/// exist, cutting that import fan-out.
///
/// Screens that take constructor arguments or return a typed result (e.g.
/// `ExplainReadingScreen`, `MealDetailScreen`) aren't covered here — those still push
/// directly, since a route needs its own typed-argument story that's a bigger design
/// decision than this pass takes on.
library;

import 'package:flutter/material.dart';

import 'advanced_screen.dart';
import 'ai_model_screen.dart';
import 'basal_recommendations_screen.dart';
import 'confirmation_inbox_screen.dart';
import 'developer_screen.dart';
import 'exercise_mode_screen.dart';
import 'glucose_meter_screen.dart';
import 'medication_mode_screen.dart';
import 'model_accuracy_screen.dart';
import 'notification_settings_screen.dart';
import 'profile_screen.dart';
import 'pump_screen.dart';
import 'reports/reports_hub_screen.dart';
import 'system_health_screen.dart';
import 'therapy_settings_screen.dart';
import 'weather_settings_screen.dart';
import 'permissions_screen.dart';

/// Every zero-argument screen reachable via [AppRoutes.push].
enum AppRoute {
  profile,
  reports,
  confirmationInbox,
  notificationSettings,
  exerciseMode,
  medicationMode,
  pump,
  glucoseMeter,
  therapySettings,
  advanced,
  basalRecommendations,
  weatherSettings,
  aiModel,
  modelAccuracy,
  developer,
  systemHealth,
  permissions,
}

/// Typed push helpers for [AppRoute] — the registry AC#1 asks for.
class AppRoutes {
  const AppRoutes._();

  static WidgetBuilder _builderFor(AppRoute route) => switch (route) {
        AppRoute.profile => (_) => const ProfileScreen(),
        AppRoute.reports => (_) => const ReportsHubScreen(),
        AppRoute.confirmationInbox => (_) => const ConfirmationInboxScreen(),
        AppRoute.notificationSettings => (_) =>
            const NotificationSettingsScreen(),
        AppRoute.exerciseMode => (_) => const ExerciseModeScreen(),
        AppRoute.medicationMode => (_) => const MedicationModeScreen(),
        AppRoute.pump => (_) => const PumpScreen(),
        AppRoute.glucoseMeter => (_) => const GlucoseMeterScreen(),
        AppRoute.therapySettings => (_) => const TherapySettingsScreen(),
        AppRoute.advanced => (_) => const AdvancedScreen(),
        AppRoute.basalRecommendations => (_) =>
            const BasalRecommendationsScreen(),
        AppRoute.weatherSettings => (_) => const WeatherSettingsScreen(),
        AppRoute.aiModel => (_) => const AiModelScreen(),
        AppRoute.modelAccuracy => (_) => const ModelAccuracyScreen(),
        AppRoute.developer => (_) => const DeveloperScreen(),
        AppRoute.systemHealth => (_) => const SystemHealthScreen(),
        AppRoute.permissions => (_) => const PermissionsScreen(),
      };

  /// Pushes [route] onto the navigator rooted at [context].
  static Future<void> push(BuildContext context, AppRoute route) =>
      Navigator.of(context)
          .push<void>(MaterialPageRoute<void>(builder: _builderFor(route)));
}
