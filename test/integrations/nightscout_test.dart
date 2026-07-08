import 'dart:convert';

import 'package:bgdude/core/samples.dart';
import 'package:bgdude/integrations/nightscout.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// A minimal fake [http.Client] that records the last request and returns a
/// canned response. It never touches the network.
class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient({this.statusCode = 200});

  final int statusCode;
  final String body = '{}';

  int callCount = 0;
  String? lastMethod;
  Uri? lastUrl;
  Map<String, String>? lastHeaders;
  String? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    lastMethod = request.method;
    lastUrl = request.url;
    lastHeaders = request.headers;
    if (request is http.Request) {
      lastBody = request.body;
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      statusCode,
      request: request,
    );
  }
}

void main() {
  final DateTime t = DateTime.utc(2026, 7, 4, 12, 30);

  group('entryFromCgm', () {
    test('produces the expected sgv document shape', () {
      final sample = CgmSample(time: t, mgdl: 142.6, trend: GlucoseTrend.flat);
      final doc = NightscoutClient.entryFromCgm(sample);

      expect(doc['type'], 'sgv');
      expect(doc['sgv'], 143); // rounded
      expect(doc['date'], t.millisecondsSinceEpoch);
      expect(doc['dateString'], t.toUtc().toIso8601String());
      expect(doc['direction'], 'Flat');
      expect(doc['device'], 'bgdude');
    });

    test('sgv is an int', () {
      final doc = NightscoutClient.entryFromCgm(
          CgmSample(time: t, mgdl: 99.9, trend: GlucoseTrend.unknown));
      expect(doc['sgv'], isA<int>());
      expect(doc['sgv'], 100);
    });
  });

  group('direction mapping', () {
    test('every trend maps to its Nightscout direction', () {
      expect(NightscoutClient.directionFor(GlucoseTrend.doubleUp), 'DoubleUp');
      expect(NightscoutClient.directionFor(GlucoseTrend.singleUp), 'SingleUp');
      expect(NightscoutClient.directionFor(GlucoseTrend.fortyFiveUp),
          'FortyFiveUp');
      expect(NightscoutClient.directionFor(GlucoseTrend.flat), 'Flat');
      expect(NightscoutClient.directionFor(GlucoseTrend.fortyFiveDown),
          'FortyFiveDown');
      expect(
          NightscoutClient.directionFor(GlucoseTrend.singleDown), 'SingleDown');
      expect(
          NightscoutClient.directionFor(GlucoseTrend.doubleDown), 'DoubleDown');
      expect(NightscoutClient.directionFor(GlucoseTrend.unknown), 'NONE');
    });
  });

  group('treatment builders', () {
    test('bolus with carbs is a Meal Bolus', () {
      final doc = NightscoutClient.treatmentFromBolus(
          BolusEvent(time: t, units: 3.5, carbsGrams: 40));
      expect(doc['eventType'], 'Meal Bolus');
      expect(doc['insulin'], 3.5);
      expect(doc['carbs'], 40);
      expect(doc['created_at'], t.toUtc().toIso8601String());
      expect(doc['enteredBy'], 'bgdude');
    });

    test('bolus without carbs is a plain Bolus and omits carbs', () {
      final doc = NightscoutClient.treatmentFromBolus(
          BolusEvent(time: t, units: 1.2));
      expect(doc['eventType'], 'Bolus');
      expect(doc['insulin'], 1.2);
      expect(doc.containsKey('carbs'), isFalse);
    });

    test('carb entry is a Carb Correction', () {
      final doc = NightscoutClient.treatmentFromCarb(
          CarbEntry(time: t, grams: 15));
      expect(doc['eventType'], 'Carb Correction');
      expect(doc['carbs'], 15);
      expect(doc['created_at'], t.toUtc().toIso8601String());
      expect(doc['enteredBy'], 'bgdude');
    });

    test('devicestatus carries iob', () {
      final doc = NightscoutClient.devicestatus(iob: 2.4, at: t);
      expect(doc['device'], 'bgdude');
      expect(doc['created_at'], t.toUtc().toIso8601String());
      final openaps = doc['openaps'] as Map<String, dynamic>;
      expect(openaps['iob'], isA<Map<String, dynamic>>());
      expect((openaps['iob'] as Map<String, dynamic>)['iob'], 2.4);
      expect((doc['iob'] as Map<String, dynamic>)['iob'], 2.4);
    });
  });

  group('api-secret header', () {
    test('is the lowercase SHA1 hex of the plaintext secret', () async {
      const secret = 'my-super-secret-token';
      final expected = sha1.convert(utf8.encode(secret)).toString();

      final fake = _FakeHttpClient();
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://ns.example.com',
            apiSecret: secret,
            enabled: true),
        httpClient: fake,
      );

      await client.uploadEntries(
          [CgmSample(time: t, mgdl: 120, trend: GlucoseTrend.flat)]);

      expect(fake.lastHeaders?['api-secret'], expected);
    });
  });

  group('uploadEntries with mocked client', () {
    test('POSTs to the entries URL with header and JSON body', () async {
      final fake = _FakeHttpClient();
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://ns.example.com/',
            apiSecret: 'secret1234567',
            enabled: true),
        httpClient: fake,
      );

      await client.uploadEntries([
        CgmSample(time: t, mgdl: 155, trend: GlucoseTrend.singleUp),
      ]);

      expect(fake.callCount, 1);
      expect(fake.lastMethod, 'POST');
      // Trailing slash on baseUrl is trimmed.
      expect(fake.lastUrl.toString(), 'https://ns.example.com/api/v1/entries');
      expect(fake.lastHeaders?['content-type'], contains('application/json'));

      final decoded = jsonDecode(fake.lastBody!) as List<dynamic>;
      expect(decoded, hasLength(1));
      final entry = decoded.first as Map<String, dynamic>;
      expect(entry['type'], 'sgv');
      expect(entry['sgv'], 155);
      expect(entry['direction'], 'SingleUp');
    });

    test('uploadTreatments posts mixed boluses and carbs', () async {
      final fake = _FakeHttpClient();
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://ns.example.com',
            apiSecret: 'secret1234567',
            enabled: true),
        httpClient: fake,
      );

      await client.uploadTreatments(<dynamic>[
        BolusEvent(time: t, units: 2, carbsGrams: 30),
        CarbEntry(time: t, grams: 10),
      ]);

      expect(fake.lastUrl.toString(),
          'https://ns.example.com/api/v1/treatments');
      final decoded = jsonDecode(fake.lastBody!) as List<dynamic>;
      expect(decoded, hasLength(2));
      expect((decoded[0] as Map)['eventType'], 'Meal Bolus');
      expect((decoded[1] as Map)['eventType'], 'Carb Correction');
    });

    test('uploadDeviceStatus posts to devicestatus', () async {
      final fake = _FakeHttpClient();
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://ns.example.com',
            apiSecret: 'secret1234567',
            enabled: true),
        httpClient: fake,
      );

      await client.uploadDeviceStatus(iob: 1.1, at: t);

      expect(fake.lastUrl.toString(),
          'https://ns.example.com/api/v1/devicestatus');
      final decoded = jsonDecode(fake.lastBody!) as List<dynamic>;
      expect((decoded.first as Map)['device'], 'bgdude');
    });
  });

  group('disabled / empty config no-ops', () {
    test('disabled config performs no HTTP call', () async {
      final fake = _FakeHttpClient();
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://ns.example.com',
            apiSecret: 'secret1234567',
            enabled: false),
        httpClient: fake,
      );

      await client.uploadEntries(
          [CgmSample(time: t, mgdl: 120, trend: GlucoseTrend.flat)]);

      expect(fake.callCount, 0);
    });

    test('empty baseUrl performs no HTTP call', () async {
      final fake = _FakeHttpClient();
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: '', apiSecret: 'secret1234567', enabled: true),
        httpClient: fake,
      );

      await client.uploadEntries(
          [CgmSample(time: t, mgdl: 120, trend: GlucoseTrend.flat)]);

      expect(fake.callCount, 0);
    });

    test('empty document list performs no HTTP call', () async {
      final fake = _FakeHttpClient();
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://ns.example.com',
            apiSecret: 'secret1234567',
            enabled: true),
        httpClient: fake,
      );

      await client.uploadEntries(<CgmSample>[]);

      expect(fake.callCount, 0);
    });
  });

  group('network errors never throw', () {
    test('a throwing client is swallowed', () async {
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://ns.example.com',
            apiSecret: 'secret1234567',
            enabled: true),
        httpClient: _ThrowingClient(),
      );

      // Should complete without throwing.
      await client.uploadEntries(
          [CgmSample(time: t, mgdl: 120, trend: GlucoseTrend.flat)]);
    });

    // uploadDeviceStatus/testConnection go through the same http.Client
    // seam but weren't individually pinned -- only uploadEntries was.
    test('uploadDeviceStatus with a throwing client is swallowed', () async {
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://ns.example.com',
            apiSecret: 'secret1234567',
            enabled: true),
        httpClient: _ThrowingClient(),
      );

      await expectLater(
          client.uploadDeviceStatus(iob: 1.2, at: t), completes);
    });

    test('testConnection with a throwing client returns false, does not throw',
        () async {
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://ns.example.com',
            apiSecret: 'secret1234567',
            enabled: true),
        httpClient: _ThrowingClient(),
      );

      expect(await client.testConnection(), isFalse);
    });
  });

  group('config json round-trip', () {
    test('toJson/fromJson preserves fields', () {
      const cfg = NightscoutConfig(
          baseUrl: 'https://ns.example.com',
          apiSecret: 'secret1234567',
          enabled: true);
      final restored = NightscoutConfig.fromJson(cfg.toJson());
      expect(restored, cfg);
    });
  });

  group('testConnection', () {
    test('hits status.json and returns true on 2xx', () async {
      final fake = _FakeHttpClient(statusCode: 200);
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://ns.example.com',
            apiSecret: 'secret1234567',
            enabled: true),
        httpClient: fake,
      );

      final ok = await client.testConnection();
      expect(ok, isTrue);
      expect(fake.lastMethod, 'GET');
      expect(fake.lastUrl.toString(),
          'https://ns.example.com/api/v1/status.json');
    });

    test('returns false on 5xx', () async {
      final fake = _FakeHttpClient(statusCode: 500);
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://ns.example.com',
            apiSecret: 'secret1234567',
            enabled: true),
        httpClient: fake,
      );
      expect(await client.testConnection(), isFalse);
    });
  });
}

/// A fake client whose every request throws, to prove uploads swallow errors.
class _ThrowingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw const _FakeSocketException();
  }
}

class _FakeSocketException implements Exception {
  const _FakeSocketException();
  @override
  String toString() => 'Simulated network failure';
}
