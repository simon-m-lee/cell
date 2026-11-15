// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:io';

/// Generates `FROZEN_API.md` — the semver contract for the `1.x` series.
///
/// Static, dependency-free scan over `lib/src/*.dart`: public
/// top-level declarations and their public member signatures are
/// listed so a future PR can diff against the frozen state.
///
/// The header is **deterministic** (the version and freeze date are
/// fixed constants) so CI can diff a fresh generation against the
/// committed manifest without timestamp noise. Bump the constants when
/// cutting a new frozen manifest.
///
/// Usage:
/// ```bash
/// dart tool/freeze_api.dart > FROZEN_API.md
/// ```
Future<void> main() async {
  const frozenVersion = '1.1.0';
  const frozenDate = '2026-11-15';
  final files = Directory('lib/src')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final buffer = StringBuffer()
    ..writeln('# Cell Mind — Frozen API (v$frozenVersion)')
    ..writeln()
    ..writeln('Frozen on: $frozenDate')
    ..writeln('Frozen by: cell_mind $frozenVersion tag')
    ..writeln('Generator: tool/freeze_api.dart')
    ..writeln()
    ..writeln('Any change to this manifest requires a deprecation cycle '
        'or a MAJOR version bump.')
    ..writeln();

  for (final file in files) {
    final stripped = _strip(file.readAsStringSync());
    final entries = _scan(stripped);
    if (entries.isEmpty) continue;
    buffer
      ..writeln('## ${file.path}')
      ..writeln();
    for (final entry in entries) {
      buffer
        ..writeln(entry)
        ..writeln();
    }
  }
  stdout.write(buffer.toString());
}

String _strip(String source) {
  var out = source.replaceAll(RegExp(r'\/\*[\s\S]*?\*\/'), '');
  out = out.replaceAll(RegExp(r'\/\/.*', multiLine: true), '');
  return out;
}

final _typeDecl = RegExp(
  r'^(?:(?:abstract|final|sealed|base|interface|mixin)\s+)*'
  r'(?:class|enum|typedef)\s+([A-Za-z][A-Za-z0-9_]*|<[A-Za-z][A-Za-z0-9_, <>]*>'
  r'\s+[A-Za-z][A-Za-z0-9_]*)',
  multiLine: true,
);

List<String> _scan(String source) {
  final entries = <String>[];
  for (final match in _typeDecl.allMatches(source)) {
    final raw = match.group(1)!;
    final name = RegExp(r'[A-Za-z][A-Za-z0-9_]*$').firstMatch(raw)!.group(0)!;
    if (name.startsWith('_')) continue;
    final after = source.substring(match.end);
    final kind = match.group(0)!.contains('enum')
        ? 'enum'
        : match.group(0)!.contains('typedef')
            ? 'typedef'
            : 'class';
    if (kind == 'typedef') {
      entries.add('### $name (typedef)');
      final sig = after.split(';').first.trim();
      entries.add('- `$sig`');
      continue;
    }
    final body = _body(after);
    if (body == null) continue;
    final members = _members(body, typeName: name);
    final buffer = StringBuffer()
      ..writeln('### $name${kind == 'enum' ? ' (enum)' : ''}');
    if (kind == 'enum') {
      final values = RegExp(r'^([a-zA-Z][a-zA-Z0-9_]*)[,}]', multiLine: true)
          .allMatches(body)
          .map((m) => m.group(1))
          .whereType<String>();
      buffer.writeln(values.map((v) => '- `$v`').join('\n'));
    } else if (members.isEmpty) {
      buffer.writeln('- (sealed hierarchy — no public members)');
    } else {
      buffer.writeln(members.join('\n'));
    }
    entries.add(buffer.toString().trimRight());
  }

  // Public top-level functions.
  final fn = RegExp(
    r'^([A-Za-z][A-Za-z0-9_<>, ?{}]*(?:<[^;()]*>)?)\s+'
    r'([A-Za-z][A-Za-z0-9_]*)\s*(?=\()',
    multiLine: true,
  );
  for (final match in fn.allMatches(source)) {
    final name = match.group(2)!;
    if (name.startsWith('_') || name == 'Function') continue;
    final after = source.substring(match.end);
    final params = _paren(after);
    final line = '### $name (function)\n- `${match.group(1)} $name($params)`';
    if (!entries.any((e) => e.contains(line))) {
      entries.add(line);
    }
  }
  return entries;
}

String? _body(String source) {
  final open = source.indexOf('{');
  if (open < 0) return null;
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  return null;
}

String _paren(String source) {
  var depth = 0;
  final buffer = StringBuffer();
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    buffer.write(c);
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return buffer.toString();
    }
  }
  return buffer.toString();
}

final _member = RegExp(
  r'^([A-Za-z][A-Za-z0-9_<>, ?()\[\]]*)\s+'
  r'([A-Za-z][A-Za-z0-9_]*)\s*(\([^)]*\))?\s*(=>)?\s*[;{]?',
);

List<String> _members(String body, {String? typeName}) {
  final out = <String>[];
  final lines = body.split('\n').map((l) => l.trim());
  var depth = 0;
  for (final line in lines) {
    if (line.isEmpty || line.startsWith('_') || line.startsWith('@')) {
      continue;
    }
    final opens = '{'.allMatches(line).length;
    final closes = '}'.allMatches(line).length;
    final inScope = depth == 0;
    depth += opens - closes;
    if (!inScope) continue;
    if (line.contains(' _') && line.contains('final ')) continue; // private
    // Constructors: `Name(...)`.
    if (typeName != null && line.startsWith('$typeName(')) {
      out.add('- `$line`');
      continue;
    }
    // Public final fields.
    if (line.startsWith('final ')) {
      final clean = line.split('{').first.trim();
      out.add('- `$clean`');
      continue;
    }
    final match = _member.firstMatch(line);
    if (match == null || match.group(0)!.length < line.length) continue;
    final keyword = match.group(1)!;
    final rest = match.group(0)!;
    if (RegExp(r'^(if|for|while|return|switch|throw|assert|const|late|var|'
            r'void|this|super|case|break|try|catch|new|static|required)\b')
        .hasMatch(keyword)) {
      continue;
    }
    // Only keep declaration-shaped lines.
    if (!rest.contains('(') && !rest.endsWith(';') && !rest.endsWith('{')) {
      continue;
    }
    out.add('- `$line`');
  }
  return out;
}
