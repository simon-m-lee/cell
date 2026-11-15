// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';

/// Measures the cost of a policy decision at varying composition depths.
///
/// Run with:
/// ```bash
/// dart run benchmark/micro/policy_cost.dart
/// ```
///
/// Reports nanoseconds per decision for:
/// - 1-deep: `domainPolicy()`
/// - 3-deep: `contextAware()` (requiresDomain + domain + confidence)
/// - 6-deep: `paranoid()` (ten gates)
/// - manual baseline: a hand-written if/else chain
///
/// Guidance: 1-deep should stay near the manual baseline; composition
/// overhead should grow roughly linearly with depth. This baseline
/// justifies static mode (P9) — no wrapper, no double-validation.
Future<void> main() async {
  final host = Cell.ingress<int>(
    context: Context(domains: 'finance,audit', compliances: 'GDPR'),
  );
  final pulse = Pulse<int>.governed(
    payload: 0,
    context: PulseContext.fromEntries([
      Provenance.actor.entry('bench'),
      Provenance.reason.entry('bench'),
      Provenance.traceId.entry(Identity.next()),
      Ontology.domains.entry('finance'),
      Provenance.compliance.entry('GDPR'),
      Provenance.confidence.entry(0.95),
      Provenance.strategy.entry(ReasoningStrategy.deterministic),
      Provenance.auditLevel.entry(AuditLevel.standard),
      Provenance.sensitivity.entry(Sensitivity.public),
    ]),
  );

  const n = 100000;

  print('Policy decision cost (ns/decision, $n iterations):');
  print('');

  // Construct the policies once — the benchmark measures decision cost,
  // not factory allocation cost.
  final oneDeep = domainPolicy();
  final threeDeep =
      requiresDomainPolicy() + domainPolicy() + confidencePolicy(min: 0.85);
  final tenDeep = paranoid();

  // Warm-up the rules and JIT.
  for (var i = 0; i < 1000; i++) {
    oneDeep.call(pulse, host: host.cell);
    threeDeep.call(pulse, host: host.cell);
    tenDeep.call(pulse, host: host.cell);
  }

  await bench('manual if/else baseline', n, () {
    final d = host.cell.context.domains ?? '';
    final o = pulse.context.domains ?? '';
    // ignore: unnecessary_statements
    d.contains(o.split(',').first);
  });
  await bench('1-deep  (domainPolicy)', n, () {
    oneDeep.call(pulse, host: host.cell);
  });
  await bench('3-deep  (contextAware)', n, () {
    threeDeep.call(pulse, host: host.cell);
  });
  await bench('10-deep (paranoid)', n, () {
    tenDeep.call(pulse, host: host.cell);
  });
}

Future<void> bench(String label, int n, void Function() body) async {
  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < n; i++) {
    body();
  }
  stopwatch.stop();
  final nsPerDecision = stopwatch.elapsedMicroseconds * 1000 / n;
  print('  ${label.padRight(28)} ${nsPerDecision.toStringAsFixed(1)}');
}
