// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_flow/src/instruction/tap.dart';

/// Warehouse events: only paid/shipped, map to a label, audit tap.
///
/// Expected:
/// ```text
/// [audit] paid
/// [label] PAID
/// [audit] shipped
/// [label] SHIPPED
/// ```
Future<void> main() async {
  const live = {'paid', 'shipped'};

  final gate = Filter<String>(live.contains) +
      Tap<String>((s) => print('[audit] $s')) +
      MapValue<String, String>((s) => s.toUpperCase());

  final events = Cell.ingress<String>();
  final out = gate.toHandle(source: events.cell);
  final obs = Cell.observe(
    source: out.cell,
    effect: (Pulse p) => print('[label] ${p.payload}'),
  );

  for (final s in ['draft', 'paid', 'cancelled', 'shipped']) {
    await events.emitAsync(s);
  }
  obs.stop();
}
