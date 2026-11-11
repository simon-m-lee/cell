// Per-tissue heap footprint + nucleus sharing (flyweight claim).
//
// Run: dart run --observe benchmark/tissue/memory/per_tissue_footprint.dart
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
        'benchmark/tissue/memory/per_tissue_footprint.dart`.');
    return;
  }
  final service = await vmServiceConnectUri(uri.toString());
  final isolateId = dev.Service.getIsolateId(Isolate.current)!;

  Future<int> heapUsed() async =>
      (await service.getMemoryUsage(isolateId)).heapUsage ?? 0;

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      List<int>.filled(1 << 16, i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Future<int> measure(String label, List<Object?> Function() allocate) async {
    await settle();
    final before = await heapUsed();
    final retained = allocate();
    await settle();
    final after = await heapUsed();
    final bytes = after - before;
    print('$label: ${(bytes / retained.length).toStringAsFixed(1)} B/unit '
        '(delta ${bytes}B for ${retained.length})');
    return bytes;
  }

  await measure('TissueList<int>() isolated', () {
    final kept = <Object?>[];
    for (var i = 0; i < 10000; i++) {
      kept.add(TissueList<int>());
    }
    return kept;
  });

  // Nucleus sharing: one blueprint, 10k tissues.
  final blueprint = TissueListNucleus.create<int, TissueList<int>>();
  await measure('TissueList.fromNucleus (shared blueprint)', () {
    final kept = <Object?>[];
    for (var i = 0; i < 10000; i++) {
      kept.add(TissueList.fromNucleus(blueprint));
    }
    return kept;
  });

  await service.dispose();
  exit(0);
}
