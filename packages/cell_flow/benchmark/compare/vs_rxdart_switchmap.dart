// Flow switchMap vs RxDart switchMap (supersession-heavy).
//
// Run: dart run benchmark/compare/vs_rxdart_switchmap.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_flow/cell_flow.dart';
import 'package:rxdart/rxdart.dart';

import '../harness.dart';

int _cpu(int v) => cpuLoop(v);

class FlowSwitchMap extends AsyncBenchmarkBase {
  FlowSwitchMap() : super('flow vs rxdart: Flow switchMap');
  late final FlowHandle h;

  @override
  Future<void> setup() async {
    h = Flow.switchMap<int, int>(Cell.ingress<int>().cell,
        project: (v) async => _cpu(v));
  }

  @override
  Future<void> run() async {
    for (var i = 0; i < 1000; i++) {
      h.emit(i);
      await Future<void>.delayed(Duration.zero);
    }
  }
}

class RxDartSwitchMap extends AsyncBenchmarkBase {
  RxDartSwitchMap() : super('flow vs rxdart: RxDart switchMap');
  late final Subject<int> subject;

  @override
  Future<void> setup() async {
    subject = PublishSubject<int>();
    subject
        .switchMap((v) => Stream.fromFuture(Future.value(_cpu(v))))
        .listen((_) {});
  }

  @override
  Future<void> run() async {
    for (var i = 0; i < 1000; i++) {
      subject.add(i);
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  FlowSwitchMap().report();
  RxDartSwitchMap().report();
}
