/// Cross-language channel-name contract (TASK-111). These platform-channel names must
/// match the Kotlin `PumpChannels` object exactly — a typo on either side silently yields
/// a dead channel. Defined once here and imported by every Dart call site.
library;

class PumpChannels {
  /// EventChannel streaming snapshot + connection-state updates from the native bridge.
  static const String events = 'bgdude/pump_events';

  /// MethodChannel for the read-only command surface (status requests, history reads).
  static const String commands = 'bgdude/pump_commands';
}
