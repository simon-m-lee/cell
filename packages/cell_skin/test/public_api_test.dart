// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The FEATURES-Skin.md machine lists are the freeze, checked against
/// the real export namespaces (package:analyzer walks the barrels, not
/// a regex over declaration lines) and against every guided block's
/// stability field.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:test/test.dart';

import '../tool/ai_guide_doc.dart';

const List<String> _barrels = [
  'lib/cell_skin.dart',
  'lib/cell_skin_rest.dart',
  'lib/cell_skin_io.dart',
];

void main() {
  late Map<String, Set<String>> lists;
  late Set<String> exported;

  setUpAll(() async {
    lists = _readLists();
    exported = await _exportedNames();
  });

  test('every exported name is in exactly one list', () {
    for (final name in exported) {
      final inStable = lists['stable']!.contains(name);
      final inExperimental = lists['experimental']!.contains(name);
      expect(inStable ^ inExperimental, isTrue,
          reason: '$name must be in exactly one list '
              '(stable=$inStable, experimental=$inExperimental)');
    }
  });

  test('no list names a symbol the barrels do not export', () {
    for (final entry in lists.entries) {
      for (final name in entry.value) {
        expect(exported, contains(name),
            reason: '${entry.key} names $name, which is not exported');
      }
    }
  });

  test('the lists are sorted and overlap-free', () {
    for (final entry in lists.entries) {
      final sorted = entry.value.toList()..sort();
      expect(entry.value.toList(), sorted,
          reason: '${entry.key} list is not sorted');
    }
    expect(
      lists['stable']!.intersection(lists['experimental']!),
      isEmpty,
      reason: 'a name in both lists is a bug',
    );
  });

  test('every parsed guide block is pinned at cell_skin: 1.0.0', () {
    final blocks = parseAllBlocks('lib');
    expect(blocks, isNotEmpty);
    for (final block in blocks) {
      expect(block.pinPackage, 'cell_skin',
          reason: '${block.file}:${block.line} ${block.key}');
      expect(block.pinVersion, '1.0.0',
          reason: '${block.file}:${block.line} ${block.key}');
      expect(block.stability, isNotEmpty,
          reason: '${block.file}:${block.line} ${block.key} '
              'has no **Stability:** field');
    }
  });

  test('every guided block stability matches its catalog list', () {
    final blocks = parseAllBlocks('lib');
    for (final block in blocks) {
      final key = block.key;
      if (key.isEmpty || key.contains('.')) continue;
      final bare = key.split(';').first.trim();
      // The parser stores field values with the bold markers still
      // attached (`** stable`), so compare the bare word.
      final stability =
          block.stability.replaceAll(RegExp(r'[\*\s]'), '').trim();
      final stable = lists['stable']!.contains(bare);
      final experimental = lists['experimental']!.contains(bare);
      if (stable) {
        expect(stability, 'stable', reason: '$key is in the stable list');
      } else if (experimental) {
        expect(stability, 'experimental',
            reason: '$key is in the experimental list');
      }
    }
  });

  test('FEATURES-Skin.md §3 names every golden error code', () {
    final features = File('FEATURES-Skin.md').readAsStringSync();
    final goldenDir = Directory('test/goldens/wire/errors');
    for (final entity in goldenDir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final code = entity.uri.pathSegments.last.replaceAll('.json', '');
      expect(features, contains(code),
          reason: '§3 of FEATURES-Skin.md must name the golden code $code');
    }
  });

  test('the migration guide carries the three rc sentences', () {
    final guide = File('guide/HowTo-Migrate-0.2.md').readAsStringSync();
    expect(guide,
        contains('Open a `FileIdempotencyStore` when a retry must survive a restart.'));
    expect(guide,
        contains('Point readiness probes at `GET /ready`. `/health` stays liveness.'));
    expect(guide,
        contains('Set `maxQueued` when a client can flood the process.'));
  });
}

Map<String, Set<String>> _readLists() {
  final lines = File('FEATURES-Skin.md').readAsLinesSync();
  String? current;
  final result = {'stable': <String>{}, 'experimental': <String>{}};
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line == '<!-- public-api:stable -->') {
      current = 'stable';
      continue;
    }
    if (line == '<!-- public-api:experimental -->') {
      current = 'experimental';
      continue;
    }
    if (current != null && line.startsWith('```')) {
      if (line == '```' && i > 0 && lines[i - 1].trim() != '```text') {
        current = null;
      }
      continue;
    }
    if (current != null && line.isNotEmpty && !line.startsWith('```')) {
      result[current]!.add(line);
    }
  }
  return result;
}

Future<Set<String>> _exportedNames() async {
  final paths = [
    for (final barrel in _barrels)
      File(barrel).absolute.path.replaceAll('/', '\\')
  ];
  final collection = AnalysisContextCollection(includedPaths: paths);
  final names = <String>{};
  for (final path in paths) {
    final session = collection.contextFor(path).currentSession;
    final result = await session.getResolvedUnit(path);
    if (result is! ResolvedUnitResult) {
      throw StateError('no resolved unit for $path: $result');
    }
    final library = result.unit.declaredElement!.library;
    names.addAll(library.exportNamespace.definedNames.keys);
  }
  return names;
}
