// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:io';

import 'package:mitose_flutter/mitose_flutter.dart';
import 'package:test/test.dart';

/// The code generator: structural contract over the canonical BRDs.
void main() {
  final root = Directory('example/brds');

  Brd brdOf(String stem) =>
      parseBrd(File('${root.path}/$stem.bfd.md').readAsStringSync());

  group('walkthrough generator', () {
    test('emits one step per requirement in order', () {
      final brd = brdOf('form_heavy');
      final walkthrough = generateWalkthrough(brd);
      final markdown = walkthrough.toMarkdown();
      expect(walkthrough.steps.length, brd.requirements.length);
      for (final (i, step) in walkthrough.steps.indexed) {
        expect(step.requirementId, brd.requirements[i].id);
        expect(markdown, contains(step.requirementId));
      }
      expect(markdown, contains('**Schema:** flutter-pipeline/v1'));
    });
  });

  group('design generator', () {
    test('produces a design with all screens and cells', () {
      final brd = brdOf('form_heavy');
      final design = generateDesign(brd, generateWalkthrough(brd));
      expect(design.screens.map((s) => s.name), containsAll(['Login', 'Home']));
      expect(design.cells.map((c) => c.name), contains('auth'));
      expect(design.routes, containsPair('Login', '/login'));
      expect(design.routes, containsPair('Home', '/home'));
    });
  });

  group('code generator', () {
    test('always has the canonical tree', () {
      for (final stem in ['form_heavy', 'list_heavy', 'async_heavy']) {
        final app = generateApp(brdOf(stem));
        for (final file in app.files) {
          expect(
            outputTreePatterns.any((p) => p.hasMatch(file.path)),
            isTrue,
            reason: '${file.path} is outside flutter-pipeline/v1',
          );
        }
        expect(app.file('lib/main.dart'), isNotNull);
        expect(app.file('test/app_test.dart'), isNull,
            reason: 'tests are generated separately');
      }
    });

    test('main.dart wraps CellScope and CellErrorBoundary at the root', () {
      final app = generateApp(brdOf('form_heavy'));
      final main = app.file('lib/main.dart')!.content;
      expect(main, contains('CellScope('));
      expect(main, contains('CellErrorBoundary('));
      expect(main, contains('CellRestorationScope('),
          reason: 'form BRD has restorable states');
      expect(main, contains("#auth: auth,"));
    });

    test('screen files exist for every BRD screen', () {
      final brd = brdOf('form_heavy');
      final app = generateApp(brd);
      expect(app.file('lib/screens/login_screen.dart'), isNotNull);
      expect(app.file('lib/screens/home_screen.dart'), isNotNull);
    });

    test('app-level cells become lib/cells files', () {
      final app = generateApp(brdOf('async_heavy'));
      expect(app.file('lib/cells/search_results.dart'), isNotNull,
          reason: 'camelCase state names map to snake_case files');
    });

    test('generation is deterministic', () {
      for (final stem in ['form_heavy', 'list_heavy', 'async_heavy']) {
        final a = generateApp(brdOf(stem));
        final b = generateApp(brdOf(stem));
        expect(a.stableHash(), b.stableHash());
      }
    });
  });

  group('test generator', () {
    test('emits one testWidgets + LEDGER per requirement', () {
      final brd = brdOf('async_heavy');
      final file = generateTests(brd, generateWalkthrough(brd));
      expect(
        '  testWidgets('.allMatches(file.content).length,
        brd.requirements.length,
      );
      // 7 calls + the `void LEDGER(...)` helper declaration.
      expect('LEDGER('.allMatches(file.content).length,
          brd.requirements.length + 1);
      for (final req in brd.requirements) {
        expect(file.content, contains(req.id));
      }
    });
  });

  group('output writer', () {
    test('writes and round-trips an app', () async {
      final dir = await Directory.systemTemp.createTemp('pipeline_write_test_');
      addTearDown(() => dir.delete(recursive: true));
      final app = generateApp(brdOf('form_heavy'));
      final testFile = generateTests(
          brdOf('form_heavy'), generateWalkthrough(brdOf('form_heavy')));
      final combined = GeneratedApp(
        brdTitle: app.brdTitle,
        files: [...app.files, testFile],
      );
      await writeApp(combined, dir);
      final loaded = await loadAppFromDirectory(dir, brdTitle: app.brdTitle);
      expect(loaded.stableHash(), combined.stableHash());
    });

    test('rejects files outside the canonical tree', () async {
      final dir =
          await Directory.systemTemp.createTemp('pipeline_reject_test_');
      addTearDown(() => dir.delete(recursive: true));
      final app = GeneratedApp(
        brdTitle: 'Bad',
        files: const [
          GeneratedFile(path: 'lib/sneaky.sh', content: 'evil'),
        ],
      );
      expect(writeApp(app, dir), throwsArgumentError);
    });
  });
}
