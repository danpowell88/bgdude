/// End-to-end tests for tools/coverage_report.dart — the script that decides
/// whether CI's coverage-gate passes (issue #378, decision-16).
///
/// The gate is load-bearing and lives outside lib/, so it is not covered by the
/// very number it computes; without these tests a bug in the merge or the glob
/// matcher would silently mis-measure every PR. Run as a subprocess (the script
/// is a `main()` with private helpers, and this exercises the real CLI contract
/// CI depends on: arguments, stdout, and exit code).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// One lcov record. [lines] maps line number -> hit count.
String _record(String sourcePath, Map<int, int> lines) {
  final buffer = StringBuffer('SF:$sourcePath\n');
  for (final entry in lines.entries) {
    buffer.writeln('DA:${entry.key},${entry.value}');
  }
  buffer
    ..writeln('LF:${lines.length}')
    ..writeln('LH:${lines.values.where((h) => h > 0).length}')
    ..writeln('end_of_record');
  return buffer.toString();
}

void main() {
  // `flutter test` runs with the package root as cwd.
  final script = p.join(Directory.current.path, 'tools', 'coverage_report.dart');

  late Directory work;

  setUp(() {
    work = Directory.systemTemp.createTempSync('coverage_report_test');
  });
  tearDown(() => work.deleteSync(recursive: true));

  /// Writes [content] to [relative] under the temp dir and returns its path.
  String write(String relative, String content) {
    final file = File(p.join(work.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    return file.path;
  }

  ProcessResult run(List<String> args) => Process.runSync(
        Platform.resolvedExecutable.contains('dart')
            ? Platform.resolvedExecutable
            : 'dart',
        [script, ...args],
        workingDirectory: work.path,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

  test('excluded files leave both the numerator and the denominator', () {
    write('tools/coverage_exclusions.txt', '# rationale\nlib/**.g.dart\n');
    write(
      'coverage/lcov.info',
      _record('lib/a.dart', {1: 1, 2: 1, 3: 0, 4: 0}) +
          // Fully uncovered generated file: if it were merely removed from the
          // numerator the percentage would fall, and if it stayed in both the
          // result would be 25%. Excluding it properly yields exactly 50%.
          _record('lib/data/database.g.dart', {1: 0, 2: 0, 3: 0, 4: 0}),
    );

    final result = run(['coverage/lcov.info']);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('50.0%'));
    expect(result.stdout, contains('(2/4 lines)'));
  });

  test('multiple tracefiles merge by summing hits, not by concatenating', () {
    write('tools/coverage_exclusions.txt', 'lib/**.g.dart\n');
    // The same file appears in two shards. Line 1 is hit only in shard A, line 2
    // only in shard B, line 3 in neither. A naive concatenation would count the
    // file twice (6 lines found); a correct merge reports 3 lines, 2 covered.
    write('shards/a/lcov.info', _record('lib/a.dart', {1: 3, 2: 0, 3: 0}));
    write('shards/b/lcov.info', _record('lib/a.dart', {1: 0, 2: 5, 3: 0}));

    final result = run(['shards']);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('(2/3 lines)'));
    expect(result.stdout, contains('merged from 2 tracefile(s)'));
  });

  test('a directory argument discovers every shard tracefile recursively', () {
    write('tools/coverage_exclusions.txt', 'lib/**.g.dart\n');
    write('shards/coverage-shard-1/lcov.info', _record('lib/a.dart', {1: 1}));
    write('shards/coverage-shard-2/lcov.info', _record('lib/b.dart', {1: 1}));
    write('shards/coverage-shard-3/lcov.info', _record('lib/c.dart', {1: 0}));

    final result = run(['shards']);

    expect(result.stdout, contains('merged from 3 tracefile(s)'));
    expect(result.stdout, contains('across 3 included files'));
  });

  test('`**` spans directories but `*` does not cross a separator', () {
    write('tools/coverage_exclusions.txt', 'lib/ui/**\nlib/*.g.dart\n');
    write(
      'coverage/lcov.info',
      // Excluded by lib/ui/** even though it is several directories deep.
      _record('lib/ui/reports/day_screen.dart', {1: 0, 2: 0}) +
          // NOT excluded: `lib/*.g.dart` must not match across a separator.
          _record('lib/data/database.g.dart', {1: 1, 2: 1}) +
          _record('lib/a.dart', {1: 1, 2: 0}),
    );

    final result = run(['coverage/lcov.info']);

    expect(result.stdout, contains('(3/4 lines)'));
    expect(result.stdout, contains('across 2 included files'));
  });

  test('an absolute or Windows-separated source path still matches a glob', () {
    write('tools/coverage_exclusions.txt', 'lib/ui/**\n');
    write(
      'coverage/lcov.info',
      // Coverage collected on Windows emits backslashes and can emit an absolute
      // path; the exclusion list must not become platform-dependent.
      _record(r'C:\dev\bgdude\lib\ui\home_screen.dart', {1: 0, 2: 0}) +
          _record('/home/runner/work/bgdude/lib/ui/pump_screen.dart', {1: 0}) +
          _record('lib/a.dart', {1: 1}),
    );

    final result = run(['coverage/lcov.info']);

    expect(result.stdout, contains('100.0%'));
    expect(result.stdout, contains('across 1 included files'));
  });

  test('--min fails below the floor and passes exactly on it', () {
    write('tools/coverage_exclusions.txt', 'lib/**.g.dart\n');
    write('coverage/lcov.info', _record('lib/a.dart', {1: 1, 2: 1, 3: 1, 4: 0}));

    expect(run(['--min', '80.0']).exitCode, 1,
        reason: '75% must fail an 80% floor');

    // Exactly on the floor must pass: an unrounded float comparison is the trap
    // that failed a PR sitting on the line (issue #368's ratchet bug).
    final onTheFloor = run(['--min', '75.0']);
    expect(onTheFloor.exitCode, 0);
    expect(onTheFloor.stdout, contains('75.0%'));
  });

  test('--emit writes the percentage for the ratchet baseline', () {
    write('tools/coverage_exclusions.txt', 'lib/**.g.dart\n');
    write('coverage/lcov.info', _record('lib/a.dart', {1: 1, 2: 0}));

    final result = run(['--emit', 'pct.txt']);

    expect(result.exitCode, 0);
    expect(File(p.join(work.path, 'pct.txt')).readAsStringSync().trim(), '50.0');
  });

  test('missing tracefiles fail loudly instead of reporting a silent zero', () {
    write('tools/coverage_exclusions.txt', 'lib/**.g.dart\n');

    // TASK-301's signal: a shard that never wrote its lcov.info must red the
    // build, not quietly shrink the denominator until the gate passes anyway.
    final result = run(['shards']);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('no lcov tracefiles found'));
  });

  test('an exclusion list that swallows everything fails rather than passing', () {
    write('tools/coverage_exclusions.txt', 'lib/**\n');
    write('coverage/lcov.info', _record('lib/a.dart', {1: 0, 2: 0}));

    // 0/0 would otherwise be reported as 0% (or crash); either way an over-broad
    // list must not be able to make the gate meaningless.
    final result = run(['coverage/lcov.info']);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('exclusion list is almost certainly too broad'));
  });

  test('a missing exclusion list is a hard error, not an empty exclusion set', () {
    write('coverage/lcov.info', _record('lib/a.dart', {1: 1}));

    // Silently treating a missing list as "exclude nothing" would change the
    // measured number without anyone editing the policy.
    final result = run(['coverage/lcov.info']);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('exclusion list not found'));
  });

  test('a glob matching no file warns as stale unless the file exists on disk', () {
    write(
      'tools/coverage_exclusions.txt',
      'lib/**.g.dart\nlib/deleted_long_ago.dart\nlib/present_but_unimported.dart\n',
    );
    write('lib/present_but_unimported.dart', '// never imported by a test\n');
    write('coverage/lcov.info', _record('lib/a.dart', {1: 1}));

    final result = run(['coverage/lcov.info']);

    expect(result.exitCode, 0);
    expect(result.stderr, contains('lib/deleted_long_ago.dart'));
    // A file that exists but no test imports never appears in the tracefile —
    // warning about it every run would train readers to ignore the warning.
    expect(result.stderr, isNot(contains('present_but_unimported')));
  });

  test('--uncovered ranks included files by uncovered line count', () {
    write('tools/coverage_exclusions.txt', 'lib/ui/**\n');
    write(
      'coverage/lcov.info',
      _record('lib/small_gap.dart', {1: 1, 2: 0}) +
          _record('lib/big_gap.dart', {1: 0, 2: 0, 3: 0, 4: 0, 5: 1}) +
          _record('lib/ui/excluded.dart', {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0}),
    );

    final result = run(['--uncovered', '5']);
    final stdout = result.stdout as String;

    expect(stdout, contains('big_gap.dart'));
    expect(stdout.indexOf('big_gap.dart'),
        lessThan(stdout.indexOf('small_gap.dart')),
        reason: 'the worst gap must be listed first — it is where tests go next');
    // Excluded files are not gaps to close; listing them would send the reader
    // to write exactly the tests the exclusion says not to write.
    expect(stdout, isNot(contains('excluded.dart')));
  });
}
