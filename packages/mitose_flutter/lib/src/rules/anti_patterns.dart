// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The do-NOT rules.
///
/// Each rule checks a widget template (design time) and generated
/// code (rubric time) for one anti-pattern. The code-level checks are
/// conservative regex heuristics over the pipeline's fixed output
/// shape; `checkUnkeyedHookBuilder` is heuristic by design (documented
/// in the placement guide).
library;

import '../brd/ast.dart';
import '../failures.dart';
import 'patterns.dart';

/// A do-NOT rule.
class AntiPatternRule {
  const AntiPatternRule({
    required this.id,
    required this.name,
    required this.description,
    required this.checkTemplate,
    required this.checkCode,
  });

  /// Rubric check id (`anti-pattern.no-cell-in-build`, …).
  final String id;

  /// Function name, matching the placement-guide section.
  final String name;

  final String description;

  /// Template-level check (design time).
  final RuleViolation? Function(WidgetTemplate template, Brd brd) checkTemplate;

  /// Code-level check (rubric time), conservative heuristics.
  final RuleViolation? Function(String code, String path) checkCode;
}

RuleViolation _violation({
  required String subtype,
  required String ruleId,
  required String path,
  required String reason,
  required String fix,
  FailureResponsibility responsibility =
      FailureResponsibility.pipelineMaintainer,
}) {
  return RuleViolation(
    subtype: subtype,
    ruleId: ruleId,
    file: path,
    line: null,
    reason: reason,
    fix: fix,
    responsibility: responsibility,
  );
}

/// Fires when a `Cell` is created inside a `build` method.
final checkCellInBuild = AntiPatternRule(
  id: 'anti-pattern.no-cell-in-build',
  name: 'checkCellInBuild',
  description: 'A `Cell` is created inside a `build` method.',
  checkTemplate: (template, brd) => null,
  checkCode: (code, path) {
    // Heuristic: `Cell.state` / `Cell.restorableState` appearing after
    // a `build(` method signature and before the method's closing.
    final buildMatch = RegExp(
            r'Widget build\(BuildContext context\) \{([\s\S]*?)\n\s*\}',
            multiLine: true)
        .firstMatch(code);
    if (buildMatch == null) return null;
    final body = buildMatch.group(1)!;
    if (RegExp(r'Cell\.(state|restorableState)').hasMatch(body)) {
      return _violation(
        subtype: 'CellInBuild',
        ruleId: 'anti-pattern.no-cell-in-build',
        path: path,
        reason: '`Cell.state` called inside `build`.',
        fix: 'Move the cell creation to the widget\'s State (initState) or '
            'to a `lib/cells/` file. If this is generated code, this is a '
            'pipeline bug — report it.',
      );
    }
    return null;
  },
);

/// Fires when a writable `ValueCell` is passed to a child widget.
final checkWritableCellToChild = AntiPatternRule(
  id: 'anti-pattern.no-writable-cell-to-child',
  name: 'checkWritableCellToChild',
  description: 'A writable `ValueCell` is passed to a child widget.',
  checkTemplate: (template, brd) {
    // A template field named `cell` whose expression ends in `.cell`
    // (writable) on a pattern that is an isolation seam is fine; any
    // other child pass-through is flagged.
    for (final entry in template.fields.entries) {
      if (entry.key == 'cell' && entry.value.endsWith('.cell')) {
        if (template.widgetType == 'CellBuilder' &&
            entry.value.contains('unmodifiable')) {
          continue;
        }
        return _violation(
          subtype: 'WritableCellToChild',
          ruleId: 'anti-pattern.no-cell-in-build',
          path: '(design)',
          reason: 'writable ValueCell passed to child widget '
              '`${template.widgetType}`.',
          fix: 'Pass `cell.unmodifiable` to the child, or move the write '
              'into the parent. If this is generated code, this is a '
              'pipeline bug — report it.',
          responsibility: FailureResponsibility.appAuthor,
        );
      }
    }
    return null;
  },
  checkCode: (code, path) => null,
);

