// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Phase 3.1 of CONTRIBUTING-AI-DOC.md: every `Minimal compilable
// example` in the `### AI Agent Guide` doc blocks must compile under
// `dart analyze`, run, and exit 0.

import 'dart:io';

import 'package:test/test.dart';

import '../tool/ai_guide_doc.dart';
import '../tool/generate_ai_examples.dart';

void main() {
  const generated =
      'test/ai_guide_examples/ai_guide_examples.generated.dart';

  test('generated AI guide example file is up to date', () {
    final blocks = parseAllBlocks('lib');
    expect(blocks, isNotEmpty, reason: 'No AI Agent Guide blocks in lib/');
    final expected = generateExamples(blocks);
    final file = File(generated);
    expect(file.existsSync(), isTrue, reason: 'Generated file missing');
    expect(file.readAsStringSync(), expected,
        reason: 'Run: dart run tool/generate_ai_examples.dart');
  });

  test('every minimal example compiles under dart analyze', () async {
    final result = await Process.run('dart', ['analyze', generated]);
    expect(result.exitCode, 0,
        reason: 'dart analyze failed:\n${result.stdout}\n${result.stderr}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('every minimal example runs and exits 0', () async {
    final result = await Process.run('dart', ['run', generated]);
    expect(result.exitCode, 0,
        reason: 'example run failed:\n${result.stdout}\n${result.stderr}');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
