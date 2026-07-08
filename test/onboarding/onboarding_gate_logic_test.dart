import 'package:bgdude/onboarding/onboarding_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure unit tests for the extracted onboarding-advance logic.
void main() {
  const gate = OnboardingGate(pageCount: 4);

  group('pumpReady matrix', () {
    test('a live real connection is ready', () {
      expect(gate.pumpReady(realConnected: true, pumpEverPaired: false), isTrue);
    });
    test('a previously-paired pump is ready even when disconnected', () {
      expect(gate.pumpReady(realConnected: false, pumpEverPaired: true), isTrue);
    });
    test('neither → not ready', () {
      expect(gate.pumpReady(realConnected: false, pumpEverPaired: false), isFalse);
    });
  });

  group('lastStepSatisfied', () {
    test('demo choice alone satisfies it', () {
      expect(gate.lastStepSatisfied(demoChosen: true, pumpReady: false), isTrue);
    });
    test('a ready pump alone satisfies it', () {
      expect(gate.lastStepSatisfied(demoChosen: false, pumpReady: true), isTrue);
    });
    test('neither → not satisfied', () {
      expect(gate.lastStepSatisfied(demoChosen: false, pumpReady: false), isFalse);
    });
  });

  group('canAdvance per page', () {
    test('page 0 always advances', () {
      expect(
          gate.canAdvance(page: 0, acceptedPairing: false, lastStepSatisfied: false),
          isTrue);
    });
    test('page 1 (pairing warning) needs acceptance', () {
      expect(
          gate.canAdvance(page: 1, acceptedPairing: false, lastStepSatisfied: true),
          isFalse);
      expect(
          gate.canAdvance(page: 1, acceptedPairing: true, lastStepSatisfied: false),
          isTrue);
    });
    test('page 2 (profile) always advances', () {
      expect(
          gate.canAdvance(page: 2, acceptedPairing: false, lastStepSatisfied: false),
          isTrue);
    });
    test('final page needs the last step satisfied', () {
      expect(
          gate.canAdvance(page: 3, acceptedPairing: true, lastStepSatisfied: false),
          isFalse);
      expect(
          gate.canAdvance(page: 3, acceptedPairing: false, lastStepSatisfied: true),
          isTrue);
    });
  });
}