/// Fires when `Cell.observe` is called inside a widget.
final checkRawObserveInWidget = AntiPatternRule(
  id: 'anti-pattern.no-raw-observe-in-widget',
  name: 'checkRawObserveInWidget',
  description: '`Cell.observe` is called inside a widget.',
  checkTemplate: (template, brd) => null,
  checkCode: (code, path) {
    if (path.endsWith('_screen.dart') &&
        RegExp(r'Cell\.observe').hasMatch(code)) {
      return _violation(
        subtype: 'RawObserveInWidget',
        ruleId: 'anti-pattern.no-cell-in-build',
        path: path,
        reason: '`Cell.observe` called inside a widget.',
        fix: 'Use `CellListener` instead of a raw observation link. If this '
            'is generated code, this is a pipeline bug — report it.',
        responsibility: FailureResponsibility.appAuthor,
      );
    }
    return null;
  },
);

/// Fires when `setState` updates a cell-held value.
final checkSetStateOnCell = AntiPatternRule(
  id: 'anti-pattern.no-set-state-on-cell',
  name: 'checkSetStateOnCell',
  description: '`setState` is called to update a cell-held value.',
  checkTemplate: (template, brd) => null,
  checkCode: (code, path) {
    if (RegExp(r'setState\s*\(', multiLine: true).hasMatch(code) &&
        RegExp(r'\.cell\.value\s*=').hasMatch(code)) {
      return _violation(
        subtype: 'SetStateOnCell',
        ruleId: 'anti-pattern.no-cell-in-build',
        path: path,
        reason: '`setState` called to update a cell-held value.',
        fix: 'Write `cell.value = ...` instead of `setState`. If this is '
            'generated code, this is a pipeline bug — report it.',
        responsibility: FailureResponsibility.appAuthor,
      );
    }
    return null;
  },
);

/// Fires on an unkeyed `HookBuilder` around a cell-swappable binding
/// (heuristic by design).
final checkUnkeyedHookBuilder = AntiPatternRule(
  id: 'anti-pattern.no-unkeyed-hook-builder',
  name: 'checkUnkeyedHookBuilder',
  description: 'An unkeyed `HookBuilder` is used for a cell swap.',
  checkTemplate: (template, brd) => null,
  checkCode: (code, path) {
    final builderMatch =
        RegExp(r'HookBuilder\([^)]*builder:', multiLine: true).firstMatch(code);
    if (builderMatch != null &&
        !builderMatch.group(0)!.contains('key:') &&
        RegExp(r'\.cell\b').hasMatch(code)) {
      return _violation(
        subtype: 'UnkeyedHookBuilder',
        ruleId: 'anti-pattern.no-cell-in-build',
        path: path,
        reason: 'unkeyed HookBuilder around a cell-swappable binding.',
        fix: 'Give the HookBuilder a Key derived from the cell, or '
            'restructure to avoid the swap. If this is generated code, '
            'this is a pipeline bug — report it.',
        responsibility: FailureResponsibility.appAuthor,
      );
    }
    return null;
  },
);

/// The anti-pattern registry — the guide-sync check reads this list.
final allAntiPatternRules = [
  checkCellInBuild,
  checkWritableCellToChild,
  checkRawObserveInWidget,
  checkSetStateOnCell,
  checkUnkeyedHookBuilder,
];

/// Runs every anti-pattern rule's template check.
List<RuleViolation> checkAllTemplateAntiPatterns(
    WidgetTemplate template, Brd brd) {
  return [
    for (final rule in allAntiPatternRules)
      if (rule.checkTemplate(template, brd) case final violation?) violation,
  ];
}

/// Runs every anti-pattern rule's code check.
List<RuleViolation> checkAllCodeAntiPatterns(String code, String path) {
  return [
    for (final rule in allAntiPatternRules)
      if (rule.checkCode(code, path) case final violation?) violation,
  ];
}
