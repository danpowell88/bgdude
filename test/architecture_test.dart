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
}
