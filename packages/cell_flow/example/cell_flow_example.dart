// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/cell_flow.dart';

/// Minimal, runnable quick start for `cell_flow`.
///
/// Shows a search-style pipeline in a few lines:
/// 1. events enter the graph through an ingress,
/// 2. a fluent chain normalizes, gates, and debounces them, and
/// 3. an observer reacts to the accepted values.
Future<void> main() async {
  // 1. Ingress: external events enter the reactive graph here.
  final query = Cell.ingress<String>();

  // 2. Fluent pipeline: normalize, gate, and debounce.
  final accepted = query.cell
      .map<String, String>(project: (q) => q.trim().toLowerCase())
      .filter<String>(test: (q) => q.length >= 2)
      .debounce<String>(duration: const Duration(milliseconds: 100));

  // 3. Observe: react to accepted values.
  Cell.observe<Pulse<String>>(
    source: accepted.cell,
    effect: (pulse) => print('Accepted: ${pulse.payload}'),
  );

  await query.emitAsync('  Dart  ');
  await query.emitAsync('x'); // filtered out (too short)
  await Future<void>.delayed(const Duration(milliseconds: 200));
}
