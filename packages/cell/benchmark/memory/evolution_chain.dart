// Evolution-chain heap cost: each `evolve` should add one _EvolvedPulse
// plus a list entry — measure that a 100-step chain doesn't cost more
// than a 1-step chain x 100.
//
// Run: dart run --observe benchmark/memory/evolution_chain.dart
import 'dart:developer' as dev;
import 'dart:io' show exit;
import 'dart:isolate' show Isolate;

import 'package:cell/cell.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main() async {
  final info = await dev.Service.getInfo();
  final uri = info.serverWebSocketUri;
  if (uri == null) {
    print('No VM service available. Run with `dart run --observe '
        'benchmark/memory/evolution_chain.dart`.');
    return;
  }

  final service = await vmServiceConnectUri(uri.toString());
  final isolateId = dev.Service.getIsolateId(Isolate.current)!;

  Future<int> heapUsed() async {
    final usage = await service.getMemoryUsage(isolateId);
    return usage.heapUsage ?? 0;
  }

  Future<int> measure(String label, Pulse Function() build) async {
    for (var i = 0; i < 10; i++) {
      List<int>.filled(1 << 16, i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final before = await heapUsed();
    final retained = <Pulse>[];
    for (var i = 0; i < 10000; i++) {
      retained.add(build());
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final after = await heapUsed();
    final bytes = after - before;
    print('$label: ${(bytes / 10000).toStringAsFixed(1)} B/unit '
        '(delta ${bytes}B for 10000)');
    return bytes;
  }

  Pulse chain(int depth) {
    Pulse p = Pulse<int>(1);
    for (var i = 0; i < depth; i++) {
      p = p.evolve(step: 's$i');
    }
    return p;
  }

  await measure('Pulse (1 step)', () => chain(1));
  await measure('Pulse (100 steps)', () => chain(100));

  await service.dispose();
  // Exit explicitly: `dart run --observe` pauses isolates at exit by
  // default, which would otherwise hang the benchmark.
  exit(0);
}
