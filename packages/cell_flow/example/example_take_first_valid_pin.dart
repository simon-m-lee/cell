// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/map.dart';

/// PIN pad: digits only, exactly 4 chars, first three good PINs only.
///
/// Expected:
/// ```text
/// [pin] 1234
/// [pin] 0000
/// [pin] 9876
/// ```
Future<void> main() async {
  final gate = MapValue<String, String>((s) => s.trim()) +
      Filter<String>((s) => RegExp(r'^\d{4}$').hasMatch(s)) +
      Take<String>(3);

  final pad = Cell.ingress<String>();
  final out = gate.toHandle(source: pad.cell);
  final obs = Cell.observe(
    source: out.cell,
    effect: (Pulse p) => print('[pin] ${p.payload}'),
  );

  for (final p in ['12', '1234', 'abcd', '0000', '9876', '1111']) {
    await pad.emitAsync(p);
  }
  obs.stop();
}
