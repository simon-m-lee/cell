// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/map.dart';

/// IoT reading: keep in-range temps, convert °C → °F, skip repeats.
///
/// Expected:
/// ```text
/// [tempF] 68.0
/// [tempF] 77.0
/// ```
Future<void> main() async {
  final gate = Filter<num>((c) => c >= -40 && c <= 85) +
      MapValue<num, double>((c) => c * 9 / 5 + 32) +
      Distinct<double>();

  final probe = Cell.ingress<num>();
  final out = gate.toHandle(source: probe.cell);
  final obs = Cell.observe(
    source: out.cell,
    effect: (Pulse p) => print('[tempF] ${p.payload}'),
  );

  await probe.emitAsync(20);
  await probe.emitAsync(20);
  await probe.emitAsync(999);
  await probe.emitAsync(25);
  obs.stop();
}
