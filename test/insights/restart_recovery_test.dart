/// Crash-restart recovery invariants, pinned so behaviour after a process
/// death is a deliberate choice rather than whatever the code happens to do.
library;

import 'dart:convert';

import 'package:bgdude/alerts/alert_orchestrator.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/health_sync.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/feedback/pending_confirmation.dart';
import 'package:bgdude/insights/exercise_mode.dart';
import 'package:bgdude/insights/illness_mode.dart';
import 'package:bgdude/insights/medication_mode.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/insights/workout_classifier.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/faults.dart';
import '../support/restart_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CooldownGate / alert re-fire across a restart', () {
    // DECISION: AlertService's cooldown state
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

  group('Pending-confirmation decisions survive a restart', () {
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

  group('Illness and exercise mode both survive a restart', () {
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

    test(
        'an in-window exercise plan survives a restart (previously '
        'documented as deliberately NOT persisted; that was wrong: losing the '
        'raised low-alert threshold mid-workout makes alerts fire LATER exactly '
        'during the highest hypo-risk window, not a safe default)', () async {
      final sim = RestartSimulation();
      final c1 = sim.buildContainer();
      // ExercisePlanNotifier.load()/affectsAt() compare against the wall clock
      // (no injected clock yet), so this anchors to real "now".
      final now = DateTime.now(); // now-ok: see comment above
      final plan = ExercisePlan(
          startAt: now, durationMinutes: 45, type: WorkoutType.aerobic);
      await c1.read(exercisePlanProvider.notifier).set(plan);
      c1.dispose();

      final c2 = sim.buildContainer();
      addTearDown(c2.dispose);
      c2.read(exercisePlanProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final restored = c2.read(exercisePlanProvider);
      expect(restored, isNotNull);
      expect(restored!.affectsAt(now), isTrue);
    });

    test('a plan whose effect window already passed is not restored', () async {
      final sim = RestartSimulation();
      final c1 = sim.buildContainer();
      final longPast = DateTime(2020, 1, 1);
      final expired = ExercisePlan(
          startAt: longPast, durationMinutes: 30, type: WorkoutType.resistance);
      await c1.read(exercisePlanProvider.notifier).set(expired);
      c1.dispose();

      final c2 = sim.buildContainer();
      addTearDown(c2.dispose);
      c2.read(exercisePlanProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(c2.read(exercisePlanProvider), isNull);
    });

    test(
        'AppJobs.checkModeExpiry clears a plan whose window passed WITHOUT a '
        'restart', () async {
      final sim = RestartSimulation();
      final c = sim.buildContainer();
      addTearDown(c.dispose);
      final longPast = DateTime(2020, 1, 1);
      final expired = ExercisePlan(
          startAt: longPast, durationMinutes: 30, type: WorkoutType.resistance);
      await c.read(exercisePlanProvider.notifier).set(expired);
      expect(c.read(exercisePlanProvider), isNotNull);

      await c.read(appJobsProvider).checkModeExpiry();

      expect(c.read(exercisePlanProvider), isNull);
    });
  });

  group('Illness/medication mode auto-expiry across a restart', () {
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
      c.read(illnessModeProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.read(illnessModeProvider).active, isTrue,
          reason: 'restored active, not yet expiry-checked');

      await c.read(appJobsProvider).checkModeExpiry();
      // Let the unawaited _persist() -> saveAnnotation() chain land.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(c.read(illnessModeProvider).active, isFalse);
      // The annotation must actually reach the history repository (what
      // the retraining pipeline reads), not just sit in the notifier's own
      // transient field -- lastDeactivationAnnotation is cleared once consumed, so
      // checking it here would only prove it was built, not that it was saved.
      final saved = await sim.repo.annotations(
          DateTime(2020), DateTime(2030));
      expect(saved, isNotEmpty,
          reason: 'the deactivation annotation must be saved to the history '
              'repository, not dropped after being built');
      expect(saved.single.kind, AnnotationKind.illness);
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

  group('Day history rebuilds from the repository after a restart', () {
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

  // TASK-256: every scenario above awaits its write (or a settle delay) before
  // crashing, so none of them ever hit the app mid-write -- the torn/partial-state
  // path a crash-restart ticket implies was never actually exercised. These
  // interrupt an in-flight multi-step write on purpose and assert what survives is
  // consistent (never a half-applied or duplicated state), not just "some data".
  group('Mid-write crash interruption leaves consistent state, not torn state', () {
    test(
        'a crash mid-DB-write while saving the illness-deactivation annotation '
        'leaves the mode change durable but the annotation cleanly absent -- '
        'never a half-saved one', () async {
      final delegate = InMemoryHistoryRepository();
      final faulty = FaultInjectingHistoryRepository(delegate);
      final sim = RestartSimulation(repo: faulty);
      final c1 = sim.buildContainer();
      c1.read(illnessModeProvider.notifier).activate(notes: 'flu');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // The process dies WHILE the deactivation annotation write is in flight --
      // it never reaches durable storage. IllnessModeNotifier._persist saves the
      // KvStore mode change FIRST, then attempts the annotation save separately
      // (TASK-258), so this models the write that was genuinely in-flight at the
      // moment of the crash, not the whole operation.
      faulty.throwOnce('saveAnnotation');
      c1.read(illnessModeProvider.notifier).deactivate();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      c1.dispose(); // no graceful shutdown -- a real crash doesn't get one either

      // Restart over the SAME delegate -- throwOnce already self-cleared, so this
      // models "the fault is gone" (a fresh process wouldn't inherit an in-flight
      // failure), leaving only whatever was durably written before the crash.
      final c2 = sim.buildContainer();
      addTearDown(c2.dispose);
      c2.read(illnessModeProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(c2.read(illnessModeProvider).active, isFalse,
          reason: 'the KvStore mode write is a separate, already-durable step -- '
              'it must survive even though the LATER annotation write crashed');
      final saved = await delegate.annotations(DateTime(2020), DateTime(2030));
      expect(saved, isEmpty,
          reason: 'the annotation write never completed -- it must be cleanly '
              'ABSENT after restart, never a torn/partial entry');
    });

    test(
        'a crash right as the exercise-hypo-risk notification fires leaves the '
        'dedup flag unset, so the next check re-evaluates rather than silently '
        'skipping a real warning forever', () async {
      final sim = RestartSimulation();
      // ThrowingNotificationService models the crash: the notification call
      // itself is where the process dies (throws), so checkExerciseHypoRisk's
      // `if (fired) await KvStore.setBool(key, true)` -- the step that would
      // record "already warned today" -- never runs. This is the same bias as
      // the alert loop's own TASK-38 pattern (mark-fired only AFTER a successful
      // send): a crash here must land on the side of re-checking, never on the
      // side of a warning silently never firing again.
      final c1 = sim.buildContainer(extraOverrides: [
        notificationServiceProvider.overrideWithValue(ThrowingNotificationService()),
      ]);
      final now = DateTime.now(); // now-ok: checkExerciseHypoRisk reads the wall clock
      final samples = [
        HealthSample(
          time: now,
          type: HealthMetric.exercise,
          value: 45,
          meta: const {'activity': 'RUNNING', 'source': 'test'},
        ),
      ];

      await expectLater(
        c1.read(appJobsProvider).checkExerciseHypoRisk(samples),
        throwsA(isA<StateError>()),
      );
      c1.dispose(); // no graceful shutdown -- a real crash doesn't get one either

      final key = 'exercise_hypo_warned_${now.year}-${now.month}-${now.day}';
      expect(await KvStore.getBool(key), isNot(true),
          reason: 'the dedup flag must be unset after a crash mid-flow -- if it '
              'were set here, a genuine daily hypo-risk warning would be silently '
              'skipped forever, the exact torn-state this scenario guards against');
    });
  });
}
