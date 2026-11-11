// Heap footprint per materialized handle (FlowHandle ≈ Cell claim).
//
// Run: dart run --observe benchmark/memory/flow_handle_footprint.dart
import 'dart:developer' as dev;
import 'dart:io' show exit;
import 'dart:isolate' show Isolate;

import 'package:cell_flow/cell_flow.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main() async {
  final info = await dev.Service.getInfo();
  final uri = info.serverWebSocketUri;
  if (uri == null) {
    print('No VM service available. Run with `dart run --observe '
        'benchmark/memory/flow_handle_footprint.dart`.');
    return;
  }
  final service = await vmServiceConnectUri(uri.toString());
  final isolateId = dev.Service.getIsolateId(Isolate.current)!;

  Future<int> heapUsed() async =>
      (await service.getMemoryUsage(isolateId)).heapUsage ?? 0;

  Future<void> settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Future<void> measure(String label, List<Object?> Function() allocate) async {
    await settle();
    final before = await heapUsed();
    final retained = allocate();
    await settle();
    final after = await heapUsed();
    print('$label: ${((after - before) / retained.length).toStringAsFixed(1)} '
        'B/unit (delta ${after - before}B for ${retained.length})');
  }

  await measure('flow: memory per handle', () {
    final kept = <Object?>[];
    for (var i = 0; i < 5000; i++) {
      kept.add(Flow.map<int, int>(Cell.ingress<int>().cell, project: (v) => v));
    }
    return kept;
  });

  await measure('flow: memory per raw Cell', () {
    final kept = <Object?>[];
    for (var i = 0; i < 5000; i++) {
      kept.add(Cell());
    }
    return kept;
  });

  await measure('flow: memory per 3-stage pipeline', () {
    final kept = <Object?>[];
    for (var i = 0; i < 2000; i++) {
      final gate = Cell.ingress<int>();
      var h = Flow.map<int, int>(gate.cell, project: (v) => v);
      h = Flow.map<int, int>(h.cell, project: (v) => v);
      h = Flow.map<int, int>(h.cell, project: (v) => v);
      kept.add(h);
    }
    return kept;
  });

  await service.dispose();
  exit(0);
}
