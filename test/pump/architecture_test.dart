/// TASK-41: turns two structural promises into build-breaking checks instead of relying
/// on discipline alone — `lib/ui/**` may only use plain data types, never reach directly
/// into services/storage, and native code never imports a pump write/control request.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Interfaces, concrete services, and storage that `lib/ui/**` must never import
/// directly — screens should go through `lib/state/providers.dart` (a plain-value
/// provider or a thin controller) instead, so pump/storage internals stay swappable
/// and screens stay testable without a live pump or database.
const _forbiddenUiImports = {
  'package:bgdude/pump/pump_source.dart',
  'package:bgdude/pump/pump_client.dart',
  'package:bgdude/pump/simulated_pump_client.dart',
  'package:bgdude/data/kv_store.dart',
  'package:bgdude/data/database.dart',
  'package:bgdude/data/history_repository.dart',
  'package:bgdude/insights/notifications.dart',
};

final _importPattern = RegExp(r'''^import\s+['"]([^'"]+)['"]''', multiLine: true);

List<String> _uiLayerViolations() {
  final uiDir = Directory('lib/ui');
  final violations = <String>[];
  for (final entity in uiDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final content = entity.readAsStringSync();
    for (final match in _importPattern.allMatches(content)) {
      final target = match.group(1)!;
      if (_forbiddenUiImports.contains(target)) {
        violations.add('${p.normalize(entity.path)} imports $target');
      }
    }
  }
  return violations;
}

List<String> _controlImportViolations() {
  final kotlinDir = Directory('android/app/src/main/kotlin');
  final violations = <String>[];
  if (!kotlinDir.existsSync()) return violations;
  final controlImport =
      RegExp(r'^import\s+com\.jwoglom\.pumpx2\.pump\.messages\.request\.control\.',
          multiLine: true);
  for (final entity in kotlinDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.kt')) continue;
    if (controlImport.hasMatch(entity.readAsStringSync())) {
      violations.add(p.normalize(entity.path));
    }
  }
  return violations;
}

/// Every concrete request class in pumpx2-messages' `request.control` package —
/// verified against the cached jar (`unzip -l pumpx2-messages-1.9.0.jar`, 2026-07-08):
/// this package holds ONLY pump write/command requests (bolus, factory reset, IDP
/// edits, temp rates, cartridge/tubing modes, etc.), never a read. TASK-243: the
/// import-line guard above misses a write invoked by fully-qualified name (no import
/// line exists to match, e.g. `sendCommand(p,
/// com.jwoglom.pumpx2.pump.messages.request.control.InitiateBolusRequest())`) — since
/// there is no legitimate reason for this read-only app to ever construct one of
/// these types, flagging the bare class name's construction anywhere in a Kotlin
/// file (imported, star-imported, or fully-qualified) closes that gap and also
/// covers a `sendCommand(...)` call carrying one, since that call is the only way
/// any of these are ever constructed.
const _controlRequestClassNames = {
  'ActivateShelfModeRequest',
  'AdditionalBolusRequest',
  'BolusPermissionReleaseRequest',
  'BolusPermissionRequest',
  'CancelBolusRequest',
  'CgmHighLowAlertRequest',
  'CgmOutOfRangeAlertRequest',
  'CgmRiseFallAlertRequest',
  'ChangeControlIQSettingsRequest',
  'ChangeTimeDateRequest',
  'CreateIDPRequest',
  'DeleteIDPRequest',
  'DisconnectPumpRequest',
  'DismissNotificationRequest',
  'EnterChangeCartridgeModeRequest',
  'EnterFillTubingModeRequest',
  'ExitChangeCartridgeModeRequest',
  'ExitFillTubingModeRequest',
  'FactoryResetBRequest',
  'FactoryResetRequest',
  'FillCannulaRequest',
  'InitiateBolusRequest',
  'PlaySoundRequest',
  'PrimeTubingSuspendRequest',
  'RemoteBgEntryRequest',
  'RemoteCarbEntryRequest',
  'RenameIDPRequest',
  'ResumePumpingRequest',
  'SendTipsControlGenericTestRequest',
  'SetActiveIDPRequest',
  'SetAutoOffAlertRequest',
  'SetBgReminderRequest',
  'SetDexcomG7PairingCodeRequest',
  'SetG6TransmitterIdRequest',
  'SetIDPSegmentRequest',
  'SetIDPSettingsRequest',
  'SetLowInsulinAlertRequest',
  'SetMaxBasalLimitRequest',
  'SetMaxBolusLimitRequest',
  'SetMissedMealBolusReminderRequest',
  'SetModesRequest',
  'SetPumpAlertSnoozeRequest',
  'SetPumpSoundsRequest',
  'SetQuickBolusSettingsRequest',
  'SetSensorTypeRequest',
  'SetSiteChangeReminderRequest',
  'SetSleepScheduleRequest',
  'SetTempRateRequest',
  'StartDexcomG6SensorSessionRequest',
  'StopDexcomCGMSensorSessionRequest',
  'StopTempRateRequest',
  'StreamDataPreflightRequest',
  'SuspendPumpingRequest',
  'UserInteractionRequest',
};

