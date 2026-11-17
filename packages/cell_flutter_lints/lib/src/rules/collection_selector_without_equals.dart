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
  name: 'cell_collection_selector_without_equals',
  problemMessage:
      'CellSelector / useCell with a collection-returning `select` and no '
      '`equals` will rebuild on every emission, even when the content is '
      'equal. Provide `equals: listEquals` / `setEquals` / `mapEquals`.',
  errorSeverity: DiagnosticSeverity.WARNING,
);

const _collectionTypes = {
  'List',
  'Set',
  'Map',
  'Iterable',
  'Collection',
};

/// Detects `CellSelector<T, S>` and `useCell<T, S>` where `S` is a
/// collection type and no `equals` argument is provided.
class CollectionSelectorWithoutEqualsRule extends DartLintRule {
  /// Creates the rule.
  CollectionSelectorWithoutEqualsRule() : super(code: _code);

  /// Emits the lint for every node matching the anti-pattern.
  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      if (node.constructorName.type.name.lexeme != 'CellSelector') {
        return;
      }
      if (_hasCollectionSlice(node.constructorName.type) &&
          !_hasEquals(node.argumentList)) {
        reporter.atNode(node, _code);
      }
    });

    // `useCell` is a top-level function; depending on the parser's
    // representation it may surface as a FunctionExpressionInvocation or
    // a target-less MethodInvocation, so both hooks are registered.
    void checkFunction(Expression function, TypeArgumentList? typeArguments,
        ArgumentList argumentList, AstNode node) {
      if (function is! SimpleIdentifier || function.name != 'useCell') {
        return;
      }
      if (_hasCollectionSliceTypeArguments(typeArguments) &&
          !_hasEquals(argumentList)) {
        reporter.atNode(node, _code);
      }
    }

    context.registry.addFunctionExpressionInvocation((node) {
      checkFunction(node.function, node.typeArguments, node.argumentList, node);
    });

    context.registry.addMethodInvocation((node) {
      if (node.target != null) {
        return;
      }
      checkFunction(
          node.methodName, node.typeArguments, node.argumentList, node);
    });
  }

  bool _hasCollectionSlice(NamedType type) {
    final arguments = type.typeArguments?.arguments;
    if (arguments == null || arguments.length < 2) {
      return false;
    }
    return _isCollectionName(arguments[1].toSource());
  }

  bool _hasCollectionSliceTypeArguments(TypeArgumentList? typeArguments) {
    final arguments = typeArguments?.arguments;
    if (arguments == null || arguments.length < 2) {
      return false;
    }
    return _isCollectionName(arguments[1].toSource());
  }

  bool _isCollectionName(String source) {
    final base = source.split('<').first.trim();
    return _collectionTypes.contains(base);
  }

  bool _hasEquals(ArgumentList arguments) => arguments.arguments.any(
        (a) => a is NamedExpression && a.name.label.name == 'equals',
      );
}
