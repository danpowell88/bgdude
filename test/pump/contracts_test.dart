import 'dart:convert';
import 'dart:io';

import 'package:bgdude/core/samples.dart';
import 'package:bgdude/pump/channels.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/widget/widget_keys.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cross-language contract tests. These pin the Dart side of the boundaries;
/// the Kotlin side has mirror tests (SnapshotContractTest, WidgetContractTest).
void main() {
  group('§ snapshot JSON contract', () {
    test('Dart parser accepts the golden MutableSnapshot.toJson() fixture', () {
      final golden = File('test/contracts/mutable_snapshot_golden.json')
          .readAsStringSync();
      final snap = PumpSnapshot.fromJson(
          jsonDecode(golden) as Map<String, dynamic>);

      expect(snap.schemaVersion, PumpSnapshot.expectedSchemaVersion);
      expect(snap.time.millisecondsSinceEpoch, 1751800000000);
      expect(snap.batteryPercent, 75);
      expect(snap.isCharging, false);
      expect(snap.reservoirUnits, 120.5);
      expect(snap.iobUnits, 1.5);
      expect(snap.basalUnitsPerHour, 0.8);
      expect(snap.maxBolusUnits, 15.0);
      expect(snap.maxBasalUnitsPerHour, 3.0);
      expect(snap.controlIqActive, true);
      expect(snap.closedLoopEnabled, true);
      expect(snap.controlIqMode, ControlIqMode.sleep);
      expect(snap.cgmMgdl, 120);
      expect(snap.cgmTrend, GlucoseTrend.flat);
      expect(snap.cgmTime!.millisecondsSinceEpoch, 1751799900000);
      expect(snap.lastBolusUnits, 5.5);
      expect(snap.lastBolusTime!.millisecondsSinceEpoch, 1751799000000);
      expect(snap.apiVersion, '2.1');
      expect(snap.firmwareVersion, '7.4');
      expect(snap.activeAlerts, ['LOW_INSULIN']);
      expect(snap.activeAlarms, ['OCCLUSION']);
    });
  });

  group('§ channel + widget-key contracts', () {
    test('channel names match the Kotlin PumpChannels literals', () {
      // The Kotlin PumpChannels object must carry the identical strings (asserted on the
      // Kotlin side too). This pins the Dart literals so a rename here fails a test.
      expect(PumpChannels.events, 'bgdude/pump_events');
      expect(PumpChannels.commands, 'bgdude/pump_commands');
    });

    test('widget prefs key set matches the checked-in contract', () {
      // The same set is asserted equal on the Kotlin side (WidgetKeys.ALL).
      expect(WidgetKeys.all, {
        'bg_text',
        'bg_trend',
        'bg_unit',
        'iob_text',
        'bg_range',
        'cgm_epoch_ms',
      });
    });
  });
}
