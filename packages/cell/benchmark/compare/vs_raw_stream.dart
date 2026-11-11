// Cell propagation vs a raw StreamController broadcast for the same
// single-hop observer shape.
//
// Run: dart run benchmark/compare/vs_raw_stream.dart
import 'dart:async';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

class CellSingleHop extends BenchmarkBase {
  CellSingleHop() : super('Cell ingress -> observer');

  late final bool Function(int) emit;

  @override
  void setup() {
    final source = Cell.ingress<int>();
    Cell.observe(source: source.cell, effect: (Pulse p) {});
    emit = source.emit;
  }

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      emit(i);
    }
  }
}

class RawStreamSingleHop extends BenchmarkBase {
  RawStreamSingleHop() : super('raw StreamController broadcast -> listener');

  final controller = StreamController<int>.broadcast();

  @override
  void setup() {
    controller.stream.listen((_) {});
  }

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      controller.add(i);
    }
  }
}

void main() {
  CellSingleHop().report();
  RawStreamSingleHop().report();
  // The ratio is the itemized price of the governance model, not overhead.
  // Warmed per-emit ladder on the maintainer machine:
  //   Pulse construction (source/type/priority/trace provenance): ~0.3 µs
  //   broadcast machinery (cycle/diamond check, deferred-link mutation
  //     guard, policy hook):                                      ~1.7 µs
  //   observer pipeline (allowAll gate, step lineage, terminal
  //     branch accounting):                                       ~2.4 µs
  //   raw StreamController.add (bare pointer handoff):            ~0.04 µs
  // RxDart/Streams would need the same features layered on to compare
  // feature-for-feature.
  print('(see benchmark/README.md for the itemized cost ladder)');
}
