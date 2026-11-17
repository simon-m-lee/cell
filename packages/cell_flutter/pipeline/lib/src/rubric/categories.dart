// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The five rubric categories, one check function per locked checkId
/// (see `docs/rubric.md`).
library;

import '../brd/ast.dart';
import '../brd/design.dart';
import '../brd/walkthrough.dart';
import '../cli/output.dart';
import '../generator/generated_app.dart';
import '../rules/anti_patterns.dart';
import '../rules/placement_rules.dart';
import 'assessor.dart';

/// Builds the five categories in rubric order.
List<CategoryResult> evaluateCategories(
  Brd brd,
  Walkthrough walkthrough,
  Design design,
  GeneratedApp app,
) {
  return [
    coverageCategory(brd, walkthrough, app),
    placementCategory(brd, walkthrough),
    antiPatternCategory(app),
    verificationCategory(brd, app),
    structuralCategory(brd, app),
  ];
}

CategoryResult coverageCategory(
    Brd brd, Walkthrough walkthrough, GeneratedApp app) {
  final tests = app.file('test/app_test.dart')?.content ?? '';
  final stepIds = walkthrough.steps.map((s) => s.requirementId).toList();
  final testIds = RegExp(r"testWidgets\('(REQ-\d+)")
      .allMatches(tests)
      .map((m) => m.group(1)!)
      .toList();

  final everyReqHasWidget = CheckResult(
    id: 'coverage.every-requirement-has-widget',
    outcome: brd.requirements.every((r) => stepIds.contains(r.id))
        ? CheckOutcome.pass
        : CheckOutcome.fail,
    detail: 'walkthrough steps: ${stepIds.join(', ')}',
  );
  final everyReqHasTest = CheckResult(
    id: 'coverage.every-requirement-has-test',
    outcome: brd.requirements.every((r) => testIds.contains(r.id))
        ? CheckOutcome.pass
        : CheckOutcome.fail,
    detail: 'testWidgets: ${testIds.join(', ')}',
  );
  final everyWidgetHasReq = CheckResult(
    id: 'coverage.every-widget-has-requirement',
    outcome: stepIds.every((id) => brd.requirements.any((r) => r.id == id))
        ? CheckOutcome.pass
        : CheckOutcome.fail,
    detail: 'no orphan walkthrough steps',
  );
  final everyTestHasReq = CheckResult(
    id: 'coverage.every-test-has-requirement',
    outcome: testIds.length == brd.requirements.length &&
            testIds.every((id) => brd.requirements.any((r) => r.id == id))
        ? CheckOutcome.pass
        : CheckOutcome.fail,
    detail: '${testIds.length} testWidgets for ${brd.requirements.length} '
        'requirements',
  );
  return CategoryResult(
    id: 'coverage',
    name: 'Coverage',
    checks: [
      everyReqHasWidget,
      everyReqHasTest,
      everyWidgetHasReq,
      everyTestHasReq
    ],
  );
}

CategoryResult placementCategory(Brd brd, Walkthrough walkthrough) {
  final checks = <CheckResult>[];
  for (final req in brd.requirements) {
    final choice = place(req, brd);
    final step =
        walkthrough.steps.where((s) => s.requirementId == req.id).firstOrNull;

    if (step == null) {
      // Missing steps are Coverage's concern; stay orthogonal.
      checks.addAll(const [
        CheckResult(
            id: 'placement.widget-type-matches',
            outcome: CheckOutcome.notApplicable),
        CheckResult(
            id: 'placement.cell-binding-matches',
            outcome: CheckOutcome.notApplicable),
        CheckResult(
            id: 'placement.builder-shape-matches',
            outcome: CheckOutcome.notApplicable),
      ]);
      continue;
    }

    checks.add(CheckResult(
      id: 'placement.widget-type-matches',
      outcome:
          step.widget == choice.widget ? CheckOutcome.pass : CheckOutcome.fail,
      detail: '${req.id}: ${step.widget} vs ${choice.widget}',
    ));
    checks.add(CheckResult(
      id: 'placement.cell-binding-matches',
      outcome: step.widgetDetails
              .contains(choice.boundStates.firstOrNull?.name ?? '∅')
          ? CheckOutcome.pass
          : CheckOutcome.fail,
      detail: '${req.id}: ${step.widgetDetails}',
    ));
    checks.add(CheckResult(
      id: 'placement.builder-shape-matches',
      outcome: step.widgetDetails.contains(choice.pattern.widgetDetails())
          ? CheckOutcome.pass
          : CheckOutcome.fail,
      detail: '${req.id}: ${step.widgetDetails} vs '
          '${choice.pattern.widgetDetails()}',
    ));
  }
  return CategoryResult(
    id: 'placement',
    name: 'Placement correctness',
    checks: checks,
  );
}

