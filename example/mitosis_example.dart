// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.

import 'package:mitosis/mitosis.dart';

/// Minimal, runnable quick start for the `mitosis` umbrella package.
///
/// Shows the three layers working together in one import:
/// 1. Cell — an ingress for external events,
/// 2. Flow — a fluent pipeline that normalizes and gates events,
/// 3. Tissue — a governed, observable collection recording the results.
Future<void> main() async {
  // 1. CELL — events enter the graph through an ingress.
  final commands = Cell.ingress<String>();

  // 2. FLOW — orchestration: normalize, gate, deduplicate.
  final accepted = commands.cell
      .map<String, String>(project: (c) => c.trim())
      .filter<String>(test: (c) => c.isNotEmpty)
      .distinct<String>();

  // 3. TISSUE — application state: a governed, observable collection.
  final ledger = TissueList.of(<String>[]);

  Cell.observe<Pulse<String>>(
    source: accepted.cell,
    effect: (pulse) => ledger.add('ACCEPTED: ${pulse.payload}'),
  );

  await commands.emitAsync('  deploy mitosis  ');
  await commands.emitAsync('  deploy mitosis  '); // distinct: duplicate dropped
  print(ledger); // [ACCEPTED: deploy mitosis]
}
