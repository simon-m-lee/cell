// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_memory/src/store_lifecycle.dart';
import 'package:test/test.dart';

void main() {
  group('StoreLifecycle', () {
    test('a run waiting on a Completer is in inflight before the first '
        'await; close without an await stops admission', () async {
      final lifecycle = StoreLifecycle('store is closed');
      final gate = Completer<void>();
      final blocked = lifecycle.run(() async {
        await gate.future;
        return 1;
      });

      expect(lifecycle.inflight, hasLength(1),
          reason: 'the future is recorded before op() runs');

      final closing = lifecycle.close();
      expect(() => lifecycle.run(() async => 2),
          throwsA(isA<StateError>()));

      gate.complete();
      expect(await blocked, 1);
      await closing;

      expect(() => lifecycle.run(() async => 3),
          throwsA(isA<StateError>()));
      expect(() => lifecycle.close(), throwsA(isA<StateError>()));
    });

    test('a synchronous op() failure is a failed future and does not wedge '
        'the barrier', () async {
      final lifecycle = StoreLifecycle('store is closed');
      await expectLater(
        lifecycle.run(() => throw StateError('op failure')),
        throwsA(isA<StateError>()),
      );
      await lifecycle.close();
    });
  });
}
