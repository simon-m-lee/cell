// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Phase 6.2 of CONTRIBUTING-AI-DOC.md: the AI-facing decision matrix is
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
}
