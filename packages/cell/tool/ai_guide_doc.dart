// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Shared parser for the `### AI Agent Guide` doc-comment convention.
// Used by tool/ai_preflight.dart, tool/generate_ai_examples.dart and
// tool/generate_api_chooser.dart. Convention: CONTRIBUTING-AI-DOC.md.

import 'dart:io';

/// One parsed `### AI Agent Guide` block.
class AiGuideBlock {
  AiGuideBlock({
    required this.key,
    required this.layer,
    required this.whenToUse,
    required this.whenNotToUse,
    required this.liveSignature,
    required this.pinPackage,
    required this.pinVersion,
    required this.confuseWith,
    required this.guide,
    required this.example,
    required this.crossLayer,
    required this.stability,
    required this.snippet,
    required this.file,
    required this.line,
  });

  final String key;
  final String layer;
  final String whenToUse;
  final String whenNotToUse;
  final String liveSignature;
  final String pinPackage;
  final String pinVersion;
  final String confuseWith;
  final String guide;
  final String example;
  final String crossLayer;
  final String stability;
  final String snippet;
  final String file;
  final int line;
}

final _docPrefix = RegExp(r'^\s*/// ?');

String? _stripDocPrefix(String line) {
  if (!line.trimLeft().startsWith('///')) return null;
  return line.replaceFirst(_docPrefix, '');
}

bool _isFieldLine(String line) =>
    line.startsWith('**Layer:**') ||
    line.startsWith('**When to use:**') ||
    line.startsWith('**When NOT to use:**') ||
    line.startsWith('**Live signature:**') ||
    line.startsWith('**Do NOT confuse with:**') ||
    line.startsWith('**Guide:**') ||
    line.startsWith('**Example:**') ||
    line.startsWith('**Cross-layer:**') ||
    line.startsWith('**Stability:**') ||
    line.startsWith('**Self-verification') ||
    line.startsWith('**Minimal compilable example**');

/// Derives the stable symbol key from the `Live signature:` line.
String deriveKey(String liveSignature) {
  final m = RegExp(r'`([^`]+)`').firstMatch(liveSignature);
  final rawSig = m?.group(1)?.trim() ?? '';
  // Remember whether a stripped generic mentioned Cell (used for
  // `FutureOr<Cell> deputy(...)` -> `Cell.deputy`).
  final genericMentionedCell =
      RegExp(r'<[^>]*\bCell\b[^>]*>').hasMatch(rawSig);
  var sig = rawSig;
  // Strip balanced generics.
  while (true) {
    final cleaned = sig.replaceFirst(RegExp(r'<[^<>]*>'), '');
    if (cleaned == sig) break;
    sig = cleaned;
  }
  // Keep everything before the first '(' or '='.
  sig = sig.split(RegExp(r'[\(=]')).first.trim();
  final tokens = sig.split(RegExp(r'\s+'));
  // `Cell get unmodifiable` -> Cell.unmodifiable
  if (tokens.contains('get')) {
    final idx = tokens.indexOf('get');
    if (idx > 0 && idx + 1 < tokens.length) {
      return '${tokens[idx - 1]}.${tokens[idx + 1]}';
    }
  }
  // `class X extends FlowInstructionBase<...>` -> FlowInstructionBase
  if (tokens.contains('extends')) {
    final idx = tokens.indexOf('extends');
    if (idx + 1 < tokens.length) return tokens[idx + 1];
  }
  // Skip declaration modifiers.
  const modifiers = {
    'abstract',
    'interface',
    'class',
    'typedef',
    'static',
    'factory',
    'const',
    'final',
  };
  var name = tokens.lastWhere(
    (t) => RegExp(r'^[A-Za-z_][A-Za-z0-9_.]*$').hasMatch(t) &&
        !modifiers.contains(t) &&
        t != 'extends' &&
        t != 'get',
    orElse: () => tokens.isNotEmpty ? tokens.last : 'unknown',
  );
  // `FutureOr<Cell> deputy(...)` -> Cell.deputy
  if (genericMentionedCell && RegExp(r'^[a-z]').hasMatch(name)) {
    name = 'Cell.$name';
  }
  return name;
}

