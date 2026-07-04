/// Riverpod providers that wire the layers together and expose app state to the UI.
/// Kept hand-written (not codegen) so the wiring is readable at a glance.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/bolus_advisor.dart';
import '../analytics/predictor.dart';
import '../analytics/therapy_settings.dart';
import '../core/units.dart';
import '../insights/notifications.dart';
import '../ml/forecaster.dart';
import '../ml/sensitivity_model.dart';
import '../pump/pump_client.dart';
import '../pump/pump_snapshot.dart';

/// Notification service (overridden in main() with the initialised instance).
final notificationServiceProvider =
    Provider<NotificationService>((ref) => throw UnimplementedError());

/// Display unit (mmol/L default for the AU user).
final glucoseUnitProvider = StateProvider<GlucoseUnit>((ref) => GlucoseUnit.mmol);

/// Whether advanced mode (model internals, prediction decomposition) is enabled.
final advancedModeProvider = StateProvider<bool>((ref) => false);

/// The native pump client (singleton for the app lifetime).
final pumpClientProvider = Provider<PumpClient>((ref) {
  final client = PumpClient()..start();
  ref.onDispose(client.dispose);
  return client;
});

/// Live connection state.
final pumpConnectionProvider = StreamProvider<PumpConnection>((ref) {
  final client = ref.watch(pumpClientProvider);
  return client.connection;
});

/// Live pump status snapshots (CGM, IOB, battery, …).
final pumpSnapshotProvider = StreamProvider<PumpSnapshot>((ref) {
  final client = ref.watch(pumpClientProvider);
  return client.snapshots;
});

/// The user's therapy settings (imported from the pump IDP during onboarding).
final therapySettingsProvider =
    StateProvider<TherapySettings>((ref) => TherapySettings.placeholder());

/// Today's sensitivity context (from the sensitivity model; neutral until trained).
final sensitivityContextProvider =
    StateProvider<SensitivityContext>((ref) => SensitivityContext.neutral);

/// Shared engines.
final predictorProvider = Provider<GlucosePredictor>((ref) => GlucosePredictor());
final forecasterProvider = Provider<Forecaster>((ref) => Forecaster());
final bolusAdvisorProvider = Provider<BolusAdvisor>(
    (ref) => BolusAdvisor(predictor: ref.watch(predictorProvider)));
