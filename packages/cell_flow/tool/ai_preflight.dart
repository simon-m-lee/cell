// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// AI preflight: verifies every `Live signature:` pin in the doc comments and
// every HowTo version pin against the resolved package versions.
//
//   dart run tool/ai_preflight.dart
//
// Exit code 0 = all pins fresh. Non-zero = at least one stale pin.

import 'dart:io';

import 'ai_guide_doc.dart';

const String packageName = 'cell_flow';
const List<String> watchedPackages = ['cell', 'cell_flow', 'cell_tissue'];

Future<void> main(List<String> args) async {
  exitCode = await runPreflight();
}

/// Runs the preflight check from [cwd] (defaults to the current directory).
Future<int> runPreflight({String? cwd}) async {
  final root = cwd ?? Directory.current.path;
  final out = StringBuffer();

  out.writeln('$packageName preflight');

  final resolved = resolveVersions(root);
  out.writeln('  resolved: ${watchedPackages.map((p) => '$p ${resolved[p] ?? 'unknown'}').join(', ')}');

  final blocks = parseAllBlocks('$root${Platform.pathSeparator}lib');

  var stale = 0;
  out.writeln('  pins (from doc comments):');
  final seen = <String>{};
  for (final b in blocks) {
    if (seen.contains(b.key)) continue;
    seen.add(b.key);
    final pinPkg = b.pinPackage.replaceFirst(RegExp(r'^package:'), '');
    if (pinPkg.isEmpty || b.pinVersion.isEmpty) {
      out.writeln('    ${b.key.padRight(24)} MISSING PIN');
      stale++;
      continue;
    }
    final resolvedVersion = resolved[pinPkg];
    final ok = resolvedVersion != null && resolvedVersion == b.pinVersion;
    if (!ok) stale++;
    out.writeln('    ${b.key.padRight(24)} pinned at ${b.pinVersion.padRight(12)} '
        '${ok ? 'OK' : 'STALE (resolved ${resolvedVersion ?? 'unknown'})'}');
  }

  final howToDir = findHowToDir(root);
  out.writeln('  HowTo pins (from guide/HowTo-Mitose-*.md):');
  if (howToDir == null) {
    out.writeln('    guide/ not found — skipped');
  } else {
    final pins = parseHowToPins(howToDir);
    if (pins.isEmpty) {
      out.writeln('    none found — skipped');
    }
    for (final entry in pins.entries) {
      final resolvedVersion = resolved[entry.key];
      final ok = resolvedVersion != null && resolvedVersion == entry.value.version;
      if (!ok) stale++;
      out.writeln('    ${entry.key.padRight(12)} verified against ${entry.value.version.padRight(12)} '
          '${ok ? 'OK' : 'STALE (resolved ${resolvedVersion ?? 'unknown'})'} '
          '(${entry.value.file})');
    }
  }

  if (stale > 0) {
    out.writeln();
    out.writeln('FAIL: $stale pin(s) stale. Review the owning doc comment / HowTo '
        'against the resolved versions, then update the pins.');
    stdout.write(out.toString());
    return 1;
  }

  out.writeln();
  out.writeln('OK: all pins fresh.');
  out.writeln();
  out.writeln('--- provenance block for the Demo header -------------------------');
  out.writeln('// Written against: '
      '${watchedPackages.map((p) => '$p ${resolved[p] ?? 'unknown'}').join(', ')} '
      '(${DateTime.now().toIso8601String().substring(0, 10)})');
  out.writeln('// Preflight: dart run tool/ai_preflight.dart -> exit 0');
  out.writeln('------------------------------------------------------------------');
  stdout.write(out.toString());
  return 0;
}

/// Resolves the versions of [watchedPackages] (see package:cell's tool for
/// the canonical implementation — this copy is package-local per the plan).
Map<String, String> resolveVersions(String root) {
  final result = <String, String>{};

  var dir = Directory(root);
  while (true) {
    final lock = File('${dir.path}${Platform.pathSeparator}pubspec.lock');
    if (lock.existsSync()) {
      final parsed = parseLockVersions(lock.readAsStringSync());
      for (final p in watchedPackages) {
        if (parsed.containsKey(p)) result[p] = parsed[p]!;
      }
      if (watchedPackages.every(result.containsKey)) return result;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }

  final parent = Directory(root).parent;
  if (parent.existsSync()) {
    for (final entity in parent.listSync()) {
      if (entity is Directory) {
        final pubspec = File('${entity.path}${Platform.pathSeparator}pubspec.yaml');
        if (pubspec.existsSync()) {
          final content = pubspec.readAsStringSync();
          final name = pubspecName(content);
          if (name != null && watchedPackages.contains(name) && !result.containsKey(name)) {
            result[name] = pubspecVersion(content) ?? 'unknown';
          }
        }
      }
    }
  }

  final own = File('$root${Platform.pathSeparator}pubspec.yaml');
  if (own.existsSync() && !result.containsKey(packageName)) {
    result[packageName] = pubspecVersion(own.readAsStringSync()) ?? 'unknown';
  }
  return result;
}

Map<String, String> parseLockVersions(String lock) {
  final result = <String, String>{};
  final lines = lock.split('\n');
  var current = '';
  for (final line in lines) {
    if (RegExp(r'^  [A-Za-z_][A-Za-z0-9_]*:$').hasMatch(line)) {
      current = line.trim().substring(0, line.trim().length - 1);
    } else if (current.isNotEmpty &&
        line.trim().startsWith('version:') &&
        !result.containsKey(current)) {
      final v = line.trim().substring('version:'.length).trim();
      result[current] = v.replaceAll('"', '').replaceAll("'", '');
      current = '';
    }
  }
  return result;
}

String? pubspecName(String content) {
  return RegExp(r'^name:\s*([A-Za-z_][A-Za-z0-9_]*)\s*$', multiLine: true)
      .firstMatch(content)
      ?.group(1);
}

String? pubspecVersion(String content) {
  return RegExp(r'^version:\s*([^\s#]+)', multiLine: true)
      .firstMatch(content)
      ?.group(1);
}

Directory? findHowToDir(String root) {
  var dir = Directory(root);
  while (true) {
    final candidate = Directory('${dir.path}${Platform.pathSeparator}guide');
    if (candidate.existsSync() &&
        candidate
            .listSync()
            .any((e) => e.path.contains('HowTo-Mitose-Cell.md'))) {
      return candidate;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

class HowToPin {
  HowToPin(this.version, this.file);
  final String version;
  final String file;
}

Map<String, HowToPin> parseHowToPins(Directory howToDir) {
  final result = <String, HowToPin>{};
  for (final entity in howToDir.listSync()) {
    if (entity is! File || !entity.path.contains('HowTo-Mitose-')) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.endsWith('.md')) continue;
    final content = entity.readAsStringSync();
    final section = RegExp(
      r'^\*\*Verified against \(version pin\):\*\*\s*$',
      multiLine: true,
    ).firstMatch(content);
    if (section == null) continue;
    final end = content.indexOf('\n\n', section.end);
    final block = content.substring(
        section.end, end == -1 ? content.length : end);
    for (final line in block.split('\n')) {
      final m = RegExp(r'^\s*-\s*`package:([A-Za-z_][A-Za-z0-9_]*)`\s*—\s*`([^`]+)`')
          .firstMatch(line);
      if (m != null) {
        result[m.group(1)!] = HowToPin(m.group(2)!, name);
      }
    }
  }
  return result;
}
