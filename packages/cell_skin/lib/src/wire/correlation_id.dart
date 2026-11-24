// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// One correlation-id sequence per isolate.
///
/// `SkinClient`, `RemoteCellClient`, and `RestAdapter` each keep a
/// private counter, so two of them on one membrane could mint the same
/// id in the same microsecond — and every waiter matches responses on
/// that id. A shared sequence plus a random suffix makes an id unique
/// within the isolate even across clients; two isolates can still only
/// collide by chance, which is all an opaque id needs.
/// {@category Features}
library;

import 'dart:math';

int _sequence = 0;

final Random _random = _secureRandom();

Random _secureRandom() {
  try {
    return Random.secure();
  } catch (_) {
    // A platform without a CSPRNG still gets a unique-enough suffix
    // from the sequence; the suffix is not a secret.
    return Random();
  }
}

/// Mints the next correlation id with [prefix] (`skin`, `rest`,
/// `remote`). Opaque to everyone except the membrane's waiter matching.
String nextCorrelationId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}-'
    '${_random.nextInt(1 << 31).toRadixString(16).padLeft(8, '0')}';
