// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cell.asStream', () {
    test('sync emission matches observe sequence', () {
      final src = Cell.ingress<int>();
      final received = <int?>[];

      src.cell.asStream<int>().listen(received.add);

      src.emit(1);
      src.emit(2);
      src.emit(3);

      expect(received, [1, 2, 3]);
    });

    test('seeds a ValueCell current value on listen', () async {
      final counter = Cell.state<int>(initial: 7);
      final received = <int?>[];

      final sub = counter.cell.asStream<int>().listen(received.add);

      // The retained-pulse seed serves ValueCell sources; the first event
      // is delivered on the next microtask, so drain once before asserting.
      await pumpEventQueue();
      expect(received, [7]);

      counter.update(8);
      await pumpEventQueue();
      expect(received, [7, 8]);

      await sub.cancel();
    });

    test('async emission with sync: false', () async {
      final src = Cell.ingress<int>();
      final received = <int?>[];

      src.cell.asStream<int>(sync: false).listen(received.add);

      src.emit(1);
      expect(received, isEmpty);

      await Future<void>.delayed(Duration.zero);
      expect(received, [1]);
    });

    test('error pulse with emitErrors: true becomes addError', () async {
      final src = Cell.ingress<Object>();
      Object? seenError;

      src.cell.asStream<Object>().listen(
            (v) {},
            onError: (Object e) => seenError = e,
          );

      await src.ingest(Pulse<Object>(StateError('boom'), type: 'error'));

      expect(seenError, isA<StateError>());
    });

    test('error pulse with emitErrors: false is skipped', () async {
      final src = Cell.ingress<Object>();
      final received = <Object?>[];
      Object? seenError;

      src.cell.asStream<Object>(emitErrors: false).listen(
            received.add,
            onError: (Object e) => seenError = e,
          );

      await src.ingest(Pulse<Object>(StateError('boom'), type: 'error'));
      src.emit(42);

      expect(seenError, isNull);
      expect(received, [42]);
    });

    test('cancel stops the egress', () {
      final src = Cell.ingress<int>();
      final received = <int?>[];

      final subscription = src.cell.asStream<int>().listen(received.add);

      src.emit(1);
      subscription.cancel();
      src.emit(2);

      expect(received, [1]);
    });

    test('second listen throws (single-subscription)', () {
      final src = Cell.ingress<int>();
      final stream = src.cell.asStream<int>();

      stream.listen((_) {});
      expect(() => stream.listen((_) {}), throwsStateError);
    });

    test('null payload is emitted as null', () {
      final src = Cell.ingress<int?>();
      final received = <int?>[];

      src.cell.asStream<int?>().listen(received.add);

      src.emit(null);
      expect(received, [null]);
    });

    test('type mismatch becomes addError', () {
      final src = Cell.ingress<Object>();
      Object? seenError;

      src.cell.asStream<int>().listen(
            (_) {},
            onError: (Object e) => seenError = e,
          );

      src.emit('not-an-int');

      expect(seenError, isA<StateError>());
    });
  });
}
