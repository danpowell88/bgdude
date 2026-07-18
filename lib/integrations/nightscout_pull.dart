/// The follower pull loop (issue #75): fetch from Nightscout, merge, store.
///
/// Kept apart from [NightscoutClient] (which is transport) and from
/// `nightscout_follower.dart` (which is pure parsing and merge decisions) so the
/// orchestration — what window to ask for, what to skip, what to write — is testable
/// against fakes without a live site or a real database.
library;

import '../core/samples.dart';
import '../data/history_repository.dart';
import '../logging/app_log.dart';
import 'nightscout.dart';
import 'nightscout_follower.dart';

/// Outcome of one pull, so callers (and tests) can see what actually happened rather
/// than inferring it from side effects.
class NightscoutPullResult {
  const NightscoutPullResult({
    this.fetched = 0,
    this.ingested = 0,
    this.skipped = false,
  });

  final int fetched;

  /// How many readings were new — the rest were already held from a higher-priority
  /// source or had been ingested on an earlier poll.
  final int ingested;

  /// True when follower mode is off or unconfigured, so nothing was even attempted.
  final bool skipped;
}

/// Pulls recent CGM readings from Nightscout and stores the ones bgdude doesn't have.
class NightscoutPuller {
  NightscoutPuller({
    required this.client,
    required this.repository,
    this.window = const Duration(hours: 6),
  });

  final NightscoutClient client;
  final HistoryRepository repository;

  /// How far back each poll looks.
  ///
  /// Deliberately much wider than the poll interval: a site that was briefly
  /// unreachable, or a phone that was asleep, must be able to catch up rather than
  /// leaving a permanent hole. Re-fetching what we already have is cheap because the
  /// merge is idempotent; missing a window is not recoverable without a manual sync.
  final Duration window;

  /// The Nightscout `_id`s ingested so far, so a re-fetch of an overlapping window
  /// doesn't reconsider them. Bounded by [_maxRememberedIds] so a long-running app
  /// can't grow this without limit.
  final Set<String> _ingestedIds = <String>{};

  static const int _maxRememberedIds = 5000;

  Future<NightscoutPullResult> pull({DateTime? now}) async {
    if (!client.config.canFollow) {
      return const NightscoutPullResult(skipped: true);
    }
    final at = now ?? DateTime.now();
    final since = at.subtract(window);

    final fetched = await client.fetchEntries(since: since);
    if (fetched.isEmpty) return const NightscoutPullResult();

    // Existing readings in the same window. Anything already here came from the pump
    // or a meter — both outrank a Nightscout copy of the same reading, which is very
    // often the reading this app pushed there in the first place.
    final existing = await repository.cgm(since, at.add(const Duration(minutes: 1)));
    final existingTimes = {
      for (final s in existing)
        if (s.source != GlucoseSource.nightscout) s.time,
    };

    final toIngest = entriesToIngest(
      fetched,
      existingTimes: existingTimes,
      knownIds: _ingestedIds,
    );
    if (toIngest.isEmpty) {
      return NightscoutPullResult(fetched: fetched.length);
    }

    try {
      await repository.saveCgm([for (final e in toIngest) e.toSample()]);
    } catch (e) {
      // A failed write must not mark these ids as ingested, or the next poll would
      // skip them and the readings would be lost for good.
      appLog.error('nightscout_pull', 'saving fetched entries failed', error: e);
      return NightscoutPullResult(fetched: fetched.length);
    }

    _rememberIngested(toIngest);
    return NightscoutPullResult(
      fetched: fetched.length,
      ingested: toIngest.length,
    );
  }

  void _rememberIngested(List<NightscoutEntry> entries) {
    for (final e in entries) {
      if (e.id.isNotEmpty) _ingestedIds.add(e.id);
    }
    if (_ingestedIds.length > _maxRememberedIds) {
      // Drop the oldest-inserted half. Forgetting an id is harmless — the timestamp
      // check still catches it — so a cheap bound beats exact bookkeeping.
      final keep = _ingestedIds.skip(_ingestedIds.length ~/ 2).toList();
      _ingestedIds
        ..clear()
        ..addAll(keep);
    }
  }
}
