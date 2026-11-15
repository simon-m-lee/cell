// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// ### When to use
/// The declared purpose above names the entry point; this
/// section pins its prerequisites and its place in the pipeline.
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// The output format for [DecisionPath.toNarrative].
///
/// {@category Organ}
/// {@category XAI}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
enum NarrativeTemplate {
  /// Full detail, all metadata, timestamped. For audit logs.
  audit,

  /// Concise, human-facing, no ids. For UI surfaces.
  ui,

  /// Structured, machine-parseable, developer-oriented. For debug.
  debug,
}

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// A read-only projection of a [Decision] for narrative and audit.
///
/// ### When to use
/// Read from [explain], [explainPulse], or [explainSource]. The path
/// carries the decision's full metadata in a form suitable for audit,
/// UI, or debug output.
///
/// ### Non-obvious
/// - **Not a chain.** A single `DecisionPath` wraps one decision. For
///   chains, query `handle.decisions` directly.
/// - **Null accessors for action decisions.** `actor`, `strategy`,
///   `confidence`, etc. return `null` when the decision has no pulse.
///
/// {@category Organ}
/// {@category XAI}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class DecisionPath {
  /// The wrapped decision — the source of truth.
  final Decision decision;

  const DecisionPath(this.decision);

  String get id => decision.id;
  DateTime get at => decision.at;
  Context get context => decision.context;
  String get contextVersion => decision.contextVersion;
  Pulse? get pulse => decision.pulse;
  ApplyCommand? get command => decision.command;
  Verdict get verdict => decision.verdict;
  String? get policyVersion => decision.policyVersion;
  Duration? get evaluationTime => decision.evaluationTime;

  // Derived accessors — null when the decision has no pulse.
  String? get actor => decision.pulse?.context.actor;
  ReasoningStrategy? get strategy => decision.pulse?.context.strategy;
  double? get confidence => decision.pulse?.context.confidence;
  String? get purpose => decision.pulse?.context.purpose;
  String? get reason => decision.pulse?.context.reason;
  String? get compliance => decision.pulse?.context.compliance;
  Sensitivity? get sensitivity => decision.pulse?.context.sensitivity;
  AuditLevel? get auditLevel => decision.pulse?.context.auditLevel;
  String? get traceId => decision.pulse?.context.traceId;

  /// Renders this decision in the given [template].
  ///
  /// - `audit`: timestamped, full metadata — replay-ready.
  /// - `ui`: human-facing, no ids.
  /// - `debug`: structured, developer-oriented.
  String toNarrative({NarrativeTemplate template = NarrativeTemplate.audit}) =>
      _renderNarrative(this, template);
}

/// ### When to use
/// The declared purpose above names the entry point; this
/// section pins its prerequisites and its place in the pipeline.
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Wraps a [Decision] in a [DecisionPath].
///
/// {@category Organ}
/// {@category XAI}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
DecisionPath explain(Decision decision) => DecisionPath(decision);

/// ### When to use
/// The declared purpose above names the entry point; this
/// section pins its prerequisites and its place in the pipeline.
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Finds the [Decision] that produced [pulse] in [handle]'s log.
///
/// Returns `null` if no matching decision is found (e.g., the pulse was
/// never routed through the handle).
///
/// ### Matching
/// Matches by `pulse.context.traceId`, not identity. Evolved pulses
/// share their root's trace id, so descendant pulses find the same
/// decision. The scan is most-recent-first; the first match wins.
///
/// {@category Organ}
/// {@category XAI}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
DecisionPath? explainPulse(Pulse pulse, CognitiveHandle handle) {
  final traceId = pulse.context.traceId;
  if (traceId == null) return null;
  for (final decision in handle.decisions.reversed) {
    if (decision.pulse != null && decision.pulse!.context.traceId == traceId) {
      return DecisionPath(decision);
    }
  }
  return null;
}

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Returns all [DecisionPath]s whose `pulse.source.id` matches
/// [source]'s id.
///
/// ### When to use
/// Works for any `Cell` with an `id` — value cells, ingress cells,
/// and `cell_organ` Blends. There is no `cell_organ` dependency.
///
/// ### Non-obvious
/// - **`pulse.source` is the emitter**, not the receiver. A pulse
///   forwarded through many cells keeps its original source.
///
/// {@category Organ}
/// {@category XAI}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
List<DecisionPath> explainSource(Cell source, CognitiveHandle handle) => [
      for (final decision in handle.decisions)
        if (decision.pulse != null && decision.pulse!.source?.id == source.id)
          DecisionPath(decision),
    ];

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Minimal abstraction over a tracing backend. Wrap your SDK.
///
/// ### When to use
/// Provide an implementation to [otelSpans]. `cell_mind` has no OTel
/// SDK dependency — wrap `opentelemetry`, `dart_otel`, or a custom
/// backend in a small adapter (see `guide/07-XAI.md`).
///
/// {@category Organ}
/// {@category XAI}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
abstract interface class Tracer {
  Span startSpan(String name, {SpanContext? parent, DateTime? startTime});
  SpanContext get currentContext;
}

