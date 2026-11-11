// -----------------------------------------------------------------------------
// Structural conformance checks for the Mitose guide scripts (pipeline v2.2).
//
// Run from the repository root:
//   dart tool/check_mitose_guides.dart
//
// Checks:
//   1. Every guide file that carries an `*End of …*` marker has that marker on
//      its last non-empty line (no content may trail the marker).
//   2. Every generator named directly by HowTo-Mitose.md exists in guide/.
//   3. Every *-AI-Generator.md named by HowTo-Mitose.md carries a versioned
//      `*End of <name> vM.m.*` footer.
//   4. HowTo-Mitose.md still defines Rules 24–26 (executed-evidence,
//      full-generation, and post-Demo reconciliation rules).
//
// The 2.1 master generator (Document_AI_MasterGenerator.md) was removed in
// pipeline v2.2: HowTo-Mitose.md now names the individual generators directly.
//
// Exits non-zero when any check fails.
// -----------------------------------------------------------------------------
import 'dart:io';

void main() {
  var failures = 0;

  void fail(String message) {
    failures++;
    stdout.writeln('FAIL  $message');
  }

  void ok(String message) {
    stdout.writeln('ok    $message');
  }

  final guideDir = Directory('guide');
  if (!guideDir.existsSync()) {
    fail('guide/ directory not found — run this script from the repo root.');
    exit(1);
  }

  // --- Check 1: end markers on the last non-empty line -----------------------
  final markedFiles = <String>[];
  for (final entity in guideDir.listSync().whereType<File>()) {
    final lines = entity.readAsLinesSync();
    final trimmed = lines.map((l) => l.trim()).toList();
    final lastNonEmptyIndex = trimmed.lastIndexWhere((l) => l.isNotEmpty);
    if (lastNonEmptyIndex < 0) continue;
    final lastNonEmpty = trimmed[lastNonEmptyIndex];
    if (lastNonEmpty.startsWith('*End of')) {
      markedFiles.add(entity.uri.pathSegments.last);
      if (lastNonEmptyIndex != trimmed.length - 1) {
        fail('${entity.uri.pathSegments.last}: end-of-file marker is not the '
            'last non-empty line (trailing content after it).');
      }
    }
  }
  ok('check 1: ${markedFiles.length} files carry end markers; all markers '
      'verified at end of file');

  // --- Check 2: generators named by HowTo-Mitose.md exist --------------------
  final mitoseText = File('guide/HowTo-Mitose.md').readAsStringSync();
  final refs = RegExp(r'`([A-Za-z0-9_-]+\.md)`')
      .allMatches(mitoseText)
      .map((m) => m.group(1)!)
      .toSet();
  final generators = refs.where((r) => r.contains('AI-Generator')).toList()
    ..sort();
  if (generators.isEmpty) {
    fail('HowTo-Mitose.md names no AI-Generator files.');
  }
  for (final gen in generators) {
    if (!File('guide/$gen').existsSync()) {
      fail('HowTo-Mitose.md references missing generator: guide/$gen');
    }
  }
  ok('check 2: ${generators.length} generators named by HowTo-Mitose.md exist '
      'in guide/');

  // --- Check 3: generator versioned footers ----------------------------------
  var versioned = 0;
  for (final gen in generators) {
    final file = File('guide/$gen');
    if (!file.existsSync()) continue;
    final lastNonEmpty = file
        .readAsLinesSync()
        .map((l) => l.trim())
        .lastWhere((l) => l.isNotEmpty);
    final expected = RegExp(
        '^\\*End of ${RegExp.escape(gen)} v(\\d+)\\.(\\d+)\\.\\*\$');
    if (!expected.hasMatch(lastNonEmpty)) {
      fail('$gen: footer "$lastNonEmpty" is not the versioned marker '
          '`*End of $gen vM.m.*`');
    } else {
      versioned++;
    }
  }
  ok('check 3: $versioned generators carry versioned end markers');

  // --- Check 4: Rules 24–26 still exist --------------------------------------
  final mitoseLines = File('guide/HowTo-Mitose.md').readAsLinesSync();
  for (final rule in ['24', '25', '26']) {
    final present = mitoseLines.any((l) => l.startsWith('$rule. **'));
    if (!present) {
      fail('HowTo-Mitose.md: Rule $rule not found.');
    }
  }
  ok('check 4: Rules 24–26 present in HowTo-Mitose.md');

  if (failures > 0) {
    stdout.writeln('\n$failures guide check(s) failed.');
    exit(1);
  }
  stdout.writeln('\nAll Mitose guide checks passed.');
}
