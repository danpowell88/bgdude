// Coverage merge + exclusion + gate (issue #378).
//
// One implementation shared by CI and local runs, so the number a developer sees
// locally is the number `coverage-gate` enforces. It replaces the previous inline
// `awk` filename match (which hard-coded a single generated file) and the
// `lcov --add-tracefile` merge step, so there is exactly one place that decides
// what counts: tools/coverage_exclusions.txt.
//
// Usage:
//   dart run tools/coverage_report.dart [options] [<lcov files/dirs>...]
//
//   --min <pct>        Fail (exit 1) if included coverage is below this floor.
//   --emit <file>      Write the included percentage (one decimal) to <file>.
//   --uncovered [<n>]  List the <n> worst included files by uncovered lines.
//   --exclusions <f>   Exclusion list (default tools/coverage_exclusions.txt).
//
// Positional arguments may be lcov tracefiles or directories searched recursively
// for `lcov.info` (that is how CI passes the downloaded per-shard artifacts).
// Defaults to coverage/lcov.info. Multiple tracefiles are merged by summing per
// line hit counts, so a file executed by more than one shard is counted once —
// the same semantics as `lcov --add-tracefile`, not a naive concatenation.

import 'dart:io';

void main(List<String> argv) {
  final args = _Args.parse(argv);

  final tracefiles = _resolveTracefiles(args.inputs);
  if (tracefiles.isEmpty) {
    _fail('no lcov tracefiles found in: ${args.inputs.join(', ')}');
  }

  final exclusions = _Exclusions.load(args.exclusionsFile);
  final merged = _merge(tracefiles);

  final included = _Totals();
  final excluded = _Totals();
  final gaps = <_FileGap>[];
  var includedFiles = 0;

  for (final entry in merged.entries) {
    final path = entry.key;
    final lines = entry.value;
    final found = lines.length;
    final hit = lines.values.where((h) => h > 0).length;

    if (exclusions.matches(path)) {
      excluded.add(hit, found);
      continue;
    }
    included.add(hit, found);
    includedFiles++;
    if (hit < found) {
      gaps.add(_FileGap(path, found - hit, hit, found));
    }
  }

  if (included.found == 0) {
    _fail(
      'no includable lines found across ${tracefiles.length} tracefile(s) — '
      'the exclusion list is almost certainly too broad',
    );
  }

  final pct = included.percent;
  final pctText = pct.toStringAsFixed(1);

  stdout.writeln(
    'Line coverage: $pctText% (${included.hit}/${included.found} lines) '
    'across $includedFiles included files, '
    'merged from ${tracefiles.length} tracefile(s)',
  );
  if (excluded.found > 0) {
    // Informational only. Excluded code is not gated, but printing it keeps the
    // exclusion list honest: a suspiciously large excluded denominator is the
    // signal that something was excluded to dodge tests rather than on merit.
    stdout.writeln(
      'Excluded (not gated): ${excluded.percent.toStringAsFixed(1)}% '
      '(${excluded.hit}/${excluded.found} lines) over '
      '${exclusions.matchedGlobs.length} matching glob(s)',
    );
  }

  for (final glob in exclusions.staleGlobs) {
    // A glob matching nothing is stale — the file was renamed or deleted and the
    // exclusion silently outlived it. Warn rather than fail so a rename does not
    // block an unrelated PR, but make it visible in the log.
    stderr.writeln(
      'WARNING: exclusion glob matched no file and may be stale: $glob',
    );
  }

  if (args.uncovered > 0 && gaps.isNotEmpty) {
    gaps.sort((a, b) => b.missing.compareTo(a.missing));
    stdout.writeln('\nLargest uncovered gaps on included code:');
    for (final gap in gaps.take(args.uncovered)) {
      stdout.writeln(
        '  ${gap.missing.toString().padLeft(5)} uncovered  '
        '${gap.hit}/${gap.found}  ${gap.path}',
      );
    }
  }

  if (args.emit != null) {
    File(args.emit!).writeAsStringSync('$pctText\n');
  }

  if (args.min != null) {
    // Compare in integer tenths, matching the printed/emitted precision. A float
    // comparison against the unrounded value can fail a run sitting exactly on
    // the floor (the rounding trap fixed for the ratchet in issue #368).
    final tenths = (pct * 10).round();
    final minTenths = (args.min! * 10).round();
    if (tenths < minTenths) {
      _fail('line coverage $pctText% is below the ${args.min}% minimum');
    }
  }
}

/// Sums per-line hit counts across tracefiles: {sourcePath: {line: hits}}.
Map<String, Map<int, int>> _merge(List<File> tracefiles) {
  final merged = <String, Map<int, int>>{};
  for (final file in tracefiles) {
    String? current;
    for (final raw in file.readAsLinesSync()) {
      final line = raw.trim();
      if (line.startsWith('SF:')) {
        current = _normalize(line.substring(3));
        merged.putIfAbsent(current, () => <int, int>{});
      } else if (line == 'end_of_record') {
        current = null;
      } else if (current != null && line.startsWith('DA:')) {
        // DA:<line>,<hits>[,<checksum>]
        final parts = line.substring(3).split(',');
        if (parts.length < 2) continue;
        final lineNo = int.tryParse(parts[0]);
        final hits = int.tryParse(parts[1]);
        if (lineNo == null || hits == null) continue;
        merged[current]!.update(
          lineNo,
          (existing) => existing + hits,
          ifAbsent: () => hits,
        );
      }
    }
  }
  return merged;
}

