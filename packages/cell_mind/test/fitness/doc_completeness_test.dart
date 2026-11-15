// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:io';

import 'package:test/test.dart';

/// Phase 7 doc audit gate: every public type and function in
/// `lib/src` must carry a doc block with the style-guide sections,
/// category tags, and the v1.0 stability note.
void main() {
  final files = Directory('lib/src')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('every public declaration has a complete doc block', () {
    final failures = <String>[];
    for (final file in files) {
      final lines =
          file.readAsStringSync().replaceAll('\r\n', '\n').split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        final isClass = RegExp(
          r'^(?:(?:abstract|final|sealed|base|interface|mixin)\s+)*'
          r'(?:class|enum|typedef)\s+([A-Za-z][A-Za-z0-9_]*)'
          r'(?:<[^;{]*>)?(?:$|\s*[;{=])',
        ).firstMatch(line);
        final isFn = RegExp(
          r'^[A-Za-z][A-Za-z0-9_<>, ?{}]*(?:<[^;()]*>)?\s+'
          r'([A-Za-z][A-Za-z0-9_]*)\s*\(',
        ).firstMatch(line);
        final name = isClass?.group(1) ?? isFn?.group(1);
        if (name == null || name.startsWith('_')) continue;
        if (isFn != null && !line.startsWith('Future<')) {
          // Only top-level function-style declarations at column 0.
          if (line != lines[i].trimLeft() || lines[i].startsWith(' ')) {
            continue;
          }
        }
        // Skip declarations inside method bodies (indented).
        if (lines[i].startsWith(' ') && isClass == null) continue;

        // Collect the contiguous doc block immediately above.
        var j = i - 1;
        while (j >= 0 && lines[j].trim().isEmpty) {
          j--;
        }
        final block = <String>[];
        while (j >= 0 && lines[j].trimLeft().startsWith('///')) {
          block.insert(0, lines[j]);
          j--;
        }
        final doc = block.join('\n');
        final checks = <String, String>{
          '### When to use': 'when-to-use section',
          '### How it works': 'how-it-works section',
          '### Non-obvious': 'non-obvious section',
          '### See also': 'see-also section',
          'AI Agent Guide': 'AI Agent Guide section',
          '{@category': 'category tag',
          '**Stability:**': 'stability note',
        };
        for (final entry in checks.entries) {
          if (!doc.contains(entry.key)) {
            failures.add(
              '${file.path}: $name missing ${entry.value}',
            );
          }
        }
      }
    }
    expect(failures, isEmpty, reason: failures.take(40).join('\n'));
  });

  test('api_chooser covers every module', () {
    final chooser = File('lib/doc/api_chooser.dart').readAsStringSync();
    for (final module in [
      'Policy',
      'CognitiveHandle',
      'trainOffline',
      'ApprovalQueue',
      'completion',
      'toolRouter',
      'DecisionPath',
      'spawn',
      'debate',
      'promptedPolicy',
      'PromptConfig',
      'conform',
    ]) {
      expect(chooser, contains(module));
    }
  });

  test('FROZEN_API.md mentions every public module file', () {
    final manifest = File('FROZEN_API.md').readAsStringSync();
    for (final file in [
      'policy.dart',
      'runtime.dart',
      'learning.dart',
      'approval.dart',
      'bridge.dart',
      'xai.dart',
      'agent.dart',
      'outcomes.dart',
      'prompt_policy.dart',
      'prompt_config.dart',
    ]) {
      expect(manifest, contains(file));
    }
  });
}
