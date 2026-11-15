// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';

/// Benchmark: XAI narrative and span construction cost.
///
/// Run with:
/// ```bash
/// dart run benchmark/micro/xai_cost.dart
/// ```
Future<void> main() async {
  final context = Context.fromEntries([Ontology.domains.entry('finance')]);
  final gate = Cell.ingress<int>(context: context);
  final handle = cognitive(cell: gate.cell);
  for (var i = 0; i < 100; i++) {
    gate.emit(i);
  }
  await Future<void>.delayed(Duration.zero);
  final decisions = handle.decisions.where((d) => d.pulse != null).toList();

  final stopwatch = Stopwatch()..start();
  const loops = 100;
  for (var i = 0; i < loops; i++) {
    for (final decision in decisions) {
      DecisionPath(decision).toNarrative();
      DecisionPath(decision).toNarrative(template: NarrativeTemplate.ui);
      DecisionPath(decision).toNarrative(template: NarrativeTemplate.debug);
    }
  }
  stopwatch.stop();
  print('XAI narrative cost: '
      '${(loops * decisions.length * 1000000 / stopwatch.elapsedMicroseconds).toStringAsFixed(0)} '
      'narratives/s');

  final tracer = _CountingTracer();
  final stopwatch2 = Stopwatch()..start();
  for (var i = 0; i < loops; i++) {
    otelSpans(decisions, tracer: tracer);
  }
  stopwatch2.stop();
  print('XAI span cost: '
      '${(loops * decisions.length * 1000000 / stopwatch2.elapsedMicroseconds).toStringAsFixed(0)} '
      'spans/s');
}

final class _CountingSpan implements Span {
  @override
  void setAttribute(String key, Object? value) {}

  @override
  void setStatus(SpanStatus status) {}

  @override
  void end() {}
}

final class _CountingContext implements SpanContext {
  @override
  final String traceId = 't';
  @override
  final String spanId = 's';
}

final class _CountingTracer implements Tracer {
  @override
  Span startSpan(String name, {SpanContext? parent, DateTime? startTime}) =>
      _CountingSpan();

  @override
  SpanContext get currentContext => _CountingContext();
}
