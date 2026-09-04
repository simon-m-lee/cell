// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/map.dart';

/// Price tick: drop negatives, cents → dollars string, skip unchanged.
///
/// Expected:
/// ```text
/// [px] \$12.34
/// [px] \$12.50
/// ```
Future<void> main() async {
  final gate = Filter<int>((cents) => cents >= 0) +
      MapValue<int, String>((cents) => '\$${(cents / 100).toStringAsFixed(2)}') +
      Distinct<String>();

  final ticks = Cell.ingress<int>();
  final out = gate.toHandle(source: ticks.cell);
  final obs = Cell.observe(
    source: out.cell,
    effect: (Pulse p) => print('[px] ${p.payload}'),
  );

  await ticks.emitAsync(-5);
  await ticks.emitAsync(1234);
  await ticks.emitAsync(1234);
  await ticks.emitAsync(1250);
  obs.stop();
}
