// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The agent transcript model.
///
/// Every message is produced by the scripted agent from the *real*
/// outcome of a membrane call — only the pacing and the wording are
/// scripted.
library;

import 'package:cell/cell.dart';

/// One discovered tool in the agent's `tools/list` view.
final class ToolDescriptor {
  /// `<cellId>.<functionName>`.
  final String name;

  /// A human-readable argument summary derived from the manifest.
  final String argumentSummary;

  const ToolDescriptor({required this.name, required this.argumentSummary});
}

/// The severity of a call result.
enum OutcomeKind {
  accepted,
  rejected,
  staged,
  committed,
}

/// A message in the agent transcript.
sealed class AgentMessage {
  /// Monotonic id for stable widget keys.
  final int id;

  const AgentMessage({required this.id});
}

/// The agent is thinking — rendered with a typing indicator.
final class AgentThinking extends AgentMessage {
  final String text;

  const AgentThinking({required super.id, required this.text});
}

/// The agent discovered the tool catalogue.
final class AgentToolsDiscovered extends AgentMessage {
  final List<ToolDescriptor> tools;

  const AgentToolsDiscovered({required super.id, required this.tools});
}

/// The agent is about to call a function.
final class AgentCalling extends AgentMessage {
  final String signature;

  const AgentCalling({required super.id, required this.signature});
}

/// The real result of a membrane call.
final class AgentCallResult extends AgentMessage {
  final String label;
  final OutcomeKind kind;

  /// The framework's own rejection reason, when one was produced.
  final String? reason;

  const AgentCallResult({
    required super.id,
    required this.label,
    required this.kind,
    this.reason,
  });
}

/// The task summary.
final class AgentTaskComplete extends AgentMessage {
  final String text;

  const AgentTaskComplete({required super.id, required this.text});
}

/// The rejection label: the framework's verbatim reason when present,
/// otherwise the demo's honest explanation of the gate that fired.
String rejectionLabel(ApplyRejected<Object?> outcome) =>
    outcome.reason?.toString() ?? 'integrity gate';

/// Renders an [ApplyOutcome] into the badge label shown in the agent
/// pane. The words come from the outcome; nothing is invented.
String outcomeLabel(ApplyOutcome<Object?> outcome) => switch (outcome) {
      ApplyAccepted<Object?>() => 'ACCEPTED',
      ApplyRejected<Object?>() => 'REJECTED',
      ApplyStaged() => 'STAGED',
    };
