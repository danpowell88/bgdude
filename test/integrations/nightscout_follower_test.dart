/// Nightscout follower mode — parsing and merge decisions (issue #75).
library;

import 'dart:convert';

import 'package:bgdude/core/samples.dart';
import 'package:bgdude/integrations/nightscout.dart';
import 'package:bgdude/integrations/nightscout_follower.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Fake [http.Client] returning a canned body and recording the request.
class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.body, {this.statusCode = 200});

  final String body;
  final int statusCode;
  Uri? lastUrl;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUrl = request.url;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      statusCode,
      request: request,
    );
  }
}

/// Throws on any request — a site that is down or unreachable.
class _DeadHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw Exception('connection refused');
}

NightscoutClient _client(http.Client httpClient) => NightscoutClient(
      const NightscoutConfig(
        baseUrl: 'https://ns.example.com',
        apiSecret: 'secret',
        // Reads are gated on followerEnabled, not on `enabled` (which is the upload
        // switch) — the two directions are independent.
        followerEnabled: true,
      ),
      httpClient: httpClient,
    );

void main() {
  group('parseEntries', () {
    test('reads sgv, time and direction', () {
      final entries = parseEntries(jsonEncode([
        {
          '_id': 'abc123',
          'type': 'sgv',
          'sgv': 142,
          'date': DateTime.utc(2026, 7, 4, 12, 30).millisecondsSinceEpoch,
          'direction': 'FortyFiveUp',
        },
      ]));

      expect(entries, hasLength(1));
      expect(entries.single.id, 'abc123');
      expect(entries.single.mgdl, 142);
      expect(entries.single.toSample().trend, GlucoseTrend.fortyFiveUp);
      // Normalised to local wall-clock, as every time-of-day feature expects.
      expect(entries.single.toSample().time.isUtc, isFalse);
      expect(entries.single.toSample().source, GlucoseSource.nightscout);
    });

    test('accepts dateString when date is absent', () {
      // Uploaders differ in which field they set; requiring `date` would silently
      // read nothing from a site that only writes ISO strings.
      final entries = parseEntries(jsonEncode([
        {'_id': 'a', 'sgv': 100, 'dateString': '2026-07-04T12:30:00.000Z'},
      ]));

      expect(entries, hasLength(1));
      expect(entries.single.time.toUtc(), DateTime.utc(2026, 7, 4, 12, 30));
    });

    test('a malformed document does not lose the rest of the batch', () {
      final entries = parseEntries(jsonEncode([
        {'_id': 'good1', 'sgv': 100, 'date': 1000},
        {'_id': 'nosgv', 'date': 2000},
        'not even an object',
        {'_id': 'notime', 'sgv': 120},
        {'_id': 'good2', 'sgv': 110, 'date': 3000},
      ]));

      expect(entries.map((e) => e.id), ['good1', 'good2']);
    });

    test('non-sgv documents are excluded', () {
      // Calibrations and meter batches are not sensor readings.
      final entries = parseEntries(jsonEncode([
        {'_id': 'cal', 'type': 'cal', 'sgv': 100, 'date': 1000},
        {'_id': 'sgv', 'type': 'sgv', 'sgv': 100, 'date': 2000},
      ]));

      expect(entries.map((e) => e.id), ['sgv']);
    });

    test('zero and negative sgv values are rejected', () {
      final entries = parseEntries(jsonEncode([
        {'_id': 'zero', 'sgv': 0, 'date': 1000},
        {'_id': 'neg', 'sgv': -5, 'date': 2000},
      ]));

      expect(entries, isEmpty);
    });

    test('an HTML login page yields nothing rather than throwing', () {
      // A site behind auth returns HTML. That is misconfiguration, not a crash.
      expect(parseEntries('<html><body>Login</body></html>'), isEmpty);
      expect(parseEntries(''), isEmpty);
      expect(parseEntries('{"not":"a list"}'), isEmpty);
    });

    test('a missing direction is unknown, not flat', () {
      // "No arrow" and "not moving" are different claims.
      final entries = parseEntries(jsonEncode([
        {'_id': 'a', 'sgv': 100, 'date': 1000},
      ]));

      expect(entries.single.toSample().trend, GlucoseTrend.unknown);
    });

    test('direction round-trips against the uploader mapping', () {
      // Guards the two halves drifting apart: what we upload must be what we read.
      for (final trend in GlucoseTrend.values) {
        final direction = NightscoutClient.directionFor(trend);
        expect(trendFromDirection(direction), trend, reason: direction);
      }
    });
  });

  group('parseTreatments', () {
    test('reads insulin and carbs', () {
      final treatments = parseTreatments(jsonEncode([
        {
          '_id': 't1',
          'eventType': 'Meal Bolus',
          'insulin': 4.5,
          'carbs': 60,
          'created_at': '2026-07-04T12:30:00.000Z',
        },
      ]));

      expect(treatments.single.insulinUnits, 4.5);
      expect(treatments.single.carbsGrams, 60);
      expect(treatments.single.hasDose, isTrue);
    });

    test('a note with neither insulin nor carbs is not a dose', () {
      final treatments = parseTreatments(jsonEncode([
        {'_id': 'n', 'eventType': 'Note', 'created_at': '2026-07-04T12:30:00Z'},
      ]));

      expect(treatments.single.hasDose, isFalse);
    });

    test('string numbers are accepted', () {
      // Some uploaders write numbers as strings.
      final treatments = parseTreatments(jsonEncode([
        {
          '_id': 't',
          'eventType': 'Bolus',
          'insulin': '2.5',
          'created_at': '2026-07-04T12:30:00Z',
        },
      ]));

      expect(treatments.single.insulinUnits, 2.5);
    });
  });

  group('entriesToIngest', () {
    NightscoutEntry entry(String id, DateTime time) =>
        NightscoutEntry(id: id, time: time, mgdl: 100);

    final t1 = DateTime(2026, 7, 4, 12, 30);
    final t2 = DateTime(2026, 7, 4, 12, 35);

    test('a reading the pump already gave us is not ingested again', () {
      // The core of follower mode: bgdude usually PUSHED this data to Nightscout
      // itself, so pulling it back would double-count the identical reading.
      final out = entriesToIngest(
        [entry('a', t1), entry('b', t2)],
        existingTimes: {t1},
      );

      expect(out.map((e) => e.id), ['b']);
    });

    test('an already-ingested _id is skipped on re-fetch', () {
      // Every poll re-fetches an overlapping window; without this it is not idempotent.
      final out = entriesToIngest(
        [entry('a', t1), entry('b', t2)],
        knownIds: {'a'},
      );

      expect(out.map((e) => e.id), ['b']);
    });

    test('duplicate timestamps within one batch collapse', () {
      // The local table has UNIQUE(time); a site returning two docs for one instant
      // would otherwise blow up the write halfway through.
      final out = entriesToIngest([entry('a', t1), entry('b', t1)]);

      expect(out, hasLength(1));
    });

    test('a UTC timestamp matches an existing local one', () {
      // Readings arrive from the site in UTC and from the pump in local time.
      // Comparing them raw would never match, and every reading would land twice.
      final utc = DateTime.utc(2026, 7, 4, 2, 30);
      final out = entriesToIngest(
        [NightscoutEntry(id: 'a', time: utc, mgdl: 100)],
        existingTimes: {utc.toLocal()},
      );

      expect(out, isEmpty);
    });

    test('entries with no _id are still ingested', () {
      // Absent ids must not be treated as the same empty id and collapsed.
      final out = entriesToIngest(
        [entry('', t1), entry('', t2)],
        knownIds: {''},
      );

      expect(out, hasLength(2));
    });

    test('nothing fetched means nothing ingested', () {
      expect(entriesToIngest(const []), isEmpty);
    });
  });

  group('fetchEntries', () {
    test('parses a successful response', () async {
      final fake = _FakeHttpClient(jsonEncode([
        {'_id': 'a', 'sgv': 120, 'date': 1000},
      ]));

      final entries = await _client(fake).fetchEntries();

      expect(entries.single.mgdl, 120);
    });

    test('sends the since filter in UTC', () async {
      // Sending local time would shift the window by the timezone offset and
      // silently miss or re-fetch hours of data.
      final fake = _FakeHttpClient('[]');

      await _client(fake)
          .fetchEntries(since: DateTime.utc(2026, 7, 4, 2).toLocal());

      expect(fake.lastUrl!.queryParameters[r'find[dateString][$gte]'],
          '2026-07-04T02:00:00.000Z');
    });

    test('an HTTP error degrades to no data, not an exception', () async {
      final entries =
          await _client(_FakeHttpClient('boom', statusCode: 500)).fetchEntries();

      expect(entries, isEmpty);
    });

    test('an unreachable site degrades to no data', () async {
      // A follower pull runs against a server bgdude does not control; it must
      // never break the poll loop.
      expect(await _client(_DeadHttpClient()).fetchEntries(), isEmpty);
      expect(await _client(_DeadHttpClient()).fetchTreatments(), isEmpty);
    });

    test('follower mode off does not call out at all', () async {
      final fake = _FakeHttpClient('[]');
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://ns.example.com', apiSecret: 's'),
        httpClient: fake,
      );

      expect(await client.fetchEntries(), isEmpty);
      expect(fake.lastUrl, isNull);
    });

    test('upload being enabled does NOT switch reading on', () async {
      // Pushing to a site must not imply pulling from it: that is how you re-ingest
      // your own readings and double-count them.
      final fake = _FakeHttpClient('[]');
      final client = NightscoutClient(
        const NightscoutConfig(
          baseUrl: 'https://ns.example.com',
          apiSecret: 's',
          enabled: true,
        ),
        httpClient: fake,
      );

      expect(await client.fetchEntries(), isEmpty);
      expect(fake.lastUrl, isNull);
    });
  });

  group('config persistence', () {
    test('followerEnabled survives a JSON round-trip', () {
      const cfg = NightscoutConfig(
        baseUrl: 'https://ns.example.com',
        apiSecret: 's',
        enabled: true,
        followerEnabled: true,
      );

      expect(NightscoutConfig.fromJson(cfg.toJson()), cfg);
    });

    test('a config saved BEFORE follower mode existed defaults to off', () {
      // An upgrade must never silently start pulling a second copy of the user's
      // own data into their history.
      final legacy = NightscoutConfig.fromJson({
        'baseUrl': 'https://ns.example.com',
        'apiSecret': 's',
        'enabled': true,
      });

      expect(legacy.followerEnabled, isFalse);
      expect(legacy.canFollow, isFalse);
      // Uploading still works exactly as before.
      expect(legacy.isUsable, isTrue);
    });

    test('canFollow needs both the switch and a URL', () {
      expect(
        const NightscoutConfig(followerEnabled: true).canFollow,
        isFalse,
        reason: 'no base URL',
      );
      expect(
        const NightscoutConfig(baseUrl: 'https://x.example').canFollow,
        isFalse,
        reason: 'switch off',
      );
      expect(
        const NightscoutConfig(
                baseUrl: 'https://x.example', followerEnabled: true)
            .canFollow,
        isTrue,
      );
    });

    test('follower and upload are independent in equality', () {
      const a = NightscoutConfig(baseUrl: 'u', followerEnabled: true);
      const b = NightscoutConfig(baseUrl: 'u');
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });
  });
}
