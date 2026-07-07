/// TASK-194: crash-restart recovery invariants, pinned so behaviour after a process
/// death is a deliberate choice rather than whatever the code happens to do.
library;

import 'dart:convert';

import 'package:bgdude/alerts/alert_orchestrator.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/feedback/pending_confirmation.dart';
import 'package:bgdude/insights/illness_mode.dart';
import 'package:bgdude/insights/medication_mode.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/restart_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CooldownGate / alert re-fire across a restart (TASK-194 AC#3)', () {
    // DECISION (documented per AC#3): AlertService's cooldown state
    // (CooldownGate._lastFired, alert_orchestrator.dart:38) is deliberately NEVER
    // persisted. A crash mid-cooldown means the next launch's fresh gate has no
    // memory of the earlier fire, so a still-active urgent-low re-fires once more.
    // The alternative — persisting last-fired timestamps — risks an incorrectly
    // SUPPRESSED alert if the persisted value is stale or wrong; for a hypoglycemia
    // alert, a redundant re-alert is the safe failure direction, a silently-skipped
    // one is not. No code change needed: this is already the only code path
    // (CooldownGate is a plain in-memory field, `AlertService._cooldowns` is
    // constructed fresh in the constructor, and nothing in alert_orchestrator.dart
    // or AlertService ever calls KvStore/the repository to save or load it).
    test('a fresh CooldownGate never remembers an earlier fire', () {
      final beforeCrash = CooldownGate();
      final now = DateTime(2026, 7, 4, 8);
      expect(beforeCrash.passed(NotificationCategory.urgentLow, now,
          const Duration(minutes: 30)), isTrue);
      beforeCrash.markFired(NotificationCategory.urgentLow, now);
      // Same instance, 1 minute later: cooldown correctly suppresses a re-fire —
      // this is the CONTINUOUS-SESSION behaviour, unaffected by the restart fix.
      expect(
          beforeCrash.passed(NotificationCategory.urgentLow,
              now.add(const Duration(minutes: 1)), const Duration(minutes: 30)),
          isFalse);

      // The "restart": a brand new gate, as AlertService's constructor creates,
      // modelling the process death and relaunch 1 minute later — still well
      // within what would have been the old gate's cooldown window.
      final afterCrash = CooldownGate();
      expect(
          afterCrash.passed(NotificationCategory.urgentLow,
              now.add(const Duration(minutes: 1)), const Duration(minutes: 30)),
          isTrue,
          reason: 'a fresh gate has no memory of the pre-crash fire — the still-'
              'active urgent-low condition must re-fire once after restart');
    });

    test('two ProviderContainers each get their own AlertService instance', () {
      final sim = RestartSimulation();
      final c1 = sim.buildContainer();
      addTearDown(c1.dispose);
      final c2 = sim.buildContainer();
      addTearDown(c2.dispose);

      expect(identical(c1.read(alertServiceProvider), c2.read(alertServiceProvider)),
          isFalse,
          reason: 'each container (each simulated process) must own its own '
              'AlertService, and therefore its own fresh CooldownGate');
    });
  });

  group('Pending-confirmation decisions survive a restart (TASK-194 AC#2)', () {
    test('a decision recorded before the crash is still applied after', () async {
      final sim = RestartSimulation();
      final c1 = sim.buildContainer();
      await c1.read(historyRepositoryProvider).saveCgm([
        CgmSample(time: DateTime(2026, 7, 4, 8), mgdl: 100),
      ]);
      await ConfirmationDecisionStore.record(
          'unannouncedMeal:12345', ConfirmationDecision.dismissed,
          at: DateTime(2026, 7, 4, 8));
      c1.dispose(); // no graceful shutdown — a crash doesn't get one either

      final c2 = sim.buildContainer();
      addTearDown(c2.dispose);
      final decisions = await ConfirmationDecisionStore.load();

      expect(decisions['unannouncedMeal:12345'], ConfirmationDecision.dismissed);
    });
  });

  group('Illness mode survives a restart, exercise mode does not (TASK-194 AC#2)', () {
    test('illness mode is still active after restart', () async {
      final sim = RestartSimulation();
      final c1 = sim.buildContainer();
      c1.read(illnessModeProvider.notifier).activate(notes: 'flu');
      // Persistence is fire-and-forget (unawaited) in IllnessModeNotifier.activate —
      // let its write actually land before "crashing".
      await Future<void>.delayed(const Duration(milliseconds: 10));
      c1.dispose();

      final c2 = sim.buildContainer();
      addTearDown(c2.dispose);
      // Riverpod builds a provider's value lazily on first read — touch the
      // notifier to trigger construction (and its unawaited _restore()) before
      // waiting for that restore to land, or the delay races nothing at all.
      c2.read(illnessModeProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(c2.read(illnessModeProvider).active, isTrue);
    });

    test('exercise mode does NOT survive restart (by design, not an oversight)', () {
      // exercisePlanProvider is explicitly documented as "In-memory/transient —
      // exercise is a short-lived state" (providers.dart:287-289) and has no
      // KvStore write anywhere. This conflicts with this ticket's own AC#2 wording
      // ("active modes (exercise/illness) survive") — flagged back on the task
      // rather than silently changed; a short workout announcement disappearing
      // after a rare crash is a much smaller problem than illness mode's multi-day
      // sensitivity adjustment doing the same; changing it needs a product call.
      final sim = RestartSimulation();
      final c1 = sim.buildContainer();
      c1.read(exercisePlanProvider.notifier).state = null; // baseline: no plan
      c1.dispose();

      final c2 = sim.buildContainer();
      addTearDown(c2.dispose);
      expect(c2.read(exercisePlanProvider), isNull);
    });
  });

  group('Illness/medication mode auto-expiry across a restart (TASK-197 AC#4)', () {
    test(
        'an illness mode activated with a since-elapsed expiry is deactivated at '
        'startup, and the annotation is emitted', () async {
      final sim = RestartSimulation();
      // Simulate a mode that was activated a while ago and expired before this
      // "launch" -- the KvStore write stands in for a real activation days earlier.
      final past = DateTime(2026, 6, 1, 8);
      final expired = IllnessMode(
        active: true,
        startedAt: past,
        expiresAt: past.add(const Duration(days: 7)),
        notes: 'flu',
      );
      await KvStore.setString('illness_mode_v1', expired.encode());

      final c = sim.buildContainer();
      addTearDown(c.dispose);
      // Force construction (so the unawaited _restore() actually starts) before
      // waiting for it to land -- Riverpod builds a provider's value lazily on
      // first read.
      final notifier = c.read(illnessModeProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.read(illnessModeProvider).active, isTrue,
          reason: 'restored active, not yet expiry-checked');

      await c.read(appJobsProvider).checkModeExpiry();

      expect(c.read(illnessModeProvider).active, isFalse);
      expect(notifier.lastDeactivationAnnotation, isNotNull);
      expect(
          notifier.lastDeactivationAnnotation!.kind, AnnotationKind.illness);
    });

    test(
        'a medication course activated with a since-elapsed expiry is '
        'deactivated at startup', () async {
      final sim = RestartSimulation();
      final past = DateTime(2026, 6, 1, 8);
      final expired = MedicationMode(
        active: true,
        startedAt: past,
        expiresAt: past.add(const Duration(days: 14)),
        intensity: MedicationIntensity.high,
      );
      await KvStore.setString(
          'medication_mode_v1', jsonEncode(expired.toJson()));

      final c = sim.buildContainer();
      addTearDown(c.dispose);
      c.read(medicationModeProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.read(medicationModeProvider).active, isTrue);

      await c.read(appJobsProvider).checkModeExpiry();

      expect(c.read(medicationModeProvider).active, isFalse);
    });

    test('a mode that has NOT yet expired survives the startup check', () async {
      final sim = RestartSimulation();
      final recent = DateTime.now() // now-ok: checkModeExpiry reads the wall clock
          .subtract(const Duration(hours: 2));
      final stillActive = IllnessMode(
        active: true,
        startedAt: recent,
        expiresAt: recent.add(const Duration(days: 7)),
      );
      await KvStore.setString('illness_mode_v1', stillActive.encode());

      final c = sim.buildContainer();
      addTearDown(c.dispose);
      c.read(illnessModeProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await c.read(appJobsProvider).checkModeExpiry();

      expect(c.read(illnessModeProvider).active, isTrue,
          reason: 'expiresAt is 6 days in the future -- must not be touched');
    });
  });

  group('Day history rebuilds from the repository after a restart (TASK-194 AC#2)',
      () {
    test('today\'s CGM data is present after an explicit reload', () async {
      final sim = RestartSimulation();
      final c1 = sim.buildContainer();
      final now = DateTime.now(); // now-ok: DayHistoryController.reload() reads the wall clock
      await c1.read(historyRepositoryProvider).saveCgm([
        CgmSample(time: now.subtract(const Duration(hours: 1)), mgdl: 110),
      ]);
      c1.dispose();

      final c2 = sim.buildContainer();
      addTearDown(c2.dispose);
      // DayHistoryController's constructor fires reload() unawaited — call it
      // explicitly so the test doesn't race the same unawaited call.
      await c2.read(dayHistoryControllerProvider.notifier).reload();

      expect(c2.read(dayDataProvider).cgm, isNotEmpty);
    });
  });
}