/// Finds control-request class names constructed anywhere in [content] — a
/// `\b<name>(` match, so an import line, a star-import plus bare construction, or a
/// fully-qualified inline construction are all caught the same way.
List<String> _controlConstructionsIn(String content) => [
      for (final name in _controlRequestClassNames)
        if (RegExp('\\b$name\\s*\\(').hasMatch(content)) name
    ];

List<String> _controlConstructionViolations() {
  final kotlinDir = Directory('android/app/src/main/kotlin');
  final violations = <String>[];
  if (!kotlinDir.existsSync()) return violations;
  for (final entity in kotlinDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.kt')) continue;
    for (final name in _controlConstructionsIn(entity.readAsStringSync())) {
      violations.add('${p.normalize(entity.path)} constructs $name (control/write request)');
    }
  }
  return violations;
}

void main() {
  test('lib/ui/** never imports pump/storage interfaces or services directly', () {
    final violations = _uiLayerViolations();
    expect(violations, isEmpty,
        reason: 'Screens must route through lib/state/providers.dart, not reach into '
            'services/storage directly:\n${violations.join('\n')}');
  });

  test('sanity: the guard actually flags a bad import', () {
    const fakeSource = "import 'package:bgdude/pump/pump_source.dart';\n";
    final matches = _importPattern
        .allMatches(fakeSource)
        .map((m) => m.group(1))
        .where(_forbiddenUiImports.contains);
    expect(matches, isNotEmpty);
  });

  test('no Kotlin source imports a pump write/control request (read-only promise)', () {
    final violations = _controlImportViolations();
    expect(violations, isEmpty,
        reason: 'The native layer must never send a pump write/control command:\n'
            '${violations.join('\n')}');
  });

  test('sanity: the guard actually flags a control-request import', () {
    const fakeSource =
        'import com.jwoglom.pumpx2.pump.messages.request.control.CancelBolusRequest\n';
    final matches = RegExp(
            r'^import\s+com\.jwoglom\.pumpx2\.pump\.messages\.request\.control\.',
            multiLine: true)
        .hasMatch(fakeSource);
    expect(matches, isTrue);
  });

  test('no Kotlin source constructs a pump write/control request, imported, '
      'star-imported, or fully-qualified (TASK-243)', () {
    final violations = _controlConstructionViolations();
    expect(violations, isEmpty,
        reason: 'The native layer must never send a pump write/control command:\n'
            '${violations.join('\n')}');
  });

  test(
      'sanity: the guard flags a real simulated write call with NO import line '
      '(TASK-243, AC#3)', () {
    // Exactly the gap TASK-243 closes: a fully-qualified construction inside a
    // sendCommand(...) call, with no `import ...control...` line for the old guard
    // to match.
    const fakeSource = '''
      fun evil(p: BluetoothPeripheral) {
          sendCommand(p, com.jwoglom.pumpx2.pump.messages.request.control.InitiateBolusRequest())
      }
    ''';
    // The old import-only guard would have missed this entirely.
    expect(
        RegExp(r'^import\s+com\.jwoglom\.pumpx2\.pump\.messages\.request\.control\.',
                multiLine: true)
            .hasMatch(fakeSource),
        isFalse,
        reason: 'this fixture must have no import line — that\'s the gap being tested');
    // The new guard still catches it.
    expect(_controlConstructionsIn(fakeSource), contains('InitiateBolusRequest'));
  });

  test('sanity: the guard flags a plain sendCommand write reached via a star '
      'import (TASK-243, AC#2)', () {
    const fakeSource = '''
      import com.jwoglom.pumpx2.pump.messages.request.control.*

      fun evil(p: BluetoothPeripheral) {
          sendCommand(p, CancelBolusRequest())
      }
    ''';
    expect(_controlConstructionsIn(fakeSource), contains('CancelBolusRequest'));
  });

  test('sanity: an unrelated read request name never false-positives', () {
    const fakeSource = 'sendCommand(p, InsulinStatusRequest())\n';
    expect(_controlConstructionsIn(fakeSource), isEmpty);
  });
}