/// Parses every `### AI Agent Guide` block in [source].
List<AiGuideBlock> parseAiGuideBlocks(String source,
    {required String file}) {
  final lines = source.split('\n');
  final blocks = <AiGuideBlock>[];
  var i = 0;
  while (i < lines.length) {
    final doc = _stripDocPrefix(lines[i]);
    if (doc != null && doc.trim().startsWith('### AI Agent Guide')) {
      final raw = <String>[];
      var j = i;
      while (j < lines.length && _stripDocPrefix(lines[j]) != null) {
        raw.add(lines[j]);
        j++;
      }
      final cleaned =
          raw.map((l) => _stripDocPrefix(l) ?? '').where((l) => l.isNotEmpty || true).toList();

      var layer = '';
      var whenToUse = '';
      final whenNot = <String>[];
      var live = '';
      var confuse = '';
      var guide = '';
      var example = '';
      var cross = '';
      var stability = '';
      final snippetLines = <String>[];
      var current = '';
      var inSnippet = false;
      var inFence = false;

      for (final line in cleaned) {
        if (line.contains('**Minimal compilable example**')) {
          current = 'snippet';
          inSnippet = true;
          continue;
        }
        if (_isFieldLine(line)) {
          current = line.substring(2, line.indexOf(':', 2)).trim();
          final value = line.substring(line.indexOf(':') + 1).trim();
          switch (current) {
            case 'Layer':
              layer = value;
            case 'When to use':
              whenToUse = value;
            case 'When NOT to use':
              whenNot.clear();
              whenNot.add(value);
            case 'Live signature':
              live = value;
            case 'Do NOT confuse with':
              confuse = value;
            case 'Guide':
              guide = value;
            case 'Example':
              example = value;
            case 'Cross-layer':
              cross = value;
            case 'Stability':
              stability = value;
          }
          continue;
        }
        if (inSnippet) {
          final t = line.trim();
          if (t.startsWith('```dart')) {
            inFence = true;
            continue;
          }
          if (inFence && t.startsWith('```')) break;
          if (inFence) snippetLines.add(line);
          continue;
        }
        if (current == 'When NOT to use' && line.isNotEmpty) {
          whenNot.add(line.trim());
        }
      }

      final pinM = RegExp(r'pinned at `([A-Za-z_][A-Za-z0-9_]*)v?:?\s*:?\s*([^`]+)`')
          .firstMatch(live);
      final key = deriveKey(live);

      // Dedent the snippet by the shortest common indentation.
      var snippet = snippetLines.join('\n');
      final indent = snippetLines
          .where((l) => l.trim().isNotEmpty)
          .map((l) => l.length - l.trimLeft().length)
          .fold<int>(1 << 30, (a, b) => a < b ? a : b);
      if (indent > 0 && indent < (1 << 30)) {
        snippet = snippetLines
            .map((l) =>
                l.length >= indent ? l.substring(indent) : l.trimLeft())
            .join('\n');
      }

      blocks.add(AiGuideBlock(
        key: key,
        layer: layer,
        whenToUse: whenToUse,
        whenNotToUse: whenNot.join(' ').trim(),
        liveSignature: live,
        pinPackage: pinM?.group(1) ?? '',
        pinVersion: pinM?.group(2)?.trim() ?? '',
        confuseWith: confuse,
        guide: guide,
        example: example,
        crossLayer: cross,
        stability: stability,
        snippet: snippet.trim(),
        file: file,
        line: i + 1,
      ));
      i = j;
      continue;
    }
    i++;
  }
  return blocks;
}

/// Parses all guide blocks in every `.dart` file under [dir] (recursive).
List<AiGuideBlock> parseAllBlocks(String dir) {
  final blocks = <AiGuideBlock>[];
  final entities = Directory(dir).listSync(recursive: true);
  final files = entities
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    blocks.addAll(parseAiGuideBlocks(f.readAsStringSync(), file: f.path));
  }
  return blocks;
}
