/// TASK-166: provider-graph regression tests for the P2-9 rebuild fixes. The
/// report providers must WATCH the repository (a demo toggle swaps it, and a
/// `ref.read` would freeze reports on the old store), and the confirmation
/// inbox must re-scan on a new CGM reading but NOT on an IOB-only snapshot tick.
library;

import 'dart:async';

import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts scans by counting repository reads the confirmations provider makes.
class _CountingRepository extends InMemoryHistoryRepository {
  int cgmReads = 0;

  @override
  Future<List<CgmSample>> cgm(DateTime from, DateTime to) {
    cgmReads++;
    return super.cgm(from, to);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a repository swap re-runs the report providers (guards ref.watch)',
      () async {
    // reportRange/pending-confirmations read the wall clock (TASK-39).
    final now = DateTime.now(); // now-ok: providers are wall-clock internally
    final repoA = InMemoryHistoryRepository();
    await repoA.saveCgm([
      for (var i = 0; i < 24; i++)
        CgmSample(
            time: now.subtract(Duration(minutes: 5 * (24 - i))), mgdl: 120),
    ]);
    final repoB = InMemoryHistoryRepository(); // empty

    final container = ProviderContainer(overrides: [
      historyRepositoryProvider.overrideWithValue(repoA),
    ]);
    addTearDown(container.dispose);

    final withData = await container.read(glucoseReportProvider.future);
    expect(withData.confirmed, isNotEmpty);

    // Swap the repository (what the demo toggle does) and re-read: a ref.read
    // regression would keep serving repoA's data forever.
    container.updateOverrides([
      historyRepositoryProvider.overrideWithValue(repoB),
    ]);
    final afterSwap = await container.read(glucoseReportProvider.future);
    expect(afterSwap.confirmed, isEmpty,
        reason: 'the report must rebuild against the swapped repository');
  });

  test(
      'a new CGM timestamp re-scans pending confirmations; an IOB-only tick '
      'does not', () async {
    final repo = _CountingRepository();
    final snapshots = StreamController<PumpSnapshot>.broadcast();
    final container = ProviderContainer(overrides: [
      historyRepositoryProvider.overrideWithValue(repo),
      pumpSnapshotProvider.overrideWith((ref) => snapshots.stream),
    ]);
    addTearDown(container.dispose);
    addTearDown(snapshots.close);

    // Keep the provider alive like the UI does.
    final sub = container.listen(pendingConfirmationsProvider, (_, __) {});
    addTearDown(sub.close);
    await container.read(pendingConfirmationsProvider.future);
    final baseline = repo.cgmReads;
    expect(baseline, greaterThan(0));

    final t0 = DateTime.now(); // now-ok: scan window is wall-clock relative
    snapshots.add(PumpSnapshot(time: t0, cgmMgdl: 120, cgmTime: t0, iobUnits: 1.0));
    await Future<void>.delayed(Duration.zero);
    await container.read(pendingConfirmationsProvider.future);
    final afterCgm = repo.cgmReads;
    expect(afterCgm, greaterThan(baseline),
        reason: 'a new CGM reading must trigger a re-scan');

    // Same cgmTime, different IOB — the select() must gate the rebuild.
    snapshots.add(PumpSnapshot(time: t0.add(const Duration(seconds: 30)), cgmMgdl: 120, cgmTime: t0, iobUnits: 2.5));
    await Future<void>.delayed(Duration.zero);
    await container.read(pendingConfirmationsProvider.future);
    expect(repo.cgmReads, afterCgm,
        reason: 'an IOB-only snapshot tick must NOT re-scan');
  });
}
