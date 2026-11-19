// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The pipeline's failure types, mirroring `docs/failure-modes.md`.
///
/// Every failure carries a subtype, a message, a fix, and a
/// responsibility attribution. The Phase F test suite asserts each
/// fires with the documented content.
library;

/// Who is responsible for fixing a failure.
enum FailureResponsibility {
  /// The developer who wrote the BRD; the fix is in the BRD.
  brdAuthor,

  /// The pipeline has a bug or a rule gap; report it.
  pipelineMaintainer,

  /// The developer edited the generated app; the fix is in the app.
  appAuthor,
}

/// Base class for all pipeline failures.
abstract class PipelineFailure implements Exception {
  /// The failure type name (`SchemaValidationFailure`, …).
  String get type;

  /// The failure subtype name (`MissingSection`, `NoRuleMatches`, …).
  String get subtype;

  /// The actionable fix.
  String get fix;

  /// Who should fix it.
  FailureResponsibility get responsibility;

  /// The multi-line report shown by the CLI.
  String report() => '$type: $subtype\n'
      '  Reason: ${message.trim()}\n'
      '  Fix: ${fix.trim()}\n'
      '  Responsibility: ${_responsibilityLabel(responsibility)}';

  /// The documented label (`BRD_AUTHOR`, `PIPELINE_MAINTAINER`,
  /// `APP_AUTHOR`).
  String _responsibilityLabel(FailureResponsibility value) => switch (value) {
        FailureResponsibility.brdAuthor => 'BRD_AUTHOR',
        FailureResponsibility.pipelineMaintainer => 'PIPELINE_MAINTAINER',
        FailureResponsibility.appAuthor => 'APP_AUTHOR',
      };

  /// The human-readable reason.
  String get message;

  @override
  String toString() => report();
}

/// A single validation error aggregated into [SchemaValidationFailure].
class SchemaValidationError {
  const SchemaValidationError({
    required this.subtype,
    required this.location,
    required this.field,
    required this.reason,
    required this.fix,
  });

  final String subtype;
  final String location;
  final String? field;
  final String reason;
  final String fix;
}

/// The BRD is not well-formed. Responsibility: the BRD author.
class SchemaValidationFailure extends PipelineFailure {
  SchemaValidationFailure({
    required this.sourcePath,
    required this.errors,
  });

  final String sourcePath;
  final List<SchemaValidationError> errors;

  @override
  String get type => 'SchemaValidationFailure';

  @override
  String get subtype => errors.isEmpty ? 'Unknown' : errors.first.subtype;

  @override
  FailureResponsibility get responsibility => FailureResponsibility.brdAuthor;

  @override
  String get fix => errors.isEmpty ? 'Fix the BRD.' : errors.first.fix;

  @override
  String get message {
    final buffer = StringBuffer('BRD: $sourcePath\n');
    for (final error in errors) {
      buffer.writeln('  $type: ${error.subtype}');
      buffer.writeln('    Location: ${error.location}');
      if (error.field != null) {
        buffer.writeln('    Field: ${error.field}');
      }
      buffer.writeln('    Reason: ${error.reason}');
      buffer.writeln('    Fix: ${error.fix}');
    }
    return buffer.toString();
  }
}

/// The BRD is well-formed but a rule cannot place a requirement.
class UnplaceableSentence extends PipelineFailure {
  UnplaceableSentence({
    required this.subtype,
    required this.requirementId,
    required this.sentence,
    required this.reason,
    required this.fix,
    required this.responsibility,
  });

  @override
  final String subtype;

  final String requirementId;
  final String sentence;

  final String reason;

  @override
  final String fix;

  @override
  final FailureResponsibility responsibility;

  @override
  String get type => 'UnplaceableSentence';

  @override
  String get message => 'Requirement: $requirementId\n'
      '  Sentence: "$sentence"\n'
      '  Reason: $reason';
}

/// The generated (or hand-edited) code violates an anti-pattern.
class RuleViolation extends PipelineFailure {
  RuleViolation({
    required this.subtype,
    required this.ruleId,
    required this.file,
    required this.line,
    required this.reason,
    required this.fix,
    required this.responsibility,
  });

  @override
  final String subtype;

  final String ruleId;
  final String file;
  final int? line;

  final String reason;

  @override
  final String fix;

  @override
  final FailureResponsibility responsibility;

  @override
  String get type => 'RuleViolation';

  @override
  String get message =>
      'File: $file${line == null ? '' : ':$line'}\n  Reason: $reason';
}

/// The generated app violates a top-level structural rule.
class StructuralInvariantFailure extends PipelineFailure {
  StructuralInvariantFailure({
    required this.subtype,
    required this.file,
    required this.reason,
    required this.fix,
    required this.responsibility,
  });

  @override
  final String subtype;

  final String file;

  final String reason;

  @override
  final String fix;

  @override
  final FailureResponsibility responsibility;

  @override
  String get type => 'StructuralInvariantFailure';

  @override
  String get message => 'File: $file\n  Reason: $reason';
}
