import 'dart:async';

import 'package:cell/cell.dart';
import 'package:test/test.dart';

Future<void> _pump() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('Cell.fromStream + EphemeralPolicy', () {
    test('eventLimit trips at the configured count, not half', () async {
      final controller = StreamController<int>.broadcast();
      addTearDown(() => controller.close());

      var invalidationCount = 0;
      final policy = EphemeralPolicy<Cell>(
        eventLimit: 5,
        onEvent: (object,
            {required Cell cell,
            required EphemeralPolicy policy,
            arguments,
            user}) {
          return (events: policy.events + 1);
        },
        onInvalidate: (nucleus) {
          invalidationCount++;
          return true;
        },
      );

      final cell = Cell.fromStream<int>(
        controller.stream,
        ephemeralPolicy: policy,
      );

      // Push 4 values — below the limit.
      for (var i = 0; i < 4; i++) {
        controller.add(i);
        await _pump();
      }

      expect(cell.isInvalidated, isFalse,
          reason: '4 events < eventLimit of 5; cell must still be alive');
      expect(invalidationCount, 0);

      // The 5th value should hit the limit.
      controller.add(4);
      await _pump();

      expect(cell.isInvalidated, isTrue,
          reason: 'the 5th event reaches the limit');
      expect(invalidationCount, 1,
          reason: 'invalidation must fire exactly once');
    });

    test('no ephemeralPolicy → no invalidation and events stay at 0', () async {
      final controller = StreamController<int>.broadcast();
      addTearDown(() => controller.close());

      final cell = Cell.fromStream<int>(controller.stream);

      for (var i = 0; i < 20; i++) {
        controller.add(i);
      }
      await _pump();

      expect(cell.isInvalidated, isFalse);
    });

    test('the caller policy hooks run exactly once per event', () async {
      final controller = StreamController<int>.broadcast();
      addTearDown(() => controller.close());

      var callerEvents = 0;
      var callerInvalidations = 0;
      final policy = EphemeralPolicy<Cell>(
        eventLimit: 2,
        onEvent: (object,
            {required Cell cell,
            required EphemeralPolicy policy,
            arguments,
            user}) {
          callerEvents++;
          return (events: policy.events + 1);
        },
        onInvalidate: (nucleus) {
          callerInvalidations++;
          return true;
        },
      );

      final cell = Cell.fromStream<int>(
        controller.stream,
        ephemeralPolicy: policy,
      );

      controller.add(1);
      await _pump();
      controller.add(2);
      await _pump();

      expect(cell.isInvalidated, isTrue,
          reason: 'the wrapper policy must trip at the configured limit');
      expect(callerEvents, 2,
          reason: 'the caller onEvent runs once per stream value — no '
              'double-tick from the listener and the receptor');
      expect(callerInvalidations, 1,
          reason: 'the caller onInvalidate must run when the wrapper '
              'reclaims the cell');
    });
  });
}
