// Per-tissue heap footprint — the flyweight claim for reactive collections.
//
// Connects to the VM service (run with `dart run --observe` to give the
// benchmark a service URI) and measures the heap delta of retained
// allocations.
//
// Run: dart run --observe benchmark/memory/per_tissue_footprint.dart
import 'dart:developer' as dev;
import 'dart:io' show exit;
import 'dart:isolate' show Isolate;

import 'package:cell_tissue/cell_tissue.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main() async {
  final info = await dev.Service.getInfo();
  final uri = info.serverWebSocketUri;
  if (uri == null) {
    print('No VM service available. Run with `dart run --observe '
        'benchmark/memory/per_tissue_footprint.dart`.');
    return;
  }

  final service = await vmServiceConnectUri(uri.toString());
  final isolateId = dev.Service.getIsolateId(Isolate.current)!;

  Future<int> heapUsed() async {
    final usage = await service.getMemoryUsage(isolateId);
    return usage.heapUsage ?? 0;
  }

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      List<int>.filled(1 << 16, i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Future<void> measure(
      String label, void Function(List<Object?> retained) allocate) async {
    await settle();
    final before = await heapUsed();
    final retained = <Object?>[];
    allocate(retained);
    await settle();
    final after = await heapUsed();
    final bytes = after - before;
    print('$label: ${(bytes / 10000).toStringAsFixed(1)} B/unit '
        '(delta ${bytes}B for 10000)');
  }

  await measure('TissueList<int>()', (retained) {
    for (var i = 0; i < 10000; i++) {
      retained.add(TissueList<int>());
    }
  });
  await measure('TissueMap<String,int>()', (retained) {
    for (var i = 0; i < 10000; i++) {
      retained.add(TissueMap<String, int>());
    }
  });
  await measure('TissueSet<int>()', (retained) {
    for (var i = 0; i < 10000; i++) {
      retained.add(TissueSet<int>(<int>[]));
    }
  });
  await measure('TissueQueue<int>()', (retained) {
    for (var i = 0; i < 10000; i++) {
      retained.add(TissueQueue<int>());
    }
  });
  await measure('TissueValue<int>(0)', (retained) {
    for (var i = 0; i < 10000; i++) {
      retained.add(TissueValue<int>(0));
    }
  });

  await service.dispose();
  exit(0);
}
