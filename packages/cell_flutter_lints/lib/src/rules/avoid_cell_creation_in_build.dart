// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

const _code = LintCode(
  name: 'cell_avoid_creation_in_build',
  problemMessage:
      'Do not create a Cell in `build`. Move the cell to `initState`, a '
      '`State` field, or a top-level `final`. Creating a cell in `build` '
      'breaks hot reload and resets state on every rebuild.',
  errorSeverity: DiagnosticSeverity.WARNING,
);

/// The `Cell` factory names that create cells (or observation links).
const _factoryNames = {
  'state',
  'ingress',
  'derive',
  'governed',
  'fromFuture',
  'fromStream',
  'asyncMap',
  'switchMap',
};

/// The builder widgets whose `builder:` closures are build-scope.
const _builderWidgets = {'HookBuilder', 'CellBuilder'};

/// Detects `Cell.state` / `Cell.ingress` / `Cell.derive` / ... called
/// inside a `build` method, a `HookWidget`'s `build`, or a
/// `HookBuilder`/`CellBuilder` `builder:` closure.
class AvoidCellCreationInBuildRule extends DartLintRule {
  /// Creates the rule.
  AvoidCellCreationInBuildRule() : super(code: _code);

  /// Emits the lint for every node matching the anti-pattern.
  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (!_factoryNames.contains(node.methodName.name)) {
        return;
      }
      final target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Cell') {
        return;
      }
      if (!_isBuildScope(node)) {
        return;
      }
      reporter.atNode(node, _code);
    });
  }

  bool _isBuildScope(AstNode node) {
    final method = node.thisOrAncestorOfType<MethodDeclaration>();
    if (method != null && method.name.lexeme == 'build') {
      return true;
    }
    // The builder: closure of HookBuilder / CellBuilder is build scope.
    for (AstNode? current = node; current != null; current = current.parent) {
      if (current is! NamedExpression || current.name.label.name != 'builder') {
        continue;
      }
      final parent = current.parent;
      if (parent is! ArgumentList) {
        continue;
      }
      final creation = parent.parent;
      if (creation is InstanceCreationExpression) {
        final name = creation.constructorName.type.name.lexeme;
        if (_builderWidgets.contains(name)) {
          return true;
        }
      }
    }
    return false;
  }
}
