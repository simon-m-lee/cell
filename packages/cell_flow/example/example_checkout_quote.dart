// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/map.dart';

/// Cart → quote: reject empty carts, map totals, drop zero quotes.
///
/// Expected:
/// ```text
/// [quote] 42
/// ```
Future<void> main() async {
  final gate = Filter<List<int>>((lines) => lines.isNotEmpty) +
      MapValue<List<int>, int>((lines) => lines.fold(0, (a, b) => a + b)) +
      Filter<int>((total) => total > 0);

  final cart = Cell.ingress<List<int>>();
  final out = gate.toHandle(source: cart.cell);
  final obs = Cell.observe(
    source: out.cell,
    effect: (Pulse p) => print('[quote] ${p.payload}'),
  );

  await cart.emitAsync(<int>[]);
  await cart.emitAsync([20, 22]);
  await cart.emitAsync([0, 0]);
  obs.stop();
}
