// Flow asyncMap vs RxDart flatMap (pure-CPU mapper).
//
// Run: dart run benchmark/compare/vs_rxdart_asyncmap.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_flow/cell_flow.dart';
import 'package:rxdart/rxdart.dart';

import '../harness.dart';

int _cpu(int v) => cpuLoop(v);

class FlowAsyncMap extends AsyncBenchmarkBase {
  FlowAsyncMap() : super('flow vs rxdart: Flow asyncMap');
  late final FlowHandle h;
  int done = 0;

  @override
  Future<void> setup() async {
    h = Flow.asyncMap<int, int>(Cell.ingress<int>().cell, mapper: _cpu);
    Cell.observe(source: h.cell, effect: (_) => done++);
  }

  @override
  Future<void> run() async {
    done = 0;
    for (var i = 0; i < 1000; i++) {
      h.emit(i);
    }
    while (done < 1000) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

class RxDartFlatMap extends AsyncBenchmarkBase {
  RxDartFlatMap() : super('flow vs rxdart: RxDart flatMap');
  late final Subject<int> subject;
  int done = 0;

  @override
  Future<void> setup() async {
    subject = PublishSubject<int>();
    subject
        .flatMap((v) => Stream.fromFuture(Future.value(_cpu(v))))
        .listen((_) => done++);
  }

  @override
  Future<void> run() async {
    done = 0;
    for (var i = 0; i < 1000; i++) {
      subject.add(i);
    }
    while (done < 1000) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  FlowAsyncMap().report();
  RxDartFlatMap().report();
}
