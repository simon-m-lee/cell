// Flow vs RxDart: synchronous map→filter pipeline.
//
// Run: dart run benchmark/compare/vs_rxdart_map_filter.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_flow/cell_flow.dart';
import 'package:rxdart/rxdart.dart';

class FlowMapFilter extends BenchmarkBase {
  FlowMapFilter() : super('flow vs rxdart: Flow map->filter');
  late final FlowHandle h;
  int count = 0;

  @override
  void setup() {
    h = Flow.map<int, int>(Cell.ingress<int>().cell, project: (x) => x * 2);
    Cell.observe(source: h.cell, effect: (_) => count++);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      h.emit(i);
    }
  }
}

class RxDartMapFilter extends BenchmarkBase {
  RxDartMapFilter() : super('flow vs rxdart: RxDart map->filter');
  late final Subject<int> subject;
  int count = 0;

  @override
  void setup() {
    subject = PublishSubject<int>();
    subject.map((x) => x * 2).where((x) => x.isEven).listen((_) => count++);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      subject.add(i);
    }
  }
}

void main() {
  FlowMapFilter().report();
  RxDartMapFilter().report();
  print('(see benchmark/README.md for the itemized cost ladder)');
}
