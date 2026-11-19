// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Markdown-to-AST parsing for BRDs (`flutter-pipeline/v1`).
///
/// The parser assumes the input has passed [validateBrd] — parsing an
/// invalid BRD produces undefined behavior. The CLI uses
/// [validateAndParseBrd] for the single safe entry point.
library;

import 'ast.dart';
import 'schema.dart';

/// Parses a validated BRD Markdown string into a [Brd] AST.
Brd parseBrd(String markdown) {
  final normalized = markdown.replaceAll('\r\n', '\n');
  final frontmatter = _parseFrontmatter(normalized);
  final sections = _splitSections(normalized);

  final requirements = _parseRequirements(sections);
  final screens = _parseScreens(sections);
  final forms = _parseForms(sections);
  final state = _parseState(sections);
  final context = sections['## Context'];

  return Brd(
    title: frontmatter['title']!,
    schemaVersion: frontmatter['schema']!,
    requirements: requirements,
    screens: screens,
    forms: forms,
    state: state,
    context: context,
  );
}

/// Validates [markdown] against `flutter-pipeline/v1`, then parses it.
///
/// Throws [SchemaValidationFailure] (aggregating every error) when the
/// BRD is not well-formed.
Brd validateAndParseBrd(String markdown, {required String sourcePath}) {
  validateBrd(markdown, sourcePath: sourcePath);
  return parseBrd(markdown);
}

Map<String, String> _parseFrontmatter(String markdown) {
  final match =
      RegExp(r'^---\n(.*?)\n---\n', dotAll: true).firstMatch(markdown);
  final result = <String, String>{};
  if (match == null) return result;
  for (final line in match.group(1)!.split('\n')) {
    final separator = line.indexOf(':');
    if (separator > 0) {
      result[line.substring(0, separator).trim()] =
          line.substring(separator + 1).trim();
    }
  }
  return result;
}

/// Splits the body into `## Heading` → body (first line trimmed).
Map<String, String> _splitSections(String markdown) {
  final sections = <String, String>{};
  final body =
      markdown.replaceFirst(RegExp(r'^---\n.*?\n---\n', dotAll: true), '');
  final parts = body.split(RegExp(r'(?=^## )', multiLine: true));
  for (final part in parts) {
    if (part.trim().isEmpty) continue;
    final lines = part.split('\n');
    final heading = lines.first.trim();
    final content = lines.skip(1).join('\n').trim();
    sections[heading] = content;
  }
  return sections;
}

List<List<String>> _parseTable(String content) {
  final lines = content
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.startsWith('|') && !l.contains('---'))
      .toList();
  if (lines.isEmpty) return [];
  return lines
      .map((line) => line
          .split('|')
          .skip(1)
          .take(line.split('|').length - 2)
          .map((c) => c.trim())
          .toList())
      .skip(1) // header row
      .toList();
}

List<BrdRequirement> _parseRequirements(Map<String, String> sections) {
  final rows = _parseTable(sections['## Requirements'] ?? '');
  return [
    for (final r in rows)
      BrdRequirement(
        id: r[0],
        sentence: r[1],
        screen: r[2],
        trigger: r[3].isEmpty ? null : r[3],
        outcome: r[4],
        type: RequirementType.tryParse(r[5]) ?? RequirementType.display,
      ),
  ];
}

List<BrdScreen> _parseScreens(Map<String, String> sections) {
  final rows = _parseTable(sections['## Screens'] ?? '');
  return [
    for (final r in rows)
      BrdScreen(
        name: r[0],
        route: r[1],
        widgets: r[2]
            .split(',')
            .map((w) => w.trim())
            .where((w) => w.isNotEmpty)
            .toList(),
      ),
  ];
}

List<BrdForm> _parseForms(Map<String, String> sections) {
  final rows = _parseTable(sections['## Forms'] ?? '');
  return [
    for (final r in rows)
      BrdForm(
        name: r[0],
        fields: r[1]
            .split(',')
            .map((f) => f.trim())
            .where((f) => f.isNotEmpty)
            .toList(),
        validator: r.length > 2 && r[2].isNotEmpty ? r[2] : null,
      ),
  ];
}

List<BrdState> _parseState(Map<String, String> sections) {
  final rows = _parseTable(sections['## State'] ?? '');
  return [
    for (final r in rows)
      BrdState(
        name: r[0],
        type: r[1],
        initial: r[2].isEmpty ? null : r[2],
        restorable: r[3] == 'yes',
        appLevel: r[4] == 'yes',
      ),
  ];
}
