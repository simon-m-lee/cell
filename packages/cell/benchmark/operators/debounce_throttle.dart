// Debounce/throttle per-emission overhead with Duration.zero timers.
// The benchmark measures enqueue/cancel overhead, not wall-clock timers.
//
// Run: dart run benchmark/operators/debounce_throttle.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

class DebounceZero extends BenchmarkBase {
  DebounceZero() : super('Cell.debounce(Duration.zero)');

  late final bool Function(int) emit;

  @override
  void setup() {
    final source = Cell.ingress<int>();
    final out = Cell.debounce(source.cell, Duration.zero);
    Cell.observe(source: out, effect: (Pulse p) {});
    emit = source.emit;
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      emit(i);
    }
  }
}

class DebounceLeadingZero extends BenchmarkBase {
  DebounceLeadingZero() : super('Cell.debounce(Duration.zero, leading)');

  late final bool Function(int) emit;

  @override
  void setup() {
    final source = Cell.ingress<int>();
    final out = Cell.debounce(source.cell, Duration.zero, leading: true);
    Cell.observe(source: out, effect: (Pulse p) {});
    emit = source.emit;
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      emit(i);
    }
  }
}

class ThrottleZero extends BenchmarkBase {
  ThrottleZero() : super('Cell.throttle(Duration.zero)');

  late final bool Function(int) emit;

  @override
  void setup() {
    final source = Cell.ingress<int>();
    final out = Cell.throttle(source.cell, Duration.zero);
    Cell.observe(source: out, effect: (Pulse p) {});
    emit = source.emit;
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      emit(i);
    }
  }
}

void main() {
  DebounceZero().report();
  DebounceLeadingZero().report();
  ThrottleZero().report();
}
