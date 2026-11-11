// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Generates test/ai_guide_examples/ai_guide_examples.generated.dart from the
// `### AI Agent Guide` blocks in lib/ (package:cell_tissue variant).
//
//   dart run tool/generate_ai_examples.dart

import 'dart:io';

import 'ai_guide_doc.dart';

const String packageName = 'cell_tissue';
const String mainImport = 'cell_tissue/cell_tissue.dart';

/// Extra imports needed by the snippets (unused imports are avoided because
/// at least one snippet in the generated file uses every listed import).
const List<String> extraImports = [];

String generateExamples(List<AiGuideBlock> blocks) {
  final buffer = StringBuffer();
  buffer.writeln('// GENERATED FILE — do not edit by hand.');
  buffer.writeln('// Regenerate with: dart run tool/generate_ai_examples.dart');
  buffer.writeln('//');
  buffer.writeln('// Compiles and executes every `Minimal compilable example` from the');
  buffer.writeln('// `### AI Agent Guide` doc blocks in lib/. Verified by');
  buffer.writeln('// test/ai_guide_examples_test.dart.');
  buffer.writeln('// ignore_for_file: non_constant_identifier_names, avoid_print');
  buffer.writeln();
  buffer.writeln("import 'package:$mainImport';");
  buffer.writeln("import 'dart:io' as io;");
  for (final imp in extraImports) {
    buffer.writeln("import '$imp';");
  }
  buffer.writeln();

  final sorted = [...blocks]..sort((a, b) => a.key.compareTo(b.key));
  for (final b in sorted) {
    final fn = 'aiExample${sanitize(b.key)}';
    buffer.writeln('// <${relPath(b.file)}:${b.line}>');
    buffer.writeln('Future<void> $fn() async {');
    for (final line in b.snippet.split('\n')) {
      buffer.writeln('  ${line.isEmpty ? '' : line}');
    }
    buffer.writeln('}');
    buffer.writeln();
  }

  buffer.writeln('Future<void> main() async {');
  buffer.writeln('  var failures = 0;');
  for (final b in sorted) {
    final fn = 'aiExample${sanitize(b.key)}';
    buffer.writeln("  try { await $fn(); print('ai-example: ${b.key} ok'); }");
    buffer.writeln('  catch (e, st) { failures++; '
        "print('ai-example: ${b.key} FAILED: \$e'); print(st); }");
  }
  buffer.writeln('  if (failures > 0) {');
  buffer.writeln("    print('ai-examples: \$failures of ${sorted.length} failed');");
  buffer.writeln('    io.exitCode = 1;');
  buffer.writeln('  } else {');
  buffer.writeln("    print('ai-examples: all ${sorted.length} passed');");
  buffer.writeln('  }');
  buffer.writeln('}');
  return buffer.toString();
}

String sanitize(String key) {
  final clean = key.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  return clean;
}

String relPath(String path) {
  final norm = path.replaceAll('\\', '/');
  final idx = norm.lastIndexOf('/lib/');
  return idx == -1 ? norm : norm.substring(idx + 1);
}

Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  final blocks = parseAllBlocks('$root${Platform.pathSeparator}lib');
  if (blocks.isEmpty) {
    stderr.writeln('No AI Agent Guide blocks found in lib/ — aborting.');
    exitCode = 1;
    return;
  }
  final output = generateExamples(blocks);
  final file = File('$root${Platform.pathSeparator}test'
      '${Platform.pathSeparator}ai_guide_examples'
      '${Platform.pathSeparator}ai_guide_examples.generated.dart');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(output);
  stdout.writeln('Wrote ${file.path} (${blocks.length} examples).');
}