/// Repo-relative, forward-slashed. `flutter test --coverage` emits Windows
/// separators on Windows and may emit an absolute path; both must match the same
/// glob as CI's Linux output or the exclusion list would be platform-dependent.
String _normalize(String path) {
  var p = path.replaceAll('\\', '/').trim();
  final marker = p.indexOf('/lib/');
  if (p.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(p)) {
    if (marker >= 0) p = p.substring(marker + 1);
  }
  return p;
}

List<File> _resolveTracefiles(List<String> inputs) {
  final found = <File>[];
  for (final input in inputs) {
    final dir = Directory(input);
    if (dir.existsSync()) {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('lcov.info')) {
          found.add(entity);
        }
      }
      continue;
    }
    final file = File(input);
    if (file.existsSync()) found.add(file);
  }
  found.sort((a, b) => a.path.compareTo(b.path));
  return found;
}

class _Totals {
  int hit = 0;
  int found = 0;
  void add(int h, int f) {
    hit += h;
    found += f;
  }

  double get percent => found == 0 ? 0 : 100 * hit / found;
}

class _FileGap {
  _FileGap(this.path, this.missing, this.hit, this.found);
  final String path;
  final int missing;
  final int hit;
  final int found;
}

class _Exclusions {
  _Exclusions(this._globs);

  final Map<String, RegExp> _globs;
  final Set<String> matchedGlobs = <String>{};

  static _Exclusions load(String path) {
    final file = File(path);
    if (!file.existsSync()) _fail('exclusion list not found: $path');
    final globs = <String, RegExp>{};
    for (final raw in file.readAsLinesSync()) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      globs[line] = _globToRegExp(line);
    }
    if (globs.isEmpty) _fail('exclusion list is empty: $path');
    return _Exclusions(globs);
  }

  bool matches(String path) {
    var matched = false;
    for (final entry in _globs.entries) {
      if (entry.value.hasMatch(path)) {
        matchedGlobs.add(entry.key);
        matched = true;
      }
    }
    return matched;
  }

  /// Globs that matched no tracefile entry AND cannot be accounted for by a file
  /// that exists but was never imported by a test. `lib/main.dart` is the standing
  /// example: it is excluded on principle, yet no unit test imports it, so it never
  /// appears in the tracefile at all. Warning on that every run would train readers
  /// to ignore the warning — which is the one outcome that makes a staleness check
  /// worthless. A wildcard glob has no single path to check, so it still warns.
  Iterable<String> get staleGlobs => _globs.keys.where(
        (g) =>
            !matchedGlobs.contains(g) &&
            !(_isLiteral(g) && File(g).existsSync()),
      );

  static bool _isLiteral(String glob) =>
      !glob.contains('*') && !glob.contains('?');

  /// `**` spans separators, `*` stays within one segment, `?` is one character.
  /// Everything else is matched literally.
  static RegExp _globToRegExp(String glob) {
    final buffer = StringBuffer('^');
    for (var i = 0; i < glob.length; i++) {
      final char = glob[i];
      if (char == '*') {
        if (i + 1 < glob.length && glob[i + 1] == '*') {
          buffer.write('.*');
          i++;
        } else {
          buffer.write('[^/]*');
        }
      } else if (char == '?') {
        buffer.write('[^/]');
      } else {
        buffer.write(RegExp.escape(char));
      }
    }
    buffer.write(r'$');
    return RegExp(buffer.toString());
  }
}

class _Args {
  _Args(this.inputs, this.min, this.emit, this.uncovered, this.exclusionsFile);

  final List<String> inputs;
  final double? min;
  final String? emit;
  final int uncovered;
  final String exclusionsFile;

  static _Args parse(List<String> argv) {
    final inputs = <String>[];
    double? min;
    String? emit;
    var uncovered = 0;
    var exclusionsFile = 'tools/coverage_exclusions.txt';

    for (var i = 0; i < argv.length; i++) {
      switch (argv[i]) {
        case '--min':
          min = double.tryParse(_value(argv, ++i, '--min'));
          if (min == null) _fail('--min expects a number');
        case '--emit':
          emit = _value(argv, ++i, '--emit');
        case '--exclusions':
          exclusionsFile = _value(argv, ++i, '--exclusions');
        case '--uncovered':
          // Optional count: `--uncovered` alone means "the default 20".
          if (i + 1 < argv.length && int.tryParse(argv[i + 1]) != null) {
            uncovered = int.parse(argv[++i]);
          } else {
            uncovered = 20;
          }
        default:
          if (argv[i].startsWith('--')) _fail('unknown option: ${argv[i]}');
          inputs.add(argv[i]);
      }
    }
    if (inputs.isEmpty) inputs.add('coverage/lcov.info');
    return _Args(inputs, min, emit, uncovered, exclusionsFile);
  }

  static String _value(List<String> argv, int i, String flag) {
    if (i >= argv.length) _fail('$flag expects a value');
    return argv[i];
  }
}

Never _fail(String message) {
  stderr.writeln('::error::$message');
  exit(1);
}
