// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  group('Pulse.toJson extension', () {
    test('is visible on Pulse<P>', () {
      final pulse = Pulse<String>('hello', type: 'greeting');
      final json = pulse.toJson();
      expect(json, isA<Map<String, dynamic>>());
      expect(json['__pulse__'], '1.0.0');
      expect(json['payload'], 'hello');
      expect(json['type'], 'greeting');
    });

    test('round-trips through Pulse.fromJson', () {
      final pulse = Pulse<int>(7, type: 'seven');
      final decoded = Pulse.fromJson(pulse.toJson());
      expect(decoded.payload, 7);
      expect(decoded.type, 'seven');
    });

    test('throws PulseNotSerializable for a pulse with callbacks', () {
      final pulse = Pulse.governed(payload: 1, onComplete: (_) {});
      expect(
        () => pulse.toJson(),
        throwsA(
          isA<PulseNotSerializable>()
              .having((e) => e.field, 'field', 'onComplete'),
        ),
      );
    });
  });
}