CategoryResult antiPatternCategory(GeneratedApp app) {
  final checks = <CheckResult>[];
  final codeFiles = app.files.where((f) => f.path.endsWith('.dart')).toList();
  for (final rule in allAntiPatternRules) {
    final violations = <String>[];
    for (final file in codeFiles) {
      final violation = rule.checkCode(file.content, file.path);
      if (violation != null) {
        violations.add('${file.path}: ${violation.reason}');
      }
    }
    checks.add(CheckResult(
      id: rule.id,
      outcome: violations.isEmpty ? CheckOutcome.pass : CheckOutcome.fail,
      detail: violations.isEmpty ? 'clean' : violations.join('; '),
    ));
  }
  return CategoryResult(
    id: 'anti-pattern',
    name: 'Anti-pattern compliance',
    checks: checks,
  );
}

CategoryResult verificationCategory(Brd brd, GeneratedApp app) {
  final tests = app.file('test/app_test.dart')?.content ?? '';
  final ledgerLines = RegExp(r"LEDGER\('(REQ-\d+)', '([^']*)'\)")
      .allMatches(tests)
      .map((m) => (id: m.group(1)!, evidence: m.group(2)!))
      .toList();
  final checks = <CheckResult>[];

  for (final (type, id, wantKind) in [
    (RequirementType.display, 'verification.display-has-render', 'RENDER'),
    (
      RequirementType.interaction,
      'verification.interaction-has-interact',
      'INTERACT'
    ),
    (RequirementType.recovery, 'verification.recovery-has-recover', 'RECOVER'),
    (RequirementType.atomic, 'verification.atomic-has-interact', 'INTERACT'),
  ]) {
    final reqs = brd.requirements.where((r) => r.type == type).toList();
    final bad = reqs
        .where((r) {
          final line = ledgerLines.where((l) => l.id == r.id).firstOrNull;
          return line == null ||
              !line.evidence.toLowerCase().contains(wantKind.toLowerCase());
        })
        .map((r) => r.id)
        .toList();
    checks.add(CheckResult(
      id: id,
      outcome: reqs.isEmpty
          ? CheckOutcome.notApplicable
          : (bad.isEmpty ? CheckOutcome.pass : CheckOutcome.fail),
      detail: bad.isEmpty ? 'ok' : 'missing/wrong kind: ${bad.join(', ')}',
    ));
    if (type == RequirementType.atomic && reqs.isNotEmpty) {
      final usesTx = tests.contains('txApply');
      checks.add(CheckResult(
        id: 'verification.atomic-has-txapply',
        outcome: usesTx ? CheckOutcome.pass : CheckOutcome.fail,
        detail: usesTx ? 'txApply present' : 'txApply missing',
      ));
    }
  }

  final missing = brd.requirements
      .where((r) => !ledgerLines.any((l) => l.id == r.id))
      .map((r) => r.id)
      .toList();
  checks.add(CheckResult(
    id: 'verification.all-ledger-lines-present',
    outcome: missing.isEmpty ? CheckOutcome.pass : CheckOutcome.fail,
    detail: missing.isEmpty ? 'all present' : 'missing: ${missing.join(', ')}',
  ));

  return CategoryResult(
    id: 'verification',
    name: 'Verification completeness',
    checks: checks,
  );
}

CategoryResult structuralCategory(Brd brd, GeneratedApp app) {
  final main = app.file('lib/main.dart')?.content ?? '';
  final anyRestorable = brd.state.any((s) => s.restorable);
  final appLevel = brd.state.where((s) => s.appLevel).toList();
  bool hasIdentifier(String name) =>
      RegExp('(?<![A-Za-z0-9_])$name\\(').hasMatch(main);
  final checks = <CheckResult>[
    CheckResult(
      id: 'structural.main-exists',
      outcome: app.file('lib/main.dart') != null
          ? CheckOutcome.pass
          : CheckOutcome.fail,
      detail: 'lib/main.dart',
    ),
    CheckResult(
      id: 'structural.cell-scope-at-root',
      outcome: hasIdentifier('CellScope') && main.contains('child: scoped')
          ? CheckOutcome.pass
          : CheckOutcome.fail,
      detail: 'CellScope at root of main.dart',
    ),
    CheckResult(
      id: 'structural.error-boundary-at-root',
      outcome:
          hasIdentifier('CellErrorBoundary') && main.contains('child: tree')
              ? CheckOutcome.pass
              : CheckOutcome.fail,
      detail: 'CellErrorBoundary wraps the app',
    ),
    CheckResult(
      id: 'structural.restoration-scope',
      outcome: !anyRestorable || hasIdentifier('CellRestorationScope')
          ? CheckOutcome.pass
          : CheckOutcome.fail,
      detail: anyRestorable
          ? 'restorable states need CellRestorationScope'
          : 'no restorable states',
    ),
    CheckResult(
      id: 'structural.app-level-cells-registered',
      outcome: appLevel.every((s) => main.contains('#${s.name}:'))
          ? CheckOutcome.pass
          : CheckOutcome.fail,
      detail: 'registered: ${appLevel.map((s) => s.name).join(', ')}',
    ),
  ];
  final treeOk =
      app.files.every((f) => outputTreePatterns.any((p) => p.hasMatch(f.path)));
  checks.add(CheckResult(
    id: 'structural.output-tree-matches',
    outcome: treeOk ? CheckOutcome.pass : CheckOutcome.fail,
    detail: '${app.files.length} files match flutter-pipeline/v1',
  ));
  return CategoryResult(
    id: 'structural',
    name: 'Structural invariants',
    checks: checks,
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
