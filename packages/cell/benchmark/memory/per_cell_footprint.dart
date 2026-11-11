// Per-cell heap footprint — the strongest flyweight claim.
//
// Connects to the VM service (run with `dart run --enable-vm-service` or
// `dart run --observe` to give the benchmark a service URI) and measures
// the heap delta of retained allocations.
//
// Pass criterion (proposal): < 128 B per Cell.
//
// Run: dart run --observe benchmark/memory/per_cell_footprint.dart
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
        'benchmark/memory/per_cell_footprint.dart`.');
    return;
  }

  final service = await vmServiceConnectUri(uri.toString());
  final isolateId = dev.Service.getIsolateId(Isolate.current)!;

  Future<int> heapUsed() async {
    final usage = await service.getMemoryUsage(isolateId);
    return usage.heapUsage ?? 0;
  }

  Future<void> settle() async {
    // Allocate and drop garbage so the collector has something to collect
    // before the next sample.
    for (var i = 0; i < 10; i++) {
      List<int>.filled(1 << 16, i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Future<int> measure(String label, Object? Function() allocate) async {
    await settle();
    final before = await heapUsed();
    final retained = <Object?>[];
    retained.add(allocate());
    await settle();
    final after = await heapUsed();
    final bytes = after - before;
    print('$label: ${(bytes / 10000).toStringAsFixed(1)} B/unit '
        '(delta ${bytes}B for 10000)');
    return bytes;
  }

  await measure('Cell()', () {
    final cells = <Cell>[];
    for (var i = 0; i < 10000; i++) {
      cells.add(Cell());
    }
    return cells;
  });

  await measure('Cell.governed(context)', () {
    final ctx = Context.module('Payment');
    final cells = <Cell>[];
    for (var i = 0; i < 10000; i++) {
      cells.add(Cell.governed(context: ctx));
    }
    return cells;
  });

  await measure('ValueCell<int>', () {
    final cells = <ValueCell<int>>[];
    for (var i = 0; i < 10000; i++) {
      cells.add(Cell.state<int>(initial: i).cell);
    }
    return cells;
  });

  await service.dispose();
  // Exit explicitly: `dart run --observe` pauses isolates at exit by
  // default, which would otherwise hang the benchmark.
  exit(0);
}
