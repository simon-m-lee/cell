// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

const _code = LintCode(
  name: 'cell_forgotten_dispose',
  problemMessage:
      'The return of `asValueCell` / `recordPulses` must be disposed. '
      'Store it in a field and call `dispose` / `stop` in `State.dispose` '
      '(or a `useEffect` cleanup in hooks).',
  errorSeverity: DiagnosticSeverity.WARNING,
);

const _observedFactories = {'asValueCell', 'recordPulses'};

const _releaseMethods = {'dispose', 'stop'};

/// Detects `field = cell.asValueCell(...)` / `field = cell.recordPulses()`
/// in a class with no matching `field.dispose()` / `field.stop()` in its
/// `dispose` method. Structural, name-based check by design: false
/// negatives are acceptable, false positives are not.
///
/// Known limitation: `HookWidget` cleanup (`useEffect` return closures)
/// is not analyzed — the rule targets `State` fields.
class ForgottenCellDisposeRule extends DartLintRule {
  /// Creates the rule.
  ForgottenCellDisposeRule() : super(code: _code);

  /// Emits the lint for every node matching the anti-pattern.
  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    void check(String name, Expression? initializer, AstNode node) {
      if (initializer is! MethodInvocation) {
        return;
      }
      if (!_observedFactories.contains(initializer.methodName.name)) {
        return;
      }
      if (initializer.target == null) {
        return;
      }
      final klass = node.thisOrAncestorOfType<ClassDeclaration>();
      if (klass == null) {
        return;
      }
      final isField = klass.members.whereType<FieldDeclaration>().any(
            (member) => member.fields.variables
                .any((variable) => variable.name.lexeme == name),
          );
      if (!isField) {
        return;
      }
      final dispose = klass.members
          .whereType<MethodDeclaration>()
          .where((m) => m.name.lexeme == 'dispose')
          .firstOrNull;
      if (dispose == null) {
        reporter.atNode(node, _code);
        return;
      }
      if (!_isReleasedIn(dispose, name)) {
        reporter.atNode(node, _code);
      }
    }

    context.registry.addAssignmentExpression((node) {
      final left = node.leftHandSide;
      if (left is! SimpleIdentifier) {
        return;
      }
      check(left.name, node.rightHandSide, node);
    });

    // Field initializers (`ValueCell<int>? mirror = cell.asValueCell();`)
    // are VariableDeclarations, not AssignmentExpressions.
    context.registry.addVariableDeclaration((node) {
      if (node.initializer == null) {
        return;
      }
      check(node.name.lexeme, node.initializer, node);
    });
  }

  bool _isReleasedIn(MethodDeclaration dispose, String fieldName) {
    final visitor = _ReleaseFinder(fieldName);
    dispose.body.accept(visitor);
    return visitor.found;
  }
}

class _ReleaseFinder extends RecursiveAstVisitor<void> {
  _ReleaseFinder(this.fieldName);

  final String fieldName;
  bool found = false;

  @override
  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (!found) {
      final function = node.function;
      if (function is PropertyAccess &&
          function.target is SimpleIdentifier &&
          (function.target as SimpleIdentifier).name == fieldName &&
          _releaseMethods.contains(function.propertyName.name)) {
        found = true;
      }
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!found) {
      final target = node.target;
      if (target is SimpleIdentifier &&
          target.name == fieldName &&
          _releaseMethods.contains(node.methodName.name)) {
        found = true;
      }
    }
    super.visitMethodInvocation(node);
  }
}
