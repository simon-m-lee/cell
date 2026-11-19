// Regenerates the three reference apps under example/generated/.
// Run from packages/cell_flutter/pipeline:
//
//   dart run tool/regenerate_references.dart
//
// The outputs are the byte-identical references the `verify` command
// diffs against.

import 'dart:io';

import 'package:mitose_flutter/src/brd/parser.dart';
import 'package:mitose_flutter/src/cli/output.dart';
import 'package:mitose_flutter/src/generator/code_generator.dart';
import 'package:mitose_flutter/src/generator/design_generator.dart';
import 'package:mitose_flutter/src/generator/generated_app.dart';
import 'package:mitose_flutter/src/generator/test_generator.dart';
import 'package:mitose_flutter/src/generator/walkthrough_generator.dart';

Future<void> main() async {
  for (final stem in ['form_heavy', 'list_heavy', 'async_heavy']) {
    final markdown = File('example/brds/$stem.bfd.md').readAsStringSync();
    final brd = parseBrd(markdown);
    final walkthrough = generateWalkthrough(brd);
    generateDesign(brd, walkthrough); // design artifact (Gate 2)
    final app = generateApp(brd);
    final testFile = generateTests(brd, walkthrough);

    final combined = GeneratedApp(
      brdTitle: brd.title,
      files: [...app.files, testFile],
    );
    final out = Directory('example/generated/$stem');
    await writeApp(combined, out);
    stdout.writeln('generated $stem: ${combined.files.length} files');
  }
}
