/// The Nightscout follower pull loop (issue #75).
library;

import 'dart:convert';

import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/integrations/nightscout.dart';
import 'package:bgdude/integrations/nightscout_pull.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/faults.dart';

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.body);

  final String body;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      request: request,
    );
  }
}

String _entries(List<(String, DateTime, double)> rows) => jsonEncode([
      for (final (id, time, mgdl) in rows)
        {
          '_id': id,
          'type': 'sgv',
          'sgv': mgdl,
          'date': time.toUtc().millisecondsSinceEpoch,
        },
    ]);

NightscoutClient _client(http.Client httpClient, {bool follower = true}) =>
    NightscoutClient(
      NightscoutConfig(
        baseUrl: 'https://ns.example.com',
        apiSecret: 'secret',
        followerEnabled: follower,
      ),
      httpClient: httpClient,
    );

void main() {
  final now = DateTime(2026, 7, 4, 12, 0);
  final t1 = now.subtract(const Duration(minutes: 10));
  final t2 = now.subtract(const Duration(minutes: 5));
  final windowStart = now.subtract(const Duration(hours: 12));

  /// Everything stored in the pull window.
  Future<List<CgmSample>> stored(HistoryRepository repo) =>
      repo.cgm(windowStart, now.add(const Duration(hours: 1)));

  test('new readings are fetched and stored', () async {
    final repo = InMemoryHistoryRepository();
    final puller = NightscoutPuller(
      client:
          _client(_FakeHttpClient(_entries([('a', t1, 120), ('b', t2, 125)]))),
      repository: repo,
    );

    final result = await puller.pull(now: now);
    final rows = await stored(repo);

    expect(result.fetched, 2);
    expect(result.ingested, 2);
    expect(rows.map((s) => s.mgdl.value), [120, 125]);
    expect(rows.every((s) => s.source == GlucoseSource.nightscout), isTrue);
  });

  test('a reading the pump already recorded is not stored again', () async {
    // The whole point of the merge: bgdude usually pushed this reading to
    // Nightscout itself, so pulling it back would double-count it.
    final repo = InMemoryHistoryRepository();
    await repo.saveCgm([CgmSample(time: t1, mgdl: 120)]);

    final puller = NightscoutPuller(
      client:
          _client(_FakeHttpClient(_entries([('a', t1, 120), ('b', t2, 125)]))),
      repository: repo,
    );

    final result = await puller.pull(now: now);
    final rows = await stored(repo);

    expect(result.ingested, 1);
    expect(rows, hasLength(2));
    expect(
      rows.where((s) => s.source == GlucoseSource.nightscout).single.time,
      t2,
    );
  });

  test('a second poll over the same window ingests nothing new', () async {
    // Every poll re-fetches an overlapping window; without idempotency this
    // duplicates every reading on every tick.
    final repo = InMemoryHistoryRepository();
    final puller = NightscoutPuller(
      client: _client(_FakeHttpClient(_entries([('a', t1, 120)]))),
      repository: repo,
    );

    await puller.pull(now: now);
    final second = await puller.pull(now: now);

    expect(second.fetched, 1);
    expect(second.ingested, 0);
    expect(await stored(repo), hasLength(1));
  });

  test('follower mode off means no network call at all', () async {
    final fake = _FakeHttpClient(_entries([('a', t1, 120)]));
    final repo = InMemoryHistoryRepository();
    final puller = NightscoutPuller(
      client: _client(fake, follower: false),
      repository: repo,
    );

    final result = await puller.pull(now: now);

    expect(result.skipped, isTrue);
    expect(fake.calls, 0);
    expect(await stored(repo), isEmpty);
  });

  test('a failed write does not mark the readings as ingested', () async {
    // Otherwise the next poll skips them and those readings are lost for good.
    final repo = FaultInjectingHistoryRepository()..failOn('saveCgm');
    final puller = NightscoutPuller(
      client: _client(_FakeHttpClient(_entries([('a', t1, 120)]))),
      repository: repo,
    );

    final first = await puller.pull(now: now);
    expect(first.ingested, 0);

    repo.clearFailOn('saveCgm');
    final second = await puller.pull(now: now);
    expect(second.ingested, 1, reason: 'the retry must succeed');
    expect(await stored(repo), hasLength(1));
  });

  test('an empty site is not an error', () async {
    final repo = InMemoryHistoryRepository();
    final puller = NightscoutPuller(
      client: _client(_FakeHttpClient('[]')),
      repository: repo,
    );

    final result = await puller.pull(now: now);

    expect(result.fetched, 0);
    expect(result.ingested, 0);
    expect(await stored(repo), isEmpty);
  });
}
