// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Phase 3.2 of CONTRIBUTING-AI-DOC.md (package:cell_flow variant): the
// seam grep rules that fail a Mitose run also fail this package's own CI.

import 'dart:io';

import 'package:test/test.dart';

List<File> exampleFiles() {
  final dir = Directory('example');
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Extracts the body of each `class X extends FlowInstructionBase` block.
List<String> instructionBodies(File file) {
  final lines = file.readAsLinesSync();
  final bodies = <String>[];
  var i = 0;
  while (i < lines.length) {
    final m = RegExp(r'^\s*class\s+\w+\s+extends\s+FlowInstructionBase')
        .firstMatch(lines[i]);
    if (m == null) {
      i++;
      continue;
    }
    final body = StringBuffer();
    var depth = 0;
    var started = false;
    for (; i < lines.length; i++) {
      for (final ch in lines[i].split('')) {
        if (ch == '{') {
          depth++;
          started = true;
        } else if (ch == '}') {
          depth--;
        }
      }
      if (started) body.writeln(lines[i]);
      if (started && depth <= 0) break;
    }
    bodies.add(body.toString());
    i++;
  }
  return bodies;
}

final _tissueWrite = RegExp(
    r'(Tissue\w+|\w*[Ee]vents|\w*[Ii]ncidents?|\w*[Qq]ueue|\w*[Bb]ooks?)\s*\.\s*(add|addAll|addLast|addFirst|remove|clear|set)\s*\(');

void main() {
  test('no Tissue write inside any FlowInstructionBase subclass in example/',
      () {
    final violations = <String>[];
    for (final file in exampleFiles()) {
      for (final body in instructionBodies(file)) {
        for (final line in body.split('\n')) {
          final code = line.split('//').first;
          if (_tissueWrite.hasMatch(code)) {
            violations.add('${file.path}: $line');
          }
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'The instruction decides; the chain assembles; the observer '
            'glues. See HowTo-Mitose-Flow.md §5.');
  });

  test('no testRule: TestCell on any Tissue constructor in example/', () {
    final violations = exampleFiles()
        .expand((f) => f.readAsLinesSync())
        .where((line) =>
            line.split('//').first.contains('Tissue') && line.split('//').first.contains('testRule: TestCell'))
        .toList();
    expect(violations, isEmpty,
        reason: 'Use TestTissue on Tissue books. '
            'See HowTo-Mitose-Tissue.md §1 and §9.');
  });
}
