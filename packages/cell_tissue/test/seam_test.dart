// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Phase 3.2 of CONTRIBUTING-AI-DOC.md (package:cell_tissue variant):
// the same grep seam rule that fails a Mitose run also fails this
// package's own CI.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('no testRule: TestCell on any Tissue constructor in example/', () {
    final dir = Directory('example');
    final violations = dir.existsSync()
        ? dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .expand((f) => f.readAsLinesSync())
            .where((line) =>
                line.split('//').first.contains('Tissue') && line.split('//').first.contains('testRule: TestCell'))
            .toList()
        : const <String>[];
    expect(violations, isEmpty,
        reason: 'Use TestTissue on Tissue books. '
            'See HowTo-Mitose-Tissue.md §1 and §9.');
  });

  test('no testRule: TestTissue on a Cell factory in example/', () {
    final dir = Directory('example');
    final violations = dir.existsSync()
        ? dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .expand((f) => f.readAsLinesSync())
            .where((line) =>
                line.contains('Cell.ingress') &&
                    line.contains('testRule: TestTissue') ||
                line.split('//').first.contains('Cell.state') &&
                    line.split('//').first.contains('testRule: TestTissue'))
            .toList()
        : const <String>[];
    expect(violations, isEmpty,
        reason: 'Use TestCell on Cell factories. '
            'See HowTo-Mitose-Cell.md §3.1.');
  });
}
