/// Pure first-run gating logic, extracted from OnboardingScreen.build() (TASK-106).
///
/// Onboarding is a [pageCount]-page flow. Two pages gate progress: the pairing-warning
/// page (page index 1) needs the warning accepted, and the final "Get connected" page
/// (last index) needs the user to have either paired a pump or explicitly chosen demo
/// mode. Every other page can always advance. Keeping this as a pure function makes the
/// correctness path — which previously had zero tests — unit-testable.
library;

class OnboardingGate {
  const OnboardingGate({this.pageCount = 4});

  /// Total number of onboarding pages.
  final int pageCount;

  /// A real pump is ready if it's connected right now, or was paired on a prior run.
  /// Demo mode never counts here (the simulator reports "connected" the instant it's
  /// chosen, which must not be mistaken for a real pump).
  bool pumpReady({required bool realConnected, required bool pumpEverPaired}) =>
      realConnected || pumpEverPaired;

  /// The final step is satisfied by an explicit demo choice or a ready pump.
  bool lastStepSatisfied({required bool demoChosen, required bool pumpReady}) =>
      demoChosen || pumpReady;

  /// Whether the user can advance from [page].
  bool canAdvance({
    required int page,
    required bool acceptedPairing,
    required bool lastStepSatisfied,
  }) {
    if (page == 1) return acceptedPairing;
    if (page == pageCount - 1) return lastStepSatisfied;
    return true;
  }
}
