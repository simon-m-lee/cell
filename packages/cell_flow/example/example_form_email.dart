// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/map.dart';

/// Email field: trim, lower, must contain @, first-seen only.
///
/// Expected:
/// ```text
/// [email] ada@example.com
/// ```
Future<void> main() async {
  final gate = MapValue<String, String>((s) => s.trim().toLowerCase()) +
      Filter<String>((s) => s.contains('@') && s.contains('.')) +
      Distinct<String>();

  final field = Cell.ingress<String>();
  final out = gate.toHandle(source: field.cell);
  final obs = Cell.observe(
    source: out.cell,
    effect: (Pulse p) => print('[email] ${p.payload}'),
  );

  await field.emitAsync('Ada@Example.com');
  await field.emitAsync('not-an-email');
  await field.emitAsync('ada@example.com');
  obs.stop();
}
