// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered cookbook test names.
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  test('recipe 15: XAI compliance report', () async {
    final gate = Cell.ingress<int>(
      context: Context.fromEntries([Ontology.domains.entry('finance')]),
    );
    final handle = cognitive(cell: gate.cell);
    final pulse = Pulse<int>.governed(
      payload: 42,
      source: gate.cell,
      context: PulseContext.fromEntries([
        Provenance.actor.entry('agent-a'),
        Provenance.reason.entry('compliance-report'),
        Provenance.confidence.entry(0.93),
        Provenance.strategy.entry(ReasoningStrategy.probabilistic),
        Provenance.traceId.entry('trace-15'),
        Ontology.domains.entry('finance'),
      ]),
    );
    await gate.ingest(pulse);
    await Future<void>.delayed(Duration.zero);
    final path = explainPulse(pulse, handle);
    expect(path, isNotNull);
    final narrative = path!.toNarrative();
    expect(narrative, contains('ACCEPT'));
    expect(narrative, contains('agent-a'));
    expect(narrative, contains('probabilistic'));
    final tracer = _Tracer();
    final spans = otelSpans(
      handle.decisions.where((d) => d.pulse != null),
      tracer: tracer,
    );
    expect(spans, hasLength(1));
    expect(tracer.spans.single.attributes['mind.actor'], 'agent-a');
  });
}

final class _Span implements Span {
  final Map<String, Object?> attributes = {};
  @override
  void setAttribute(String key, Object? value) => attributes[key] = value;
  @override
  void setStatus(SpanStatus status) {}
  @override
  void end() {}
}

final class _Context implements SpanContext {
  @override
  final String traceId = 't';
  @override
  final String spanId = 's';
}

final class _Tracer implements Tracer {
  final spans = <_Span>[];
  @override
  Span startSpan(String name, {SpanContext? parent, DateTime? startTime}) {
    final span = _Span();
    spans.add(span);
    return span;
  }

  @override
  SpanContext get currentContext => _Context();
}
