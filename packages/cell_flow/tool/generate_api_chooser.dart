// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Generates lib/doc/api_chooser.dart from the `### AI Agent Guide` blocks
// (package:cell_flow variant). Asserted fresh by
// test/api_chooser_up_to_date_test.dart.
//
//   dart run tool/generate_api_chooser.dart

import 'dart:io';

import 'ai_guide_doc.dart';

const String packageName = 'cell_flow';
const String libraryName = 'cell_flow_api_chooser';
const String intro = '''
**Layer:** Flow. Owns: `riskOf` / operators / latch / product filter /
chain assembly / `toHandle`. Does **not** own: ingress, observe,
Transaction, or any Tissue write. See `HowTo-Mitose-Flow.md` §1.

**Read this file when:** a BRD sentence asks "wait", "rate-limit",
"cancel", "parallel", "batch", or "combine multiple sources."
''';

String generateApiChooser(List<AiGuideBlock> blocks) {
  final buffer = StringBuffer();
  buffer.writeln('// GENERATED FILE — do not edit by hand.');
  buffer.writeln('// Regenerate with: dart run tool/generate_api_chooser.dart');
  buffer.writeln('//');
  buffer.writeln('// Documentation only — this library is not imported by');
  buffer.writeln('// application code. It renders the AI decision matrix on pub.dev.');
  buffer.writeln('/// ## API Chooser — `$packageName` operators');
  buffer.writeln('///');
  for (final line in intro.trim().split('\n')) {
    buffer.writeln('/// $line');
  }
  buffer.writeln('///');
  buffer.writeln('/// The full decision procedure lives in `HowTo-Mitose-Flow.md`; this');
  buffer.writeln('/// matrix is generated from the `### AI Agent Guide` blocks and cannot');
  buffer.writeln('/// drift.');
  buffer.writeln('///');
  buffer.writeln('/// | Symbol | When to use | When NOT to use | Live signature | Guide | Example |');
  buffer.writeln('/// |---|---|---|---|---|---|');

  final sorted = [...blocks]..sort((a, b) => a.key.compareTo(b.key));
  for (final b in sorted) {
    buffer.writeln('/// | `${b.key}` | ${_cell(b.whenToUse)} | '
        '${_cell(b.whenNotToUse)} | ${_cell(b.liveSignature)} | '
        '${_cell(b.guide)} | ${_cell(b.example)} |');
  }
  buffer.writeln('///');
  buffer.writeln('/// ## How this matrix stays fresh');
  buffer.writeln('///');
  buffer.writeln('/// * `dart run tool/generate_api_chooser.dart` — regenerates this file.');
  buffer.writeln('/// * `test/api_chooser_up_to_date_test.dart` — fails CI if stale.');
  buffer.writeln('/// * `dart run tool/ai_preflight.dart` — fails CI if a pin drifts.');
  buffer.writeln('///');
  buffer.writeln('// ignore: unnecessary_library_name');
  buffer.writeln('library $libraryName;');
  buffer.writeln();
  return buffer.toString();
}

String _cell(String value) {
  return value
      .replaceAll('|', '/')
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  final blocks = parseAllBlocks('$root${Platform.pathSeparator}lib');
  if (blocks.isEmpty) {
    stderr.writeln('No AI Agent Guide blocks found in lib/ — aborting.');
    exitCode = 1;
    return;
  }
  final output = generateApiChooser(blocks);
  final file = File('$root${Platform.pathSeparator}lib'
      '${Platform.pathSeparator}doc${Platform.pathSeparator}api_chooser.dart');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(output);
  stdout.writeln('Wrote ${file.path} (${blocks.length} rows).');
}
