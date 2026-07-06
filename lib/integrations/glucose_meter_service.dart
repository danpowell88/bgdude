/// Imports fingersticks from a paired Bluetooth glucose meter into history.
///
/// Orchestration only (BLE lives behind [GlucoseMeterTransport]): fetch stored records
/// newer than the last-seen sequence number, dedupe, save them as calibration-type
/// [CgmSample]s, and advance the high-water mark so the next sync is incremental.
library;

import '../core/samples.dart';
import '../data/history_repository.dart';
import '../data/kv_store.dart';
import 'glucose_meter.dart';
import 'glucose_meter_transport.dart';

class MeterSyncOutcome {
  const MeterSyncOutcome({
    required this.imported,
    required this.lastSeq,
    this.clockSkew,
  });

  /// How many *new* readings were saved this sync.
  final int imported;

  /// The high-water sequence number after this sync (null if nothing ever synced).
  final int? lastSeq;

  /// Detected meter clock drift (TASK-94 AC#4): how far the newest reading is stamped into
  /// the future relative to the phone. Null when within tolerance. A finger-prick can't be
  /// from the future, so this reliably flags a meter whose clock runs ahead — its imported
  /// times will be off by roughly this much.
  final Duration? clockSkew;
}

class GlucoseMeterService {
  GlucoseMeterService({required this.transport, required this.repository});

  final GlucoseMeterTransport transport;
  final HistoryRepository repository;

  static const _kSeq = 'glucose_meter_last_seq_v1';

  /// A reading stamped more than this far into the future flags meter clock drift.
  static const clockSkewTolerance = Duration(minutes: 15);

  /// Pull new records from [deviceId] and store them. Idempotent: records at/below the
  /// stored high-water sequence are ignored, so re-syncing never duplicates readings.
  /// [now] is injectable for tests.
  Future<MeterSyncOutcome> sync(String deviceId, {DateTime Function()? now}) async {
    final clock = now ?? DateTime.now;
    final lastSeq = await lastSequence();
    final records = await transport.fetchRecords(deviceId, sinceSeq: lastSeq);

    // Defend against meters that ignore the "since" filter and report everything.
    final fresh = <GlucoseMeterReading>[
      for (final r in records)
        if (lastSeq == null || r.sequenceNumber > lastSeq) r,
    ];
    if (fresh.isEmpty) return MeterSyncOutcome(imported: 0, lastSeq: lastSeq);

    final samples = <CgmSample>[for (final r in fresh) r.toCgmSample()];
    await repository.saveCgm(samples);

    final maxSeq =
        fresh.map((r) => r.sequenceNumber).reduce((a, b) => a > b ? a : b);
    final newSeq = (lastSeq == null || maxSeq > lastSeq) ? maxSeq : lastSeq;
    await KvStore.setString(_kSeq, newSeq.toString());

    // Clock-skew check on the newest reading (the one most likely to be "now"-ish).
    final newest =
        fresh.map((r) => r.time).reduce((a, b) => a.isAfter(b) ? a : b);
    final ahead = newest.difference(clock());
    final clockSkew = ahead > clockSkewTolerance ? ahead : null;

    return MeterSyncOutcome(
        imported: fresh.length, lastSeq: newSeq, clockSkew: clockSkew);
  }

  Future<int?> lastSequence() async {
    final s = await KvStore.getString(_kSeq);
    if (s == null || s.isEmpty) return null;
    return int.tryParse(s);
  }

  /// Clear the high-water mark (on unpair) so a fresh pairing re-imports from scratch.
  Future<void> reset() => KvStore.setString(_kSeq, '');
}
