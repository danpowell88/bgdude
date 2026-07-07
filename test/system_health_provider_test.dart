import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/insights/system_health.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-201 AC#3: force one subsystem to fail and assert the surface reflects it,
/// while the caller's own error handling (the rethrow) is unaffected -- this is
/// meant to ADD observability, never change existing behaviour.
void main() {
  setUp(KvStore.useMemory);

  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('a throwing subsystem is recorded as a failure and still rethrows', () async {
    final notifier = container.read(systemHealthProvider.notifier);

    await expectLater(
      notifier.track(Subsystem.weather, () => throw StateError('network down')),
      throwsA(isA<StateError>()),
    );

    final health = container.read(systemHealthProvider).of(Subsystem.weather);
    expect(health.consecutiveFailures, 1);
    expect(health.lastSuccessAt, isNull);
    expect(health.lastError, contains('network down'));
    expect(health.isUnhealthy, isTrue);
    // Untouched subsystems are unaffected.
    expect(container.read(systemHealthProvider).of(Subsystem.healthSync),
        SubsystemHealth.unknown);
  });

  test('a successful call records success and resets a prior failure streak',
      () async {
    final notifier = container.read(systemHealthProvider.notifier);
    await expectLater(
      notifier.track(Subsystem.modelDownload, () => throw Exception('boom')),
      throwsException,
    );
    expect(
        container.read(systemHealthProvider).of(Subsystem.modelDownload)
            .consecutiveFailures,
        1);

    final result =
        await notifier.track(Subsystem.modelDownload, () async => 'ok');
    expect(result, 'ok');

    final health =
        container.read(systemHealthProvider).of(Subsystem.modelDownload);
    expect(health.consecutiveFailures, 0);
    expect(health.lastSuccessAt, isNotNull);
  });

  test('health persists across a rebuilt container (same KvStore backing)',
      () async {
    await container
        .read(systemHealthProvider.notifier)
        .track(Subsystem.forecasterTraining, () async => 'trained');

    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    c2.read(systemHealthProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(
        c2.read(systemHealthProvider).of(Subsystem.forecasterTraining)
            .lastSuccessAt,
        isNotNull);
  });
}
