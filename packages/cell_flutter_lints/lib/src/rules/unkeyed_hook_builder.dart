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
  name: 'cell_unkeyed_hook_builder',
  problemMessage: 'HookBuilder observes a cell that can be swapped. Key the '
      'HookBuilder on the cell (`key: ValueKey(cell)`) so hook state '
      'resets between cells. Without a key, the hook will flash the '
      'previous cell\'s value for one frame.',
  errorSeverity: DiagnosticSeverity.WARNING,
);

const _hookObservers = {
  'useCell',
  'useCellValue',
  'useCellAsync',
  'useCellNotifier',
};

/// Detects a `HookBuilder` without a `key` argument whose `builder:`
/// closure passes a **field** of the enclosing widget class (a cell that
/// can be swapped) to a `useCell*` hook. Restricted to the field case by
/// design — the general data-flow detection is too noisy.
class UnkeyedHookBuilderRule extends DartLintRule {
  /// Creates the rule.
  UnkeyedHookBuilderRule() : super(code: _code);

  /// Emits the lint for every node matching the anti-pattern.
  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      if (node.constructorName.type.name.lexeme != 'HookBuilder') {
        return;
      }
      final arguments = node.argumentList.arguments;
      final hasKey = arguments.any(
        (a) => a is NamedExpression && a.name.label.name == 'key',
      );
      if (hasKey) {
        return;
      }
      final builderArg = arguments.whereType<NamedExpression>().where(
            (a) => a.name.label.name == 'builder',
          );
      if (builderArg.isEmpty) {
        return;
      }
      final enclosingClass = node.thisOrAncestorOfType<ClassDeclaration>();
      final fieldNames = enclosingClass == null
          ? const <String>{}
          : <String>{
              for (final member in enclosingClass.members)
                if (member is FieldDeclaration)
                  for (final variable in member.fields.variables)
                    variable.name.lexeme,
            };
      final visitor = _FieldHookObserver(fieldNames);
      builderArg.first.expression.accept(visitor);
      if (!visitor.found) {
        return;
      }
      reporter.atNode(node, _code);
    });
  }
}

class _FieldHookObserver extends RecursiveAstVisitor<void> {
  _FieldHookObserver(this.fieldNames);

  final Set<String> fieldNames;
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _check(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    _check(node);
    super.visitFunctionExpressionInvocation(node);
  }

  void _check(InvocationExpression node) {
    if (found) {
      return;
    }
    final function = node.function;
    final name = function is SimpleIdentifier ? function.name : null;
    if (name == null || !_hookObservers.contains(name)) {
      return;
    }
    var argument = node.argumentList.arguments.firstOrNull;
    if (argument is NamedExpression) {
      argument = argument.expression;
    }
    // `useCellValue(cell ?? fallback)` — the observed cell is the
    // left-hand side of a null-coalescing expression.
    if (argument is BinaryExpression && argument.operator.lexeme == '??') {
      argument = argument.leftOperand;
    }
    if (argument is SimpleIdentifier && fieldNames.contains(argument.name)) {
      found = true;
    }
  }
}
