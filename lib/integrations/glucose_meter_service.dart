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
  const MeterSyncOutcome({required this.imported, required this.lastSeq});

  /// How many *new* readings were saved this sync.
  final int imported;

  /// The high-water sequence number after this sync (null if nothing ever synced).
  final int? lastSeq;
}

class GlucoseMeterService {
  GlucoseMeterService({required this.transport, required this.repository});

  final GlucoseMeterTransport transport;
  final HistoryRepository repository;

  static const _kSeq = 'glucose_meter_last_seq_v1';

  /// Pull new records from [deviceId] and store them. Idempotent: records at/below the
  /// stored high-water sequence are ignored, so re-syncing never duplicates readings.
  Future<MeterSyncOutcome> sync(String deviceId) async {
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
    return MeterSyncOutcome(imported: fresh.length, lastSeq: newSeq);
  }

  Future<int?> lastSequence() async {
    final s = await KvStore.getString(_kSeq);
    if (s == null || s.isEmpty) return null;
    return int.tryParse(s);
  }

  /// Clear the high-water mark (on unpair) so a fresh pairing re-imports from scratch.
  Future<void> reset() => KvStore.setString(_kSeq, '');
}
