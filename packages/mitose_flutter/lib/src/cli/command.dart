// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The CLI commands: `generate`, `verify`, `assess`.
///
/// Exit codes (contract in `docs/pipeline-cli.md`):
/// - 0 — success, or a deliberate rejection (gate reject, NOT_VERIFIED
///   assessment is reported and treated as a pipeline failure per
///   `docs/rubric.md`, see below);
/// - 1 — pipeline failure (invalid BRD, unplaceable sentence, assessment
///   failure, verify mismatch);
/// - 2 — usage / unexpected errors.
library;

import 'dart:io';

import '../brd/ast.dart';
import '../brd/design.dart';
import '../brd/parser.dart';
import '../brd/walkthrough.dart';
import '../failures.dart';
import '../generator/code_generator.dart';
import '../generator/design_generator.dart';
import '../generator/generated_app.dart';
import '../generator/test_generator.dart';
import '../generator/walkthrough_generator.dart';
import '../ledger/emitter.dart';
import '../rubric/assessor.dart';
import 'gates.dart';
import 'output.dart';

/// The result of running a command.
class CommandResult {
  const CommandResult({required this.exitCode, this.output = ''});

  final int exitCode;
  final String output;
}

/// Shared context for the commands.
class CliContext {
  const CliContext({
    required this.verbose,
    required this.noGates,
    required this.dryRun,
    required this.outDir,
  });

  final bool verbose;
  final bool noGates;
  final bool dryRun;
  final String outDir;
}

/// `generate <brd> --out <dir>` — the full three-gate pipeline.
Future<CommandResult> runGenerate(CliContext context, String brdPath) async {
  final reporter = Reporter(context.verbose);
  final file = File(brdPath);
  if (!await file.exists()) {
    return CommandResult(
        exitCode: 2, output: 'error: BRD not found: $brdPath\n');
  }
  final markdown = await file.readAsString();
  final Brd brd;
  try {
    brd = validateAndParseBrd(markdown, sourcePath: brdPath);
  } on SchemaValidationFailure catch (failure) {
    return CommandResult(exitCode: 1, output: failure.report());
  }
  reporter.line('Parsed ${brd.requirements.length} requirements, '
      '${brd.screens.length} screens, ${brd.state.length} states.');

  // Gate 1 — walkthrough.
  final Walkthrough walkthrough;
  try {
    walkthrough = generateWalkthrough(brd);
  } on PipelineFailure catch (failure) {
    return CommandResult(exitCode: 1, output: failure.report());
  }
  if (!context.noGates) {
    final decision = promptGate(
      title: 'Gate 1 — Walkthrough',
      artifact: walkthrough.toMarkdown(),
      summary: walkthrough.toMarkdown(),
    );
    if (decision == GateDecision.reject) {
      return const CommandResult(
          exitCode: 0, output: 'Gate 1 rejected — nothing written.\n');
    }
  } else {
    reporter.line('Gate 1 skipped (--no-gates).');
  }

  // Gate 2 — design.
  final Design design;
  try {
    design = generateDesign(brd, walkthrough);
  } on PipelineFailure catch (failure) {
    return CommandResult(exitCode: 1, output: failure.report());
  }
  if (!context.noGates) {
    final decision = promptGate(
      title: 'Gate 2 — Design',
      artifact: design.toMarkdown(),
      summary: design.toMarkdown(),
    );
    if (decision == GateDecision.reject) {
      return const CommandResult(
          exitCode: 0, output: 'Gate 2 rejected — nothing written.\n');
    }
  } else {
    reporter.line('Gate 2 skipped (--no-gates).');
  }

  // Generation + tests.
  final GeneratedApp app;
  try {
    app = generateApp(brd);
  } on PipelineFailure catch (failure) {
    return CommandResult(exitCode: 1, output: failure.report());
  }
  final tests = generateTests(brd, walkthrough);
  final combined = GeneratedApp(
    brdTitle: app.brdTitle,
    files: [...app.files, tests],
  );

  // Gate 3 — assessment (always runs, even with --no-gates).
  final assessment = assess(brd, walkthrough, design, combined);
  reporter.line(assessment.report());
  if (!assessment.verified) {
    return CommandResult(
        exitCode: 1, output: 'Assessment NOT_VERIFIED — nothing written.\n');
  }

  if (context.dryRun) {
    return CommandResult(
        exitCode: 0,
        output: 'Dry run: assessment VERIFIED; ${combined.files.length} '
            'files would be written to ${context.outDir}.\n');
  }

  try {
    await writeApp(combined, Directory(context.outDir));
  } on ArgumentError catch (error) {
    return CommandResult(exitCode: 1, output: 'error: $error\n');
  }

  // LEDGER artifact in the sibling ledgers/ directory.
  final ledger = Ledger(
    title: brd.title,
    schemaVersion: 'flutter-pipeline/v1',
    generatedAt: DateTime.now().toUtc().toIso8601String(),
    entries: ledgerFromTests(tests.content),
  );
  final ledgersDir =
      Directory('${Directory(context.outDir).parent.path}/ledgers');
  await ledgersDir.create(recursive: true);
  final stem = packageName(brd.title);
  await File('${ledgersDir.path}/$stem.ledger.md')
      .writeAsString('${ledger.toMarkdown().trimRight()}\n');

  return CommandResult(
      exitCode: 0,
      output: 'Generated ${combined.files.length} files into '
          '${context.outDir} (assessment VERIFIED).\n');
}

