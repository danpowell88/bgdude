/// Riverpod state for the glucose-meter feature: the paired meter, last-sync info, and
/// the pair / unpair / sync-now actions. BLE and storage live in the transport + service.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/kv_store.dart';
import '../logging/app_log.dart';
import 'glucose_meter_service.dart';
import 'glucose_meter_transport.dart';

class GlucoseMeterStatus {
  const GlucoseMeterStatus({
    this.paired,
    this.lastSyncAt,
    this.lastImported = 0,
    this.totalImported = 0,
    this.syncing = false,
    this.error,
  });

  final MeterDevice? paired;
  final DateTime? lastSyncAt;
  final int lastImported; // readings from the most recent sync
  final int totalImported; // cumulative
  final bool syncing;
  final String? error;

  bool get isPaired => paired != null;

  GlucoseMeterStatus copyWith({
    MeterDevice? paired,
    bool clearPaired = false,
    DateTime? lastSyncAt,
    int? lastImported,
    int? totalImported,
    bool? syncing,
    String? error,
    bool clearError = false,
  }) =>
      GlucoseMeterStatus(
        paired: clearPaired ? null : (paired ?? this.paired),
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastImported: lastImported ?? this.lastImported,
        totalImported: totalImported ?? this.totalImported,
        syncing: syncing ?? this.syncing,
        error: clearError ? null : (error ?? this.error),
      );
}

class GlucoseMeterController extends StateNotifier<GlucoseMeterStatus> {
  GlucoseMeterController({
    required GlucoseMeterService service,
    required GlucoseMeterTransport transport,
    this.demo = false,
  })  : _service = service,
        _transport = transport,
        super(const GlucoseMeterStatus()) {
    _restore();
  }

  final GlucoseMeterService _service;
  final GlucoseMeterTransport _transport;
  final bool demo;

  static const _kDevice = 'glucose_meter_device_v1';
  static const _kLastSync = 'glucose_meter_last_sync_v1';
  static const _kTotal = 'glucose_meter_total_v1';

  GlucoseMeterTransport get transport => _transport;

  Future<void> _restore() async {
    // TASK-206: this runs fire-and-forget from the constructor — an uncaught
    // decode failure here would be an unhandled async error, not even a logged
    // one, and would leave the controller permanently stuck without a paired
    // meter until the KvStore entry is manually cleared.
    try {
      final raw = await KvStore.getString(_kDevice);
      if (raw != null && raw.isNotEmpty) {
        final device =
            MeterDevice.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        final syncRaw = await KvStore.getString(_kLastSync);
        final total = (await KvStore.getDouble(_kTotal))?.toInt() ?? 0;
        if (mounted) {
          state = state.copyWith(
            paired: device,
            lastSyncAt: syncRaw == null ? null : DateTime.tryParse(syncRaw),
            totalImported: total,
          );
        }
      } else if (demo) {
        // Populate a representative paired meter so the screen isn't empty without
        // hardware.
        if (mounted) {
          state = state.copyWith(
            paired: const MeterDevice(id: 'DEMO-METER', name: 'Accu-Chek Guide Me'),
            lastSyncAt: DateTime.now().subtract(const Duration(hours: 3)),
            lastImported: 2,
            totalImported: 37,
          );
        }
      }
    } catch (e) {
      appLog.error(
          'persistence', 'corrupt glucose-meter pairing state — starting unpaired',
          error: e);
    }
  }

  Future<void> pair(MeterDevice device) async {
    await KvStore.setString(_kDevice, jsonEncode(device.toJson()));
    state = state.copyWith(paired: device, clearError: true);
    await syncNow();
  }

  Future<void> unpair() async {
    await KvStore.setString(_kDevice, '');
    await KvStore.setString(_kLastSync, '');
    await _service.reset();
    state = const GlucoseMeterStatus();
  }

  Future<void> syncNow() async {
    final device = state.paired;
    if (device == null || state.syncing) return;
    state = state.copyWith(syncing: true, clearError: true);
    try {
      final outcome = await _service.sync(device.id);
      final total = state.totalImported + outcome.imported;
      final now = DateTime.now();
      await KvStore.setString(_kLastSync, now.toIso8601String());
      await KvStore.setDouble(_kTotal, total.toDouble());
      state = state.copyWith(
        syncing: false,
        lastSyncAt: now,
        lastImported: outcome.imported,
        totalImported: total,
        // TASK-94: surface a drifted meter clock so the user knows imported times are off.
        error: outcome.clockSkew == null
            ? null
            : 'Your meter\'s clock looks ~${outcome.clockSkew!.inMinutes} min '
                'fast — imported reading times may be off. Set the meter\'s time.',
        clearError: outcome.clockSkew == null,
      );
    } catch (e) {
      state = state.copyWith(syncing: false, error: _friendly(e));
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('No Glucose Service')) {
      return 'That device isn\'t a standard glucose meter.';
    }
    if (s.toLowerCase().contains('timeout') || s.contains('timed out')) {
      return 'Couldn\'t reach the meter — wake it and try again.';
    }
    return 'Sync failed: $s';
  }
}
