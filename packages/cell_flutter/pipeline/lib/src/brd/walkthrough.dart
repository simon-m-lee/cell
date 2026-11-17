// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The walkthrough — a human-reviewable per-requirement plan (Gate 1).
library;

import '../brd/ast.dart';

/// The walkthrough of a BRD.
class Walkthrough {
  const Walkthrough({
    required this.title,
    required this.steps,
    this.schemaVersion = 'flutter-pipeline/v1',
  });

  final String title;
  final List<WalkthroughStep> steps;
  final String schemaVersion;

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Walkthrough: $title')
      ..writeln()
      ..writeln('**Schema:** $schemaVersion')
      ..writeln('**Requirements:** ${steps.length}')
      ..writeln('**Screens:** ${steps.map((s) => s.screen).toSet().length}')
      ..writeln();
    for (final step in steps) {
      buffer
        ..writeln('## ${step.requirementId} — ${step.description}')
        ..writeln('- **Type:** ${step.type.name}')
        ..writeln('- **Screen:** ${step.screen}')
        ..writeln('- **Widget:** ${step.widget} (${step.widgetDetails})');
      if (step.trigger != null) {
        buffer.writeln('- **Trigger:** ${step.trigger}');
      }
      buffer
        ..writeln('- **Assertion:** `${step.assertion}`')
        ..writeln('- **LEDGER:** `${step.ledger}`')
        ..writeln();
    }
    return buffer.toString();
  }
}

/// A single step in the walkthrough.
class WalkthroughStep {
  const WalkthroughStep({
    required this.requirementId,
    required this.type,
    required this.screen,
    required this.description,
    required this.widget,
    required this.widgetDetails,
    required this.trigger,
    required this.assertion,
    required this.ledger,
  });

  final String requirementId;
  final RequirementType type;
  final String screen;
  final String description;
  final String widget;
  final String widgetDetails;
  final String? trigger;
  final String assertion;
  final String ledger;
}