/// `verify <brd>` — regenerate and byte-compare against the committed
/// reference in `example/generated/<stem>/`.
Future<CommandResult> runVerify(CliContext context, String brdPath) async {
  final file = File(brdPath);
  final stem = file.uri.pathSegments.last.replaceAll(RegExp(r'\.bfd\.md$'), '');
  if (!await file.exists()) {
    return CommandResult(
        exitCode: 2, output: 'error: BRD not found: $brdPath\n');
  }
  final Brd brd;
  try {
    brd = parseBrd(await file.readAsString());
  } on PipelineFailure catch (failure) {
    return CommandResult(exitCode: 1, output: failure.report());
  }
  final walkthrough = generateWalkthrough(brd);
  final design = generateDesign(brd, walkthrough);
  final app = generateApp(brd);
  final tests = generateTests(brd, walkthrough);
  final combined = GeneratedApp(
    brdTitle: brd.title,
    files: [...app.files, tests],
  );

  final assessment = assess(brd, walkthrough, design, combined);
  if (!assessment.verified) {
    return CommandResult(
        exitCode: 1,
        output: 'Assessment failed before comparison:\n'
            '${assessment.report()}');
  }

  final reference = Directory('example/generated/$stem');
  if (!await reference.exists()) {
    return CommandResult(
        exitCode: 1,
        output: 'No committed reference at ${reference.path}; run '
            '`dart run tool/regenerate_references.dart`.\n');
  }
  final referenceApp =
      await loadAppFromDirectory(reference, brdTitle: brd.title);
  if (referenceApp.stableHash() == combined.stableHash()) {
    return CommandResult(
        exitCode: 0,
        output: 'VERIFIED: $stem matches the committed '
            'reference byte-for-byte.\n');
  }
  return CommandResult(
      exitCode: 1,
      output: 'MISMATCH: $stem differs from the committed reference.\n');
}

/// `assess <brd> [--app <dir>]` — run the rubric alone.
Future<CommandResult> runAssess(
  CliContext context,
  String brdPath,
  String? appDir,
) async {
  final file = File(brdPath);
  if (!await file.exists()) {
    return CommandResult(
        exitCode: 2, output: 'error: BRD not found: $brdPath\n');
  }
  final Brd brd;
  try {
    brd = parseBrd(await file.readAsString());
  } on PipelineFailure catch (failure) {
    return CommandResult(exitCode: 1, output: failure.report());
  }
  final walkthrough = generateWalkthrough(brd);
  final design = generateDesign(brd, walkthrough);

  final GeneratedApp app;
  if (appDir != null) {
    final dir = Directory(appDir);
    if (!await dir.exists()) {
      return const CommandResult(
          exitCode: 2, output: 'error: --app directory not found\n');
    }
    app = await loadAppFromDirectory(dir, brdTitle: brd.title);
  } else {
    app = GeneratedApp(
      brdTitle: brd.title,
      files: [...generateApp(brd).files, generateTests(brd, walkthrough)],
    );
  }

  final assessment = assess(brd, walkthrough, design, app);
  final report = assessment.report();
  return CommandResult(exitCode: assessment.verified ? 0 : 1, output: report);
}

/// Minimal stdout reporter honoring --verbose.
class Reporter {
  const Reporter(this.verbose);

  final bool verbose;

  void line(String message) {
    if (verbose) stdout.writeln(message);
  }
}
