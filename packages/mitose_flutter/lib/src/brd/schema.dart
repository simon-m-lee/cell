// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The BRD schema validator (`flutter-pipeline/v1`).
///
/// Validates a BRD Markdown string against the contract in
/// `docs/brd-schema.md` / `docs/brd-schema.json`. Every violation is
/// collected into one [SchemaValidationFailure]; nothing is guessed.
library;

import '../failures.dart';

const schemaVersionV1 = 'flutter-pipeline/v1';

/// The fixed column sets per section (v1).
const Map<String, List<String>> fixedColumnSets = {
  '## Requirements': ['ID', 'Sentence', 'Screen', 'Trigger', 'Outcome', 'Type'],
  '## Screens': ['Name', 'Route', 'Widgets'],
  '## Forms': ['Name', 'Fields', 'Validator'],
  '## State': ['Name', 'Type', 'Initial', 'Restorable', 'AppLevel'],
};

/// Validates [markdown] against `flutter-pipeline/v1`.
///
/// Throws [SchemaValidationFailure] when invalid; does nothing when
/// the BRD is well-formed.
void validateBrd(String markdown, {required String sourcePath}) {
  final errors = _collectErrors(markdown, sourcePath);
  if (errors.isNotEmpty) {
    throw SchemaValidationFailure(sourcePath: sourcePath, errors: errors);
  }
}

