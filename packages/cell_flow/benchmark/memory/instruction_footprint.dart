// Heap footprint per instruction (flyweight claim).
//
// Run: dart run --observe benchmark/memory/instruction_footprint.dart
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
        'benchmark/memory/instruction_footprint.dart`.');
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

  await measure('flow: memory per stateless instruction', () {
    final kept = <Object?>[];
    for (var i = 0; i < 10000; i++) {
      kept.add(FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) => p));
    }
    return kept;
  });

  await measure('flow: memory per stateful instruction', () {
    final kept = <Object?>[];
    for (var i = 0; i < 10000; i++) {
      kept.add(FlowInstruction<Cell, Pulse, Pulse>.future((pulse,
          {cell, user, future, token}) {
        // A stateful blueprint: captures mutable state per instance.
        return pulse.payload is int ? null : null;
      }));
    }
    return kept;
  });

  await measure('flow: memory per raw closure', () {
    final kept = <Object?>[];
    for (var i = 0; i < 10000; i++) {
      Pulse identity(Pulse p) => p;
      kept.add(identity);
    }
    return kept;
  });

  await service.dispose();
  exit(0);
}
