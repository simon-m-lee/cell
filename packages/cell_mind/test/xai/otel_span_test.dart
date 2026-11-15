// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

final class _TestSpan implements Span {
  final String name;
  final SpanContext? parent;
  final DateTime? startTime;
  final Map<String, Object?> attributes = {};
  SpanStatus status = SpanStatus.unset;
  bool ended = false;

  _TestSpan(this.name, {this.parent, this.startTime});

  @override
  void setAttribute(String key, Object? value) => attributes[key] = value;

  @override
  void setStatus(SpanStatus value) => status = value;

  @override
  void end() => ended = true;
}

final class _TestContext implements SpanContext {
  @override
  final String traceId;
  @override
  final String spanId;
  _TestContext(this.traceId, this.spanId);
}

final class _TestTracer implements Tracer {
  final List<_TestSpan> spans = [];
  _TestContext _current = _TestContext('trace-0', 'span-0');

  @override
  Span startSpan(String name, {SpanContext? parent, DateTime? startTime}) {
    final span = _TestSpan(name, parent: parent, startTime: startTime);
    spans.add(span);
    _current = _TestContext('trace-0', 'span-${spans.length}');
    return span;
  }

  @override
  SpanContext get currentContext => _current;
}

Decision decision({
  required String id,
  required DateTime at,
  Verdict verdict = const Accept(),
  String? traceId,
  String? parentTraceId,
}) =>
    Decision(
      id: id,
      at: at,
      context: Context.system,
      contextVersion: '1.0.0',
      verdict: verdict,
      pulse: Pulse<int>.governed(
        payload: 42,
        context: PulseContext.fromEntries([
          Provenance.actor.entry('agent-a'),
          Provenance.confidence.entry(0.9),
          Provenance.strategy.entry(ReasoningStrategy.probabilistic),
          if (traceId != null) Provenance.traceId.entry(traceId),
          if (parentTraceId != null)
            Provenance.parentTraceId.entry(parentTraceId),
        ]),
      ),
      evaluationTime: const Duration(milliseconds: 3),
    );

void main() {
  group('otelSpans', () {
    test('produces one span per decision in causal order', () {
      final tracer = _TestTracer();
      final spans = otelSpans(
        [
          decision(id: 'd-2', at: DateTime.utc(2026, 11, 15, 10, 2)),
          decision(id: 'd-1', at: DateTime.utc(2026, 11, 15, 10, 1)),
        ],
        tracer: tracer,
      );
      expect(spans, hasLength(2));
      expect(tracer.spans.map((s) => s.startTime), [
        DateTime.utc(2026, 11, 15, 10, 1),
        DateTime.utc(2026, 11, 15, 10, 2),
      ]);
      expect(tracer.spans.every((s) => s.name == 'mind.decision'), isTrue);
    });

    test('attaches the mind.* attributes', () {
      final tracer = _TestTracer();
      otelSpans(
        [decision(id: 'd-1', at: DateTime.utc(2026), traceId: 't-1')],
        tracer: tracer,
      );
      final span = tracer.spans.single;
      expect(span.attributes['mind.actor'], 'agent-a');
      expect(span.attributes['mind.strategy'], 'probabilistic');
      expect(span.attributes['mind.confidence'], 0.9);
      expect(span.attributes['mind.verdict.type'], 'accept');
      expect(span.attributes['mind.context.version'], '1.0.0');
      expect(span.attributes['mind.evaluationTime.micros'], 3000);
    });

    test('rejects map to error status and accepts to ok', () {
      final tracer = _TestTracer();
      otelSpans(
        [
          decision(id: 'd-1', at: DateTime.utc(2026)),
          decision(
            id: 'd-2',
            at: DateTime.utc(2026, 11, 15, 0, 0, 1),
            verdict: const Reject('blocked'),
          ),
        ],
        tracer: tracer,
      );
      expect(tracer.spans[0].status, SpanStatus.ok);
      expect(tracer.spans[1].status, SpanStatus.error);
    });

    test('reconstructs parent/child from parentTraceId', () {
      final tracer = _TestTracer();
      otelSpans(
        [
          decision(id: 'root', at: DateTime.utc(2026), traceId: 't-root'),
          decision(
            id: 'child',
            at: DateTime.utc(2026, 11, 15, 0, 0, 1),
            traceId: 't-child',
            parentTraceId: 't-root',
          ),
        ],
        tracer: tracer,
      );
      expect(tracer.spans[0].parent, isNull);
      expect(tracer.spans[1].parent, isNotNull,
          reason: 'The child links to the root span context.');
    });

    test('orphans become roots', () {
      final tracer = _TestTracer();
      otelSpans(
        [
          decision(
            id: 'orphan',
            at: DateTime.utc(2026),
            traceId: 't-orphan',
            parentTraceId: 'missing',
          ),
        ],
        tracer: tracer,
      );
      expect(tracer.spans.single.parent, isNull);
    });

    test('spanName and extraAttributes overrides apply', () {
      final tracer = _TestTracer();
      otelSpans(
        [decision(id: 'd-1', at: DateTime.utc(2026))],
        tracer: tracer,
        spanName: (d) => 'custom.${d.id}',
        extraAttributes: (d) => {'custom.key': d.id},
      );
      final span = tracer.spans.single;
      expect(span.name, 'custom.d-1');
      expect(span.attributes['custom.key'], 'd-1');
    });

    test('every span is ended', () {
      final tracer = _TestTracer();
      otelSpans(
        [decision(id: 'd-1', at: DateTime.utc(2026))],
        tracer: tracer,
      );
      expect(tracer.spans.single.ended, isTrue);
    });
  });
}
