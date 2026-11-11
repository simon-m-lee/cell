import 'dart:async';

import 'package:cell/cell.dart';
import 'package:test/test.dart';

Future<void> _pump() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('Cell.asyncMap latestOnly with concurrency=1', () {
    test('latest value is emitted despite a superseded in-flight future',
        () async {
      final ingress = Cell.ingress<int>();
      final completers = <int, Completer<int>>{};

      final cell = Cell.asyncMap<int, int>(
        ingress.cell,
        (v) {
          final c = Completer<int>();
          completers[v] = c;
          return c.future;
        },
        latestOnly: true,
        concurrency: 1,
      );

      final received = <int>[];
      Cell.observe<Pulse<int>>(
        source: cell,
        effect: (p) => received.add(p.payload as int),
      );

      // Emit 1 — starts immediately.
      ingress.emit(1);
      await _pump();
      expect(completers.containsKey(1), isTrue);
      expect(completers.containsKey(2), isFalse,
          reason: 'concurrency=1 blocks 2 until 1 completes');

      // Emit 2 while 1 is still in flight.
      ingress.emit(2);
      await _pump();
      expect(completers.containsKey(2), isFalse,
          reason: 'still blocked while 1 is pending');

      // Complete 1 — it is superseded so its result is dropped, but the
      // pump must now start 2.
      completers[1]!.complete(100);
      await _pump();

      expect(completers.containsKey(2), isTrue,
          reason: 'the queued latest value must be drained');
      expect(received, isEmpty, reason: 'the superseded generation is dropped');

      // Complete 2 — this should emit.
      completers[2]!.complete(200);
      await _pump();

      expect(received, [200], reason: 'only the latest generation is emitted');
    });

    test('concurrency=0 latestOnly is unaffected by the change', () async {
      final ingress = Cell.ingress<int>();
      final completers = <int, Completer<int>>{};

      final cell = Cell.asyncMap<int, int>(
        ingress.cell,
        (v) {
          final c = Completer<int>();
          completers[v] = c;
          return c.future;
        },
        latestOnly: true,
        concurrency: 0,
      );

      final received = <int>[];
      Cell.observe<Pulse<int>>(
        source: cell,
        effect: (p) => received.add(p.payload as int),
      );

      ingress.emit(1);
      await _pump();
      ingress.emit(2);
      await _pump();

      completers[1]!.complete(100);
      completers[2]!.complete(200);
      await _pump();

      expect(received, [200]);
    });
  });
}
