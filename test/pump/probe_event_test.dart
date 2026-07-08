import 'package:bgdude/pump/probe_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// ProbeEvent/ProbeCatalog's model + dedup logic was entirely uncovered
/// (only exercised end-to-end via the native bridge in production).
void main() {
  group('ProbeEvent.fromMap', () {
    test('parses every field from a full map', () {
      final e = ProbeEvent.fromMap({
        'direction': 'rx',
        'name': 'CurrentEGVGuiDataResponse',
        'ts': 1751800000000,
        'opcode': 42,
        'characteristic': 'CURRENT_STATUS',
        'cargoHex': 'AA BB CC',
        'json': '{"mgdl":120}',
        'verbose': 'raw dump',
      });

      expect(e.direction, 'rx');
      expect(e.name, 'CurrentEGVGuiDataResponse');
      expect(e.timestampMs, 1751800000000);
      expect(e.opcode, 42);
      expect(e.characteristic, 'CURRENT_STATUS');
      expect(e.cargoHex, 'AA BB CC');
      expect(e.json, '{"mgdl":120}');
      expect(e.verbose, 'raw dump');
    });

    test('missing direction/name/ts fall back to sane defaults', () {
      final before = DateTime.now().millisecondsSinceEpoch; // now-ok: bounds fromMap's own wall-clock fallback
      final e = ProbeEvent.fromMap(const {});
      final after = DateTime.now().millisecondsSinceEpoch; // now-ok: bounds fromMap's own wall-clock fallback

      expect(e.direction, 'rx');
      expect(e.name, 'Unknown');
      expect(e.timestampMs, inInclusiveRange(before, after));
      expect(e.opcode, isNull);
      expect(e.characteristic, isNull);
      expect(e.cargoHex, isNull);
      expect(e.json, isNull);
    });
  });

  group('ProbeEvent.isTx / time', () {
    test('isTx is true only for direction "tx"', () {
      expect(ProbeEvent.fromMap(const {'direction': 'tx'}).isTx, isTrue);
      expect(ProbeEvent.fromMap(const {'direction': 'rx'}).isTx, isFalse);
      expect(ProbeEvent.fromMap(const {'direction': 'weird'}).isTx, isFalse);
    });

    test('time is derived from the epoch-ms timestamp', () {
      const ms = 1751800000000;
      final e = ProbeEvent.fromMap(const {'ts': ms});
      expect(e.time, DateTime.fromMillisecondsSinceEpoch(ms));
    });
  });

  group('ProbeEvent.cargoBytes', () {
    test('counts whitespace-separated hex byte groups', () {
      const e = ProbeEvent(
          direction: 'rx', name: 'x', timestampMs: 0, cargoHex: 'AA BB CC DD');
      expect(e.cargoBytes, 4);
    });

    test('tolerates multiple/irregular whitespace between bytes', () {
      const e = ProbeEvent(
          direction: 'rx', name: 'x', timestampMs: 0, cargoHex: 'AA   BB  CC');
      expect(e.cargoBytes, 3);
    });

    test('null or empty cargo is zero bytes, not an error', () {
      expect(
          const ProbeEvent(direction: 'rx', name: 'x', timestampMs: 0).cargoBytes,
          0);
      expect(
          const ProbeEvent(direction: 'rx', name: 'x', timestampMs: 0, cargoHex: '')
              .cargoBytes,
          0);
      expect(
          const ProbeEvent(
                  direction: 'rx', name: 'x', timestampMs: 0, cargoHex: '   ')
              .cargoBytes,
          0);
    });
  });

  group('ProbeEvent.toReport', () {
    test('a tx request reports the direction arrow and every field', () {
      final e = ProbeEvent.fromMap({
        'direction': 'tx',
        'name': 'AlertStatusRequest',
        'ts': 1751800000000,
        'opcode': 7,
        'characteristic': 'CURRENT_STATUS',
        'cargoHex': 'AA BB',
        'json': '{"alerts":[]}',
      });

      final report = e.toReport();

      expect(report, contains('→ REQUEST  AlertStatusRequest'));
      expect(report, contains('opcode:  7'));
      expect(report, contains('characteristic: CURRENT_STATUS'));
      expect(report, contains('cargo:   AA BB'));
      expect(report, contains('decoded: {"alerts":[]}'));
    });

    test('an rx response uses the response arrow', () {
      final e = ProbeEvent.fromMap(const {'direction': 'rx', 'name': 'X'});
      expect(e.toReport(), contains('← RESPONSE  X'));
    });

    test('absent opcode/characteristic/cargo/json render as placeholders, '
        'not "null"', () {
      final e = ProbeEvent.fromMap(const {'direction': 'rx', 'name': 'X'});
      final report = e.toReport();

      expect(report, contains('opcode:  —'));
      expect(report, contains('characteristic: —'));
      expect(report, contains('cargo:   (empty)'));
      expect(report, isNot(contains('decoded:')));
    });
  });

  group('ProbeCatalog / ProbeCatalogFlat.sweepable', () {
    test('every group has a non-empty title and at least one request', () {
      for (final g in ProbeCatalog.groups) {
        expect(g.title, isNotEmpty);
        expect(g.requests, isNotEmpty, reason: g.title);
      }
    });

    test('sweepable excludes every parametric request', () {
      final sweepable = ProbeCatalogFlat.sweepable;
      expect(sweepable.any((r) => r.parametric), isFalse);
      // The catalog does contain parametric entries (IDPSegmentRequest,
      // HistoryLogRequest) -- prove sweepable is a real filter, not a no-op alias
      // for the full catalog.
      final total =
          ProbeCatalog.groups.fold<int>(0, (n, g) => n + g.requests.length);
      expect(sweepable.length, lessThan(total));
    });

    test('sweepable de-duplicates by class name', () {
      final classNames = ProbeCatalogFlat.sweepable.map((r) => r.className);
      expect(classNames.toSet().length, classNames.length);
    });

    test('ProbeRequest.parametric is true iff params is non-empty', () {
      const withParams =
          ProbeRequest('X', 'label', 'note', params: ['a']);
      const withoutParams = ProbeRequest('Y', 'label', 'note');
      expect(withParams.parametric, isTrue);
      expect(withoutParams.parametric, isFalse);
    });
  });
}
