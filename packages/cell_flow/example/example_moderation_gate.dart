// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/map.dart';

/// Public comment gate: trim, non-empty, blocklist, length cap.
///
/// Expected:
/// ```text
/// [live] hello world
/// ```
Future<void> main() async {
  const blocked = {'spam', 'scam'};

  final gate = MapValue<String, String>((s) => s.trim()) +
      Filter<String>((s) => s.isNotEmpty) +
      Filter<String>((s) => !blocked.contains(s.toLowerCase())) +
      Filter<String>((s) => s.length <= 280);

  final drafts = Cell.ingress<String>();
  final out = gate.toHandle(source: drafts.cell);
  final obs = Cell.observe(
    source: out.cell,
    effect: (Pulse p) => print('[live] ${p.payload}'),
  );

  await drafts.emitAsync('  spam  ');
  await drafts.emitAsync('hello world');
  await drafts.emitAsync('');
  obs.stop();
}
