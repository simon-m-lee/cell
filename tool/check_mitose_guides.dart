// -----------------------------------------------------------------------------
// Structural conformance checks for the Mitose guide scripts.
//
// Run from the repository root:
//   dart tool/check_mitose_guides.dart
//
// Checks:
//   1. Every guide file that carries an `*End of …*` marker has that marker on
//      its last non-empty line (no content may trail the marker).
//   2. The generator manifest in Document_AI_MasterGenerator.md matches the
//      version footer of each generator file.
//   3. Every `.md` file referenced from Document_AI_MasterGenerator.md exists
//      in guide/.
//   4. HowTo-Mitose.md still defines Rules 25 and 26 (referenced by the
//      master generator's consolidated rule sections).
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
    final lastNonEmptyIndex =
        trimmed.lastIndexWhere((l) => l.isNotEmpty);
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

  // --- Check 2 + 3: master manifest and referenced files ---------------------
  final masterFile = File('guide/Document_AI_MasterGenerator.md');
  if (!masterFile.existsSync()) {
    fail('Document_AI_MasterGenerator.md is missing.');
    exit(1);
  }
  final masterLines = masterFile.readAsLinesSync();
  final masterText = masterFile.readAsStringSync();

  // Referenced .md files must exist.
  final refs = RegExp(r'`([A-Za-z0-9_-]+\.md)`')
      .allMatches(masterText)
      .map((m) => m.group(1)!)
      .toSet();
  for (final ref in refs) {
    if (!File('guide/$ref').existsSync()) {
      fail('Document_AI_MasterGenerator.md references missing file: guide/$ref');
    }
  }
  ok('check 3: ${refs.length} referenced .md files exist in guide/');

  // Master header version must match its footer version.
  final headerVersion =
      RegExp(r'\*\*Version:\*\*\s*([0-9.]+)').firstMatch(masterText)?.group(1);
  final masterFooter = masterLines
      .map((l) => l.trim())
      .lastWhere((l) => l.isNotEmpty);
  final footerVersion = RegExp(r'v([0-9.]+)\.\*$')
      .firstMatch(masterFooter)
      ?.group(1);
  if (headerVersion == null || footerVersion == null) {
    fail('Document_AI_MasterGenerator.md: version header or footer not found.');
  } else if (headerVersion != footerVersion) {
    fail('Document_AI_MasterGenerator.md: header v$headerVersion != footer '
        'v$footerVersion.');
  } else {
    ok('check 2a: master generator header and footer both v$headerVersion');
  }

  // Manifest entries must match each generator's footer version.
  var manifestChecked = 0;
  var inManifest = false;
  for (final line in masterLines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('## Generator manifest')) {
      inManifest = true;
      continue;
    }
    if (inManifest && trimmed.startsWith('## ')) break;
    if (!inManifest || !trimmed.startsWith('|')) continue;
    final cells = trimmed.split('|').map((c) => c.trim()).toList();
    if (cells.length < 3) continue;
    final name = RegExp(r'`([A-Za-z0-9_-]+\.md)`').firstMatch(cells[1])?.group(1);
    final version = RegExp(r'^([0-9.]+)$').firstMatch(cells[2])?.group(1);
    if (name == null || version == null) continue;
    final generator = File('guide/$name');
    if (!generator.existsSync()) {
      fail('manifest lists missing generator: guide/$name');
      continue;
    }
    final lastNonEmpty = generator
        .readAsLinesSync()
        .map((l) => l.trim())
        .lastWhere((l) => l.isNotEmpty);
    if (lastNonEmpty != '*End of $name v$version.*') {
      fail('$name: footer "$lastNonEmpty" does not match manifest v$version');
    } else {
      manifestChecked++;
    }
  }
  ok('check 2b: $manifestChecked manifest entries match generator footers');

  // --- Check 4: Rules 25 and 26 still exist ----------------------------------
  final mitoseLines = File('guide/HowTo-Mitose.md').readAsLinesSync();
  for (final rule in ['25', '26']) {
    final present = mitoseLines.any((l) => l.startsWith('$rule. **'));
    if (!present) {
      fail('HowTo-Mitose.md: Rule $rule not found (referenced by the master '
          'generator).');
    }
  }
  ok('check 4: Rules 25 and 26 present in HowTo-Mitose.md');

  if (failures > 0) {
    stdout.writeln('\n$failures guide check(s) failed.');
    exit(1);
  }
  stdout.writeln('\nAll Mitose guide checks passed.');
}
