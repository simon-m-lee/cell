// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Mirrors CONTRIBUTING-AI-DOC.md: the AI-facing decision matrix is
// generated from the `### AI Agent Guide` blocks and cannot drift.

import 'dart:io';

import 'package:test/test.dart';

import '../tool/ai_guide_doc.dart';
import '../tool/generate_api_chooser.dart';

void main() {
  test('lib/doc/api_chooser.dart is generated and up to date', () {
    final blocks = parseAllBlocks('lib');
    expect(blocks, isNotEmpty, reason: 'No AI Agent Guide blocks in lib/');
    final expected = generateApiChooser(blocks);
    final file = File('lib/doc/api_chooser.dart');
    expect(file.existsSync(), isTrue, reason: 'api_chooser.dart missing');
    expect(file.readAsStringSync(), expected,
        reason: 'Run: dart run tool/generate_api_chooser.dart');
  });

  test('skill references/api_chooser.md is generated and up to date', () {
    final blocks = parseAllBlocks('lib');
    final expected = generateApiChooserMarkdown(blocks);
    final file = File(skillApiChooserPath);
    expect(file.existsSync(), isTrue, reason: 'skill api_chooser.md missing');
    expect(file.readAsStringSync(), expected,
        reason: 'Run: dart run tool/generate_api_chooser.dart');
  });

  test('package skill has the install line and the elevator matrix', () {
    final skill = File('skills/cell-skin/SKILL.md').readAsStringSync();
    expect(skill, contains('dart run skills@ get cell_skin'));
    expect(skill, contains('## BRD sentence'));
    expect(skill, contains('references/api_chooser.md'));
    expect(skill, isNot(contains('userAgent')));
  });

  test('every parsed block is pinned at cell_skin: 1.0.0', () {
    final blocks = parseAllBlocks('lib');
    expect(blocks, isNotEmpty);
    for (final block in blocks) {
      expect(block.pinPackage, 'cell_skin',
          reason: '${block.file}:${block.line} ${block.key}');
      expect(block.pinVersion, '1.0.0',
          reason: '${block.file}:${block.line} ${block.key}');
    }
  });
}
