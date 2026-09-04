// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/map.dart';

/// Trim → drop blanks → pass through. One Receptor via `+`.
///
/// Expected:
/// ```text
/// [sanitize] ada
/// ```
Future<void> main() async {
  final gate = MapValue<String, String>((s) => s.trim()) +
      Filter<String>((s) => s.isNotEmpty);

  final raw = Cell.ingress<String>();
  final out = gate.toHandle(source: raw.cell);
  final obs = Cell.observe(
    source: out.cell,
    effect: (Pulse p) => print('[sanitize] ${p.payload}'),
  );

  await raw.emitAsync('  ada  ');
  await raw.emitAsync('   ');
  obs.stop();
}