/// ### When to use
/// The declared purpose above names the entry point; this
/// section pins its prerequisites and its place in the pipeline.
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// A span produced by [otelSpans] (or a user tracer).
///
/// {@category Organ}
/// {@category XAI}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
abstract interface class Span {
  void setAttribute(String key, Object? value);
  void setStatus(SpanStatus status);
  void end();
}

/// ### When to use
/// The declared purpose above names the entry point; this
/// section pins its prerequisites and its place in the pipeline.
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Identifies a span within a trace.
///
/// {@category Organ}
/// {@category XAI}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
abstract interface class SpanContext {
  String get traceId;
  String get spanId;
}

/// ### When to use
/// The declared purpose above names the entry point; this
/// section pins its prerequisites and its place in the pipeline.
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Span status — the verdict maps to [ok] / [error].
///
/// {@category Organ}
/// {@category XAI}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
enum SpanStatus { ok, error, unset }

/// ### When to use
/// The declared purpose above names the entry point; this
/// section pins its prerequisites and its place in the pipeline.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Converts a decision log into OTel-compatible spans.
///
/// ### How it works
/// 1. Walks [decisions] in causal order (sorted by `at`).
/// 2. For each, starts a span named by [spanName] (default
///    `'mind.decision'`).
/// 3. The parent is the decision whose `traceId` matches the current
///    decision's `pulse.context.parentTraceId`; orphans become roots.
/// 4. Attaches attributes: `mind.actor`, `mind.strategy`,
///    `mind.confidence`, `mind.verdict.type`, `mind.context.version`,
///    `mind.evaluationTime.micros` — plus [extraAttributes].
/// 5. Sets the status (`ok` for Accept, `error` for Reject) and ends
///    each span. Returns the spans for inspection.
///
/// {@category Organ}
/// {@category XAI}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
List<Span> otelSpans(
  Iterable<Decision> decisions, {
  required Tracer tracer,
  String Function(Decision)? spanName,
  Map<String, Object?> Function(Decision)? extraAttributes,
}) {
  final sorted = decisions.toList()..sort((a, b) => a.at.compareTo(b.at));
  final spans = <Span>[];
  final spanByTrace = <String, SpanContext>{};
  for (final decision in sorted) {
    final traceId = decision.pulse?.context.traceId;
    final parentTraceId = decision.pulse?.context.parentTraceId;
    final parent = parentTraceId == null ? null : spanByTrace[parentTraceId];
    final span = tracer.startSpan(
      spanName?.call(decision) ?? 'mind.decision',
      parent: parent,
      startTime: decision.at,
    );
    final pulse = decision.pulse;
    span.setAttribute('mind.verdict.type', decision.verdict.type);
    span.setAttribute('mind.context.version', decision.contextVersion);
    if (pulse != null) {
      span.setAttribute('mind.actor', pulse.context.actor);
      span.setAttribute('mind.strategy', pulse.context.strategy?.name);
      span.setAttribute('mind.confidence', pulse.context.confidence);
    }
    final eval = decision.evaluationTime;
    if (eval != null) {
      span.setAttribute('mind.evaluationTime.micros', eval.inMicroseconds);
    }
    extraAttributes?.call(decision).forEach(span.setAttribute);
    span.setStatus(
      decision.verdict is Accept ? SpanStatus.ok : SpanStatus.error,
    );
    span.end();
    spans.add(span);
    if (traceId != null) {
      spanByTrace[traceId] = tracer.currentContext;
    }
  }
  return spans;
}
