// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Phase D: the five-category rubric — clean apps are VERIFIED, and
/// each deliberate defect fails exactly one category (orthogonality).
library;

import 'dart:io';

import 'package:mitose_flutter/mitose_flutter.dart';
import 'package:test/test.dart';

void main() {
  Brd brdOf(String stem) =>
      parseBrd(File('example/brds/$stem.bfd.md').readAsStringSync());

  GeneratedApp cleanApp(String stem) {
    final brd = brdOf(stem);
    final walkthrough = generateWalkthrough(brd);
    final app = generateApp(brd);
    final tests = generateTests(brd, walkthrough);
    return GeneratedApp(
      brdTitle: brd.title,
      files: [...app.files, tests],
    );
  }

  GeneratedApp withContent(GeneratedApp app, String path, String content) {
    return GeneratedApp(
      brdTitle: app.brdTitle,
      files: [
        for (final file in app.files)
          if (file.path == path)
            GeneratedFile(path: file.path, content: content)
          else
            file,
      ],
    );
  }

  group('clean assessment', () {
    for (final stem in ['form_heavy', 'list_heavy', 'async_heavy']) {
      test('$stem is VERIFIED', () {
        final brd = brdOf(stem);
        final walkthrough = generateWalkthrough(brd);
        final design = generateDesign(brd, walkthrough);
        final assessment = assess(brd, walkthrough, design, cleanApp(stem));
        expect(assessment.verified, isTrue, reason: assessment.report());
        expect(assessment.failures, isEmpty);
      });
    }
  });

  group('deliberate defects fail exactly one category', () {
    test('coverage: a requirement without a widget', () {
      final stem = 'form_heavy';
      final brd = brdOf(stem);
      final walkthrough = generateWalkthrough(brd);
      final design = generateDesign(brd, walkthrough);
      // Drop REQ-003's walkthrough step: no widget satisfies it.
      final prunedWalkthrough = Walkthrough(
        title: walkthrough.title,
        steps: walkthrough.steps
            .where((s) => s.requirementId != 'REQ-003')
            .toList(),
      );
      final assessment = assess(brd, prunedWalkthrough, design, cleanApp(stem));
      expect(assessment.verified, isFalse);
      expect(assessment.failures.map((c) => c.id), ['coverage']);
    });

    test('placement: wrong widget type in the walkthrough', () {
      final stem = 'form_heavy';
      final brd = brdOf(stem);
      final walkthrough = generateWalkthrough(brd);
      final design = generateDesign(brd, walkthrough);
      final badSteps = [
        for (final step in walkthrough.steps)
          step.requirementId == 'REQ-001'
              ? WalkthroughStep(
                  requirementId: step.requirementId,
                  type: step.type,
                  screen: step.screen,
                  description: step.description,
                  widget: 'CellBuilder', // wrong type
                  widgetDetails: step.widgetDetails,
                  trigger: step.trigger,
                  assertion: step.assertion,
                  ledger: step.ledger,
                )
              : step,
      ];
      final badWalkthrough =
          Walkthrough(title: walkthrough.title, steps: badSteps);
      final assessment = assess(brd, badWalkthrough, design, cleanApp(stem));
      expect(assessment.verified, isFalse);
      expect(assessment.failures.map((c) => c.id), ['placement']);
    });

    test('anti-pattern: cell created inside build', () {
      final stem = 'form_heavy';
      final brd = brdOf(stem);
      final walkthrough = generateWalkthrough(brd);
      final design = generateDesign(brd, walkthrough);
      final app = cleanApp(stem);
      final screen = app.file('lib/screens/login_screen.dart')!.content;
      final polluted = screen.replaceFirst(
        'Widget build(BuildContext context) {',
        'Widget build(BuildContext context) {\n'
            '    final bad = Cell.state<int>(initial: 0);',
      );
      final assessment = assess(brd, walkthrough, design,
          withContent(app, 'lib/screens/login_screen.dart', polluted));
      expect(assessment.verified, isFalse);
      expect(assessment.failures.map((c) => c.id), ['anti-pattern']);
    });

    test('verification: interaction ledger changed to RENDER', () {
      final stem = 'form_heavy';
      final brd = brdOf(stem);
      final walkthrough = generateWalkthrough(brd);
      final design = generateDesign(brd, walkthrough);
      final app = cleanApp(stem);
      final tests = app.file('test/app_test.dart')!.content;
      // REQ-003 is an interaction requirement; flip its ledger kind.
      final bad = tests.replaceFirst(
        RegExp(r"(LEDGER\('REQ-003', ')interacted via ([^']*)('\);)"),
        r"$1rendered via $2$3",
      );
      final assessment = assess(brd, walkthrough, design,
          withContent(app, 'test/app_test.dart', bad));
      expect(assessment.verified, isFalse);
      expect(assessment.failures.map((c) => c.id), ['verification']);
    });

    test('structural: root CellErrorBoundary removed', () {
      final stem = 'form_heavy';
      final brd = brdOf(stem);
      final walkthrough = generateWalkthrough(brd);
      final design = generateDesign(brd, walkthrough);
      final app = cleanApp(stem);
      final main = app.file('lib/main.dart')!.content;
      final bad =
          main.replaceFirst('CellErrorBoundary(', 'CellErrorBoundaryRemoved(');
      final assessment = assess(
          brd, walkthrough, design, withContent(app, 'lib/main.dart', bad));
      expect(assessment.verified, isFalse);
      expect(assessment.failures.map((c) => c.id), ['structural']);
    });
  });

  group('ledger emitter', () {
    test('parses kinds from generated tests', () {
      final app = cleanApp('async_heavy');
      final entries = ledgerFromTests(app.file('test/app_test.dart')!.content);
      expect(entries.length, 7);
      expect(entries.map((e) => e.kind).toSet(),
          {'RENDER', 'INTERACT', 'RECOVER'});
    });

    test('stable body excludes the timestamp', () {
      final ledger = Ledger(
        title: 'Search',
        schemaVersion: 'flutter-pipeline/v1',
        generatedAt: '2026-11-16T00:00:00',
        entries: const [
          LedgerEntry(
              requirementId: 'REQ-001',
              kind: 'RENDER',
              evidence: 'rendered via CellTextField'),
        ],
      );
      expect(ledger.stableBody(), isNot(contains('Generated:')));
      expect(ledger.toMarkdown(), contains('Generated: 2026-11-16T00:00:00'));
    });
  });
}
