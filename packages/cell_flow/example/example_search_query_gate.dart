// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/map.dart';

/// Search box policy: trim, lowercase, min length, distinct.
///
/// Expected:
/// ```text
/// [query] dart
/// [query] flutter
/// ```
Future<void> main() async {
  final gate = MapValue<String, String>((q) => q.trim().toLowerCase()) +
      Filter<String>((q) => q.length >= 2) +
      Distinct<String>();

  final box = Cell.ingress<String>();
  final out = gate.toHandle(source: box.cell);
  final obs = Cell.observe(
    source: out.cell,
    effect: (Pulse p) => print('[query] ${p.payload}'),
  );

  for (final q in [' D', ' Dart', 'DART', 'Flutter']) {
    await box.emitAsync(q);
  }
  obs.stop();
}
