// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The assessment model: five orthogonal rubric categories.
library;

import '../brd/ast.dart';
import '../brd/design.dart';
import '../brd/walkthrough.dart';
import '../generator/generated_app.dart';
import 'categories.dart';

/// A single sub-check outcome.
enum CheckOutcome { pass, fail, notApplicable }

/// One sub-check result.
class CheckResult {
  const CheckResult({
    required this.id,
    required this.outcome,
    this.detail = '',
  });

  final String id;
  final CheckOutcome outcome;
  final String detail;

  bool get passed => outcome != CheckOutcome.fail;
}

/// A category aggregates its sub-checks.
class CategoryResult {
  const CategoryResult({
    required this.id,
    required this.name,
    required this.checks,
  });

  final String id;
  final String name;
  final List<CheckResult> checks;

  bool get applicable =>
      checks.any((c) => c.outcome != CheckOutcome.notApplicable);
  bool get passed => checks.every((c) => c.passed);
  List<CheckResult> get failures =>
      checks.where((c) => c.outcome == CheckOutcome.fail).toList();
}

enum AssessmentStatus { verified, notVerified }

/// The overall assessment of a generated app.
class Assessment {
  const Assessment({
    required this.status,
    required this.categories,
  });

  final AssessmentStatus status;
  final List<CategoryResult> categories;

  bool get verified => status == AssessmentStatus.verified;
  List<CategoryResult> get failures =>
      categories.where((c) => !c.passed && c.applicable).toList();

  String report() {
    final buffer = StringBuffer()
      ..writeln('Assessment: ${verified ? 'VERIFIED' : 'NOT_VERIFIED'}');
    for (final category in categories) {
      final statusLine = category.applicable
          ? (category.passed ? 'PASS' : 'FAIL')
          : 'NOT_APPLICABLE';
      buffer.writeln('  ${category.id}: $statusLine');
      for (final check in category.checks) {
        final line = switch (check.outcome) {
          CheckOutcome.pass => 'PASS',
          CheckOutcome.fail => 'FAIL',
          CheckOutcome.notApplicable => 'N/A ',
        };
        buffer.writeln(
            '    $line ${check.id}${check.detail.isEmpty ? '' : ' — ${check.detail}'}');
      }
    }
    return buffer.toString();
  }
}

/// Runs the five-category rubric over a generated app.
Assessment assess(
  Brd brd,
  Walkthrough walkthrough,
  Design design,
  GeneratedApp app,
) {
  final categories = evaluateCategories(brd, walkthrough, design, app);
  final verified = categories.every((c) => !c.applicable || c.passed);
  return Assessment(
    status: verified ? AssessmentStatus.verified : AssessmentStatus.notVerified,
    categories: categories,
  );
}