List<SchemaValidationError> _collectErrors(String markdown, String source) {
  final normalized = markdown.replaceAll('\r\n', '\n');
  final errors = <SchemaValidationError>[];

  // --- Frontmatter ---
  final frontmatterMatch =
      RegExp(r'^---\n(.*?)\n---\n', dotAll: true).firstMatch(normalized);
  final frontmatter = <String, String>{};
  if (frontmatterMatch == null) {
    errors.add(const SchemaValidationError(
      subtype: 'MissingFrontmatter',
      location: 'line 1',
      field: null,
      reason: 'missing the required frontmatter block.',
      fix: 'Add a YAML frontmatter block with `schema: flutter-pipeline/v1`, '
          '`title: <name>`, and `version: 1` at the top of the file.',
    ));
  } else {
    for (final line in frontmatterMatch.group(1)!.split('\n')) {
      final separator = line.indexOf(':');
      if (separator > 0) {
        frontmatter[line.substring(0, separator).trim()] =
            line.substring(separator + 1).trim();
      }
    }
    final version = frontmatter['schema'];
    if (version == null) {
      errors.add(const SchemaValidationError(
        subtype: 'MissingField',
        location: 'frontmatter',
        field: 'schema',
        reason: 'missing required field "schema".',
        fix: 'Add `schema: flutter-pipeline/v1` to the frontmatter.',
      ));
    } else if (version != schemaVersionV1) {
      errors.add(SchemaValidationError(
        subtype: 'UnknownSchemaVersion',
        location: 'frontmatter',
        field: 'schema',
        reason: 'schema version "$version" is not supported; this pipeline '
            'supports "flutter-pipeline/v1".',
        fix: 'Change the schema version to `flutter-pipeline/v1`, or upgrade '
            'the pipeline to a version that supports "$version".',
      ));
    }
    if ((frontmatter['title'] ?? '').isEmpty) {
      errors.add(const SchemaValidationError(
        subtype: 'MissingField',
        location: 'frontmatter',
        field: 'title',
        reason: 'missing required field "title".',
        fix: 'Add `title: <name>` to the frontmatter.',
      ));
    }
    final versionValue = frontmatter['version'];
    if (versionValue == null || versionValue.isEmpty) {
      errors.add(const SchemaValidationError(
        subtype: 'MissingField',
        location: 'frontmatter',
        field: 'version',
        reason: 'missing required field "version".',
        fix: 'Add `version: 1` to the frontmatter.',
      ));
    } else if (versionValue != '1') {
      errors.add(const SchemaValidationError(
        subtype: 'InvalidType',
        location: 'frontmatter',
        field: 'version',
        reason: 'version must be "1" in flutter-pipeline/v1.',
        fix: 'Set `version: 1` in the frontmatter.',
      ));
    }
  }

  // --- Sections ---
  final body =
      normalized.replaceFirst(RegExp(r'^---\n.*?\n---\n', dotAll: true), '');
  final sections = _splitSections(body);
  for (final required in ['## Requirements', '## Screens', '## State']) {
    if (!sections.containsKey(required)) {
      errors.add(SchemaValidationError(
        subtype: 'MissingSection',
        location: '(section)',
        field: null,
        reason: 'missing the required section `$required`.',
        fix: 'Add a `$required` section with the table described in '
            'docs/brd-schema.md.',
      ));
    }
  }

  // --- Table shapes ---
  for (final entry in fixedColumnSets.entries) {
    final content = sections[entry.key];
    if (content == null) continue; // optional sections handled above
    final header = _tableHeader(content);
    if (header == null) {
      errors.add(SchemaValidationError(
        subtype: 'MalformedTable',
        location: entry.key,
        field: null,
        reason: 'the section has no parseable table.',
        fix: 'Restore the fixed column set `${entry.value.join(" | ")}`.',
      ));
    } else if (!_sameList(header, entry.value)) {
      errors.add(SchemaValidationError(
        subtype: 'MalformedTable',
        location: entry.key,
        field: null,
        reason: 'expected the fixed column set '
            '`${entry.value.join(" | ")}` but the table has '
            '${header.join(" | ")}.',
        fix: 'Restore the fixed column set '
            '`${entry.value.join(" | ")}`; extra columns are not allowed '
            'in flutter-pipeline/v1.',
      ));
    }
  }

  // --- Row-level checks ---
  final requirements = _rows(sections['## Requirements'] ?? '');
  final screens = _rows(sections['## Screens'] ?? '');
  final forms = _rows(sections['## Forms'] ?? '');
  final state = _rows(sections['## State'] ?? '');

  final reqIds = <String>[];
  for (var i = 0; i < requirements.length; i++) {
    final r = requirements[i];
    final location = '## Requirements, row ${i + 1}';
    final id = r[0];
    if (!RegExp(r'^REQ-\d{3,}$').hasMatch(id)) {
      errors.add(SchemaValidationError(
        subtype: 'InvalidType',
        location: location,
        field: 'ID',
        reason: '"$id" is not a legal requirement ID.',
        fix: 'Use an ID of the form `REQ-###` (e.g. `REQ-001`).',
      ));
    }
    if (reqIds.contains(id)) {
      errors.add(SchemaValidationError(
        subtype: 'DuplicateId',
        location: location,
        field: 'ID',
        reason: 'duplicate requirement ID "$id".',
        fix: 'Use a unique ID for each requirement.',
      ));
    }
    reqIds.add(id);
    if (r[1].isEmpty) {
      errors.add(SchemaValidationError(
        subtype: 'MissingField',
        location: location,
        field: 'Sentence',
        reason: 'missing required field "Sentence".',
        fix: 'Provide a sentence for the requirement.',
      ));
    }
    final type = RequirementTypeValues.tryParse(r[5]);
    if (type == null) {
      errors.add(SchemaValidationError(
        subtype: 'InvalidType',
        location: location,
        field: 'Type',
        reason: '"${r[5]}" is not a legal Type value.',
        fix: 'Use one of: display, interaction, recovery, atomic.',
      ));
    }
    final isTriggered = type == 'interaction' || type == 'recovery';
    if (isTriggered && r[3].isEmpty) {
      errors.add(SchemaValidationError(
        subtype: 'MissingField',
        location: location,
        field: 'Trigger',
        reason: 'Type is "${r[5]}" but Trigger is empty.',
        fix: 'Provide a Trigger value (e.g., "tap Sign in"), or change Type '
            'to "display".',
      ));
    }
    if (!screens.any((s) => s[0] == r[2])) {
      errors.add(SchemaValidationError(
        subtype: 'UnresolvedReference',
        location: location,
        field: 'Screen',
        reason: 'screen "${r[2]}" is not in `## Screens`.',
        fix: 'Add "${r[2]}" to `## Screens`, or change the requirement\'s '
            'Screen to an existing screen.',
      ));
    }
  }

  final screenNames = <String>[];
  for (final s in screens) {
    if (screenNames.contains(s[0])) {
      errors.add(SchemaValidationError(
        subtype: 'DuplicateId',
        location: '## Screens',
        field: 'Name',
        reason: 'duplicate screen name "${s[0]}".',
        fix: 'Use a unique name for each screen.',
      ));
    }
    screenNames.add(s[0]);
    if (!s[1].startsWith('/')) {
      errors.add(SchemaValidationError(
        subtype: 'InvalidType',
        location: '## Screens',
        field: 'Route',
        reason: 'route "${s[1]}" does not start with "/".',
        fix: 'Use a route starting with "/" (e.g. "/login").',
      ));
    }
  }

  final stateNames = <String>[];
  for (final st in state) {
    if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(st[0])) {
      errors.add(SchemaValidationError(
        subtype: 'InvalidType',
        location: '## State',
        field: 'Name',
        reason: '"${st[0]}" is not a lowercase-first Dart identifier.',
        fix: 'Use a lowercase-first identifier (e.g. "email").',
      ));
    }
    if (stateNames.contains(st[0])) {
      errors.add(SchemaValidationError(
        subtype: 'DuplicateId',
        location: '## State',
        field: 'Name',
        reason: 'duplicate state name "${st[0]}".',
        fix: 'Use a unique name for each state entry.',
      ));
    }
    stateNames.add(st[0]);
    if (st.length >= fixedColumnSets['## State']!.length) {
      for (final flag in [(st[3]), (st[4])]) {
        if (flag != 'yes' && flag != 'no') {
          errors.add(SchemaValidationError(
            subtype: 'InvalidType',
            location: '## State',
            field: 'Restorable/AppLevel',
            reason: '"$flag" is not a legal yes/no value.',
            fix: 'Use `yes` or `no`.',
          ));
        }
      }
    }
  }

  for (final form in forms) {
    for (final field in form[1].split(',').map((f) => f.trim())) {
      if (field.isEmpty) continue;
      if (!stateNames.contains(field)) {
        errors.add(SchemaValidationError(
          subtype: 'UnresolvedReference',
          location: '## Forms',
          field: 'Fields',
          reason: 'form field "$field" is not in `## State`.',
          fix: 'Add "$field" to `## State`, or remove it from the form.',
        ));
      }
    }
  }

  return errors;
}

Map<String, String> _splitSections(String body) {
  final sections = <String, String>{};
  for (final part in body.split(RegExp(r'(?=^## )', multiLine: true))) {
    if (part.trim().isEmpty) continue;
    final lines = part.split('\n');
    sections[lines.first.trim()] = lines.skip(1).join('\n').trim();
  }
  return sections;
}

List<String>? _tableHeader(String content) {
  final lines = content.split('\n').map((l) => l.trim()).toList();
  if (lines.isEmpty || !lines.first.startsWith('|')) return null;
  final cells = lines.first
      .split('|')
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();
  return cells.isEmpty ? null : cells;
}

List<List<String>> _rows(String content) {
  final lines = content
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.startsWith('|') && !l.contains('---'))
      .toList();
  if (lines.length <= 1) return [];
  return lines.skip(1).map((line) {
    final parts = line.split('|');
    return parts.sublist(1, parts.length - 1).map((c) => c.trim()).toList();
  }).toList();
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Legal `Type` values (kept as strings for validator reuse).
abstract final class RequirementTypeValues {
  static const legal = ['display', 'interaction', 'recovery', 'atomic'];

  static String? tryParse(String value) =>
      legal.contains(value.trim()) ? value.trim() : null;
}
