// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The mitose_flutter CLI.
///
/// Commands: `generate`, `verify`, `assess`. See `docs/pipeline-cli.md`
/// for the contract.
library;

import 'dart:io';

import 'package:args/args.dart';

import 'package:mitose_flutter/mitose_flutter.dart';

const toolVersion = '0.1.0-dev.1';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
    ..addFlag('version',
        negatable: false, help: 'Print the tool version and exit.')
    ..addCommand('generate')
    ..addCommand('verify')
    ..addCommand('assess');

  parser.commands['generate']!
    ..addOption('out',
        abbr: 'o', mandatory: true, help: 'Output directory for the app.')
    ..addFlag('no-gates',
        negatable: false,
        help: 'Skip the interactive walkthrough/design gates '
            '(assessment still runs).')
    ..addFlag('dry-run',
        negatable: false, help: 'Run everything except writing files.')
    ..addOption('schema',
        help: 'Custom schema path (defaults to '
            'docs/brd-schema.json; the embedded validator implements v1).')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Print step-by-step progress.');
  parser.commands['verify']!
    ..addOption('schema',
        help: 'Custom schema path (defaults to '
            'docs/brd-schema.json; the embedded validator implements v1).')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Print step-by-step progress.');
  parser.commands['assess']!
    ..addOption('app',
        abbr: 'a',
        help: 'Assess an existing app directory '
            'instead of the freshly generated one.')
    ..addOption('schema',
        help: 'Custom schema path (defaults to '
            'docs/brd-schema.json; the embedded validator implements v1).')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Print step-by-step progress.');

  try {
    final top = parser.parse(arguments);
    if (top['version'] == true) {
      stdout.writeln('mitose_flutter $toolVersion');
      exit(0);
    }
    final commandName = top.command?.name;
    if (commandName == null || top['help'] == true) {
      stdout.writeln('mitose_flutter — the cell_flutter Mitose pipeline.');
      stdout.writeln();
      stdout.writeln(parser.usage);
      exit(commandName == null ? 2 : 0);
    }

    final args = parser.commands[commandName]!;
    final command = args.parse(top.arguments);
    var rest = command.rest;
    // The sub-parser sees the command name as its first positional.
    if (rest.isNotEmpty && rest.first == commandName) {
      rest = rest.skip(1).toList();
    }
    if (rest.isEmpty) {
      stderr.writeln('error: <brd> is required');
      exit(2);
    }
    final brdPath = rest.first;
    T? opt<T>(ArgResults results, String name) {
      try {
        return results.wasParsed(name) ? results[name] as T : null;
      } on ArgumentError {
        return null; // Option not registered for this command.
      }
    }

    final context = CliContext(
      verbose: opt<bool>(command, 'verbose') ?? false,
      noGates: opt<bool>(command, 'no-gates') ?? false,
      dryRun: opt<bool>(command, 'dry-run') ?? false,
      outDir: opt<String>(command, 'out') ?? 'generated_app',
    );

    final CommandResult result = switch (commandName) {
      'generate' => await runGenerate(context, brdPath),
      'verify' => await runVerify(context, brdPath),
      'assess' =>
        await runAssess(context, brdPath, opt<String>(command, 'app')),
      _ => const CommandResult(
          exitCode: 2,
          output: 'error: unknown command\n',
        ),
    };

    stdout.write(result.output);
    exit(result.exitCode);
  } on FormatException catch (error) {
    stderr.writeln('error: ${error.message}');
    exit(2);
  } catch (error) {
    stderr.writeln('error: unexpected: $error');
    exit(2);
  }
}
