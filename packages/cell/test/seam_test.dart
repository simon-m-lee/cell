// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Phase 3.2 of CONTRIBUTING-AI-DOC.md: the same grep seam rules that
// fail a Mitose run also fail this package's own CI.

import 'dart:io';

import 'package:test/test.dart';

List<String> exampleLines() {
  final dir = Directory('example');
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .expand((f) => f.readAsLinesSync())
      .toList();
}

void main() {
  test('no testRule: TestCell on any Tissue constructor in example/', () {
    final violations = exampleLines()
        .where((line) =>
            line.split('//').first.contains('Tissue') && line.split('//').first.contains('testRule: TestCell'))
        .toList();
    expect(violations, isEmpty,
        reason: 'Use TestTissue on Tissue books. '
            'See HowTo-Mitose-Tissue.md §1 and §9.');
  });

  test('no testRule: TestTissue on a Cell factory in example/', () {
    final violations = exampleLines()
        .where((line) =>
            line.split('//').first.contains('Cell.ingress') && line.split('//').first.contains('testRule: TestTissue') ||
            line.split('//').first.contains('Cell.state') && line.split('//').first.contains('testRule: TestTissue'))
        .toList();
    expect(violations, isEmpty,
        reason: 'Use TestCell on Cell factories. '
            'See HowTo-Mitose-Cell.md §3.1.');
  });
}
