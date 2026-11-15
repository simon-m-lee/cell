// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered example file names; the numeric
// prefix is intentional (08_xai_audit → example #8).
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';

/// XAI audit demo — narratives and spans from a decision log.
///
/// Run with:
/// ```bash
/// dart run example/08_xai_audit.dart
/// ```
Future<void> main() async {
  print('=== XAI audit demo ===');
  print('');

  final gate = Cell.ingress<int>(
    context: Context.fromEntries([Ontology.domains.entry('finance')]),
  );
  final handle = cognitive(
    cell: gate.cell,
    policy: predicatePolicy((object, {required host}) {
      if (object is! Pulse) return true;
      return (object.payload as int) < 100;
    }),
  );

  // Traffic: one accepted, one rejected.
  await gate.ingest(Pulse<int>.governed(
    payload: 50,
    source: gate.cell,
    context: PulseContext.fromEntries([
      Provenance.actor.entry('agent-a'),
      Provenance.reason.entry('small'),
      Provenance.confidence.entry(0.95),
      Provenance.strategy.entry(ReasoningStrategy.probabilistic),
      Provenance.traceId.entry('trace-small'),
    ]),
  ));
  await gate.ingest(Pulse<int>.governed(
    payload: 500,
    source: gate.cell,
    context: PulseContext.fromEntries([
      Provenance.actor.entry('agent-a'),
      Provenance.reason.entry('large'),
      Provenance.confidence.entry(0.8),
      Provenance.strategy.entry(ReasoningStrategy.probabilistic),
      Provenance.traceId.entry('trace-large'),
    ]),
  ));
  await Future<void>.delayed(Duration.zero);

  // 1. Narratives in all three templates.
  print('--- Narratives ---');
  for (final decision in handle.decisions.where((d) => d.pulse != null)) {
    final path = DecisionPath(decision);
    print('audit: ${path.toNarrative()}');
    print('  ui:  ${path.toNarrative(template: NarrativeTemplate.ui)}');
    print('debug: ${path.toNarrative(template: NarrativeTemplate.debug)}');
  }

  // 2. Explain a specific pulse.
  print('');
  print('--- explainPulse ---');
  final path = explainPulse(
    Pulse<int>.governed(
      payload: 500,
      context: PulseContext.fromEntries([
        Provenance.traceId.entry('trace-large'),
      ]),
    ),
    handle,
  );
  print(path == null
      ? '  (no matching decision)'
      : '  ${path.toNarrative(template: NarrativeTemplate.ui)}');

  // 3. Explain by source.
  print('');
  print('--- explainSource ---');
  final paths = explainSource(gate.cell, handle);
  print('  ${paths.length} decision(s) emitted by the gate:');
  for (final p in paths) {
    print('    payload=${p.pulse?.payload} verdict=${p.verdict.type}');
  }

  // 4. OTel-style spans via the abstract tracer.
  print('');
  print('--- otelSpans ---');
  final tracer = _PrintTracer();
  otelSpans(handle.decisions.where((d) => d.pulse != null), tracer: tracer);
  for (final span in tracer.spans) {
    print('  ${span.name}: ${span.attributes} status=${span.status}');
  }

  print('');
  print('=== Done ===');
}

final class _PrintSpan implements Span {
  final String name;
  final SpanContext? parent;
  final Map<String, Object?> attributes = {};
  SpanStatus status = SpanStatus.unset;

  _PrintSpan(this.name, {this.parent});

  @override
  void setAttribute(String key, Object? value) => attributes[key] = value;

  @override
  void setStatus(SpanStatus value) => status = value;

  @override
  void end() {}
}

final class _PrintContext implements SpanContext {
  @override
  final String traceId;
  @override
  final String spanId;
  _PrintContext(this.traceId, this.spanId);
}

final class _PrintTracer implements Tracer {
  final List<_PrintSpan> spans = [];
  _PrintContext _current = _PrintContext('demo-trace', 'span-0');

  @override
  Span startSpan(String name, {SpanContext? parent, DateTime? startTime}) {
    final span = _PrintSpan(name, parent: parent);
    spans.add(span);
    _current = _PrintContext('demo-trace', 'span-${spans.length}');
    return span;
  }

  @override
  SpanContext get currentContext => _current;
}
