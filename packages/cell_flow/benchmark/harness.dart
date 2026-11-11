// Shared fixtures for the cell_flow benchmark suite.
//
// Every benchmark goes through these helpers so a "3-stage map" means the
// same thing everywhere.
library;

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';

/// A materialized pipeline plus its emit entry point, terminal, and a
/// counter sink.
typedef FlowBench = ({
  bool Function(dynamic input) emit,
  Cell terminal,
  int Function() emitted,
  void Function() reset,
});

/// A `map → map → ...` chain of [depth] stages on top of a fresh ingress.
/// The sink is a plain `Cell.observe` counter so we never measure logging.
FlowBench buildMapChain(int depth) {
  final gate = Cell.ingress<int>();
  var handle = Flow.map<int, int>(gate.cell, project: (v) => v + 1);
  for (var i = 1; i < depth; i++) {
    handle = Flow.map<int, int>(handle.cell, project: (v) => v + 1);
  }
  return _withSink(handle.emit, handle.cell);
}

/// A `filter(always true) → ...` chain of [depth] stages.
FlowBench buildFilterChain(int depth) {
  final gate = Cell.ingress<int>();
  var handle = Flow.filter<int>(gate.cell, test: (v) => true);
  for (var i = 1; i < depth; i++) {
    handle = Flow.filter<int>(handle.cell, test: (v) => true);
  }
  return _withSink(handle.emit, handle.cell);
}

/// A single operator piped onto a fresh ingress with a counter sink.
FlowBench buildWith({required Cell Function(Cell source) pipe}) {
  final gate = Cell.ingress<int>();
  final terminal = pipe(gate.cell);
  final passthrough = Flow.map<int, int>(gate.cell, project: (v) => v);
  return _withSink(passthrough.emit, terminal);
}

/// Fan-out: one source, [n] `Cell.observe` sinks.
FlowBench buildFanout(int n) {
  final gate = Cell.ingress<int>();
  final count = _Counter();
  for (var i = 0; i < n; i++) {
    Cell.observe(source: gate.cell, effect: (_) => count.bump());
  }
  final passthrough = Flow.map<int, int>(gate.cell, project: (v) => v);
  return (
    emit: passthrough.emit,
    terminal: gate.cell,
    emitted: count.count,
    reset: count.reset,
  );
}

FlowBench _withSink(bool Function(dynamic) emit, Cell terminal) {
  final count = _Counter();
  Cell.observe(source: terminal, effect: (_) => count.bump());
  return (
    emit: emit,
    terminal: terminal,
    emitted: count.count,
    reset: count.reset,
  );
}

/// Emits [n] pulses synchronously through [bench.emit], then drains the
/// async queue until `emitted == n` (or the spin budget is exhausted).
///
/// Synchronous pipelines complete before the call returns; async operators
/// must be drained. Returns the number of sink deliveries observed.
Future<int> drain(FlowBench bench, int n,
    {Duration spinCap = const Duration(seconds: 5)}) async {
  bench.reset();
  for (var i = 0; i < n; i++) {
    bench.emit(i);
  }
  final deadline = DateTime.now().add(spinCap);
  while (bench.emitted() < n && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(Duration.zero);
  }
  return bench.emitted();
}

/// Pure-CPU mapper used in every async/flatten bench so the timer is
/// framework overhead, not `Future.delayed`.
int cpuLoop(int v, {int iterations = 1000}) {
  var acc = v;
  for (var i = 0; i < iterations; i++) {
    acc = (acc * 31 + i) & 0x7fffffff;
  }
  return acc;
}

class _Counter {
  int _count = 0;
  int count() => _count;
  void bump() => _count++;
  void reset() => _count = 0;
}
