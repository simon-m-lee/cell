// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Phase E: the CLI contract — `generate`, `verify`, `assess`, gates,
/// and exit codes.
library;

import 'dart:io';

import 'package:mitose_flutter/mitose_flutter.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mitose_cli_test_');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  String writeBrd(String name, String content) {
    final file = File('${tmp.path}/$name');
    file.writeAsStringSync(content);
    return file.path;
  }

  String canonicalBrd(String stem) {
    final file = File('example/brds/$stem.bfd.md');
    return file.absolute.path;
  }

  group('generate', () {
    test('writes the app and the LEDGER (--no-gates)', () async {
      final out = '${tmp.path}/app';
      final result = await runGenerate(
        CliContext(verbose: false, noGates: true, dryRun: false, outDir: out),
        canonicalBrd('form_heavy'),
      );
      expect(result.exitCode, 0, reason: result.output);
      expect(File('$out/lib/main.dart').existsSync(), isTrue);
      expect(File('$out/test/app_test.dart').existsSync(), isTrue);
      final ledgers = Directory('${tmp.path}/ledgers');
      expect(File('${ledgers.path}/login_flow.ledger.md').existsSync(), isTrue);
      final ledger =
          File('${ledgers.path}/login_flow.ledger.md').readAsStringSync();
      expect(ledger, contains('| REQ-001 | RENDER |'));
      expect(ledger, contains('Generated:'));
    });

    test('--dry-run writes nothing', () async {
      final out = '${tmp.path}/app';
      final result = await runGenerate(
        CliContext(verbose: false, noGates: true, dryRun: true, outDir: out),
        canonicalBrd('list_heavy'),
      );
      expect(result.exitCode, 0, reason: result.output);
      expect(result.output, contains('Dry run'));
      expect(Directory(out).existsSync(), isFalse);
    });

    test('a malformed BRD fails with exit 1 and a failure report', () async {
      final bad = writeBrd(
        'bad.bfd.md',
        '''
---
title: Bad
schema: flutter-pipeline/v1
---

## Requirements

| ID | Sentence | Screen | Trigger | Outcome | Type |
|---|---|---|---|---|---|
| REQ-001 | User sees the thing | Main | | Thing seen | display |

## Screens

| Name | Route |
|---|---|
| Main | /main |

## State

| Name | Type | Initial |
|---|---|---|
| thing | String | '' |
''',
      );
      final result = await runGenerate(
        CliContext(
            verbose: false,
            noGates: true,
            dryRun: false,
            outDir: '${tmp.path}/app'),
        bad,
      );
      expect(result.exitCode, 1);
      expect(result.output, contains('SchemaValidationFailure'));
    });

    test('a missing BRD exits 2', () async {
      final result = await runGenerate(
        CliContext(
            verbose: false,
            noGates: true,
            dryRun: false,
            outDir: '${tmp.path}/app'),
        '${tmp.path}/nope.bfd.md',
      );
      expect(result.exitCode, 2);
    });
  });

  group('verify', () {
    for (final stem in ['form_heavy', 'list_heavy', 'async_heavy']) {
      test('$stem matches its committed reference', () async {
        final result = await runVerify(
          CliContext(verbose: false, noGates: true, dryRun: false, outDir: ''),
          canonicalBrd(stem),
        );
        expect(result.exitCode, 0, reason: result.output);
        expect(result.output, contains('VERIFIED'));
      });
    }
  });

  group('assess', () {
    test('freshly generated apps are VERIFIED (exit 0)', () async {
      for (final stem in ['form_heavy', 'list_heavy', 'async_heavy']) {
        final result = await runAssess(
          CliContext(verbose: false, noGates: true, dryRun: false, outDir: ''),
          canonicalBrd(stem),
          null,
        );
        expect(result.exitCode, 0, reason: result.output);
        expect(result.output, contains('VERIFIED'));
      }
    });

    test('a defective --app dir is NOT_VERIFIED (exit 1)', () async {
      // Write a generated app, then sabotage it structurally.
      final out = '${tmp.path}/app';
      final generated = await runGenerate(
        CliContext(verbose: false, noGates: true, dryRun: false, outDir: out),
        canonicalBrd('form_heavy'),
      );
      expect(generated.exitCode, 0);
      final main = File('$out/lib/main.dart');
      main.writeAsStringSync(
          main.readAsStringSync().replaceFirst('CellScope(', 'NotCellScope('));
      final result = await runAssess(
        CliContext(verbose: false, noGates: true, dryRun: false, outDir: ''),
        canonicalBrd('form_heavy'),
        out,
      );
      expect(result.exitCode, 1);
      expect(result.output, contains('NOT_VERIFIED'));
      expect(result.output, contains('structural'));
    });
  });

  group('gates', () {
    test('non-interactive sessions auto-approve', () {
      expect(
        promptGate(
          title: 'Gate 1 — Walkthrough',
          artifact: 'artifact',
          summary: 'summary',
          interactive: false,
        ),
        GateDecision.approve,
      );
    });
  });

  group('binary', () {
    test('--version prints the version (exit 0)', () async {
      final result = await Process.run(
        'dart',
        ['run', 'bin/mitose_flutter.dart', '--version'],
        runInShell: true,
      );
      expect(result.exitCode, 0);
      expect('${result.stdout}', contains('mitose_flutter'));
    });

    test('no command exits 2 with usage', () async {
      final result = await Process.run(
        'dart',
        ['run', 'bin/mitose_flutter.dart'],
        runInShell: true,
      );
      expect(result.exitCode, 2);
    });
  });
}
