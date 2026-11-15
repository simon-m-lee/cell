// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered example file names; the numeric
// prefix is intentional (01_hello_policy → example #1).
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';

/// Domain-gated ingress — the simplest `cell_mind` use case.
///
/// Run with:
/// ```bash
/// dart run example/01_hello_policy.dart
/// ```
///
/// Expected output:
/// ```text
/// trade-001 (finance)        -> ACCEPTED
/// audit-42 (audit)           -> ACCEPTED
/// trade-002 (finance,audit)  -> ACCEPTED
/// marketing-blast (marketing)-> REJECTED
/// anonymous (untagged)       -> REJECTED
/// Accepted payloads: [trade-001, audit-42, trade-002]
/// ```
Future<void> main() async {
  print('=== Constructing a domain-gated ingress ===');

  // 1. The acceptor declares its domains. Note: `Ontology.domains` is a
  //    static pillar in cell 1.1.0 — set it at construction, not evolve.
  final context = Context(domains: 'finance,audit');

  // 2. Compose the policy: require a domain, then check the subset.
  //    domainPolicy() also fails closed on untagged pulses (P4).
  final policy = requiresDomainPolicy() + domainPolicy();

  // 3. Static mode: bake the policy into the cell's testRule.
  final gate = Cell.ingress<String>(
    context: context,
    testRule: policy,
  );

  // 4. Observe the accepted path.
  final accepted = <String>[];
  final observer = Cell.observe(
      source: gate.cell,
      effect: (Pulse p) {
        accepted.add(p.payload as String);
      });

  print('=== Emitting pulses ===');

  Future<void> emit(String label, String? domains) async {
    final pulse = Pulse<String>.governed(
      payload: label,
      context: PulseContext.fromEntries([
        Provenance.actor.entry('demo'),
        Provenance.reason.entry('example emission'),
        Provenance.traceId.entry(Identity.next()),
        if (domains != null) Ontology.domains.entry(domains),
      ]),
    );
    await gate.ingest(pulse);
    final result = accepted.contains(label) ? 'ACCEPTED' : 'REJECTED';
    print('  $label (${domains ?? 'untagged'}) -> $result');
  }

  await emit('trade-001', 'finance');
  await emit('audit-42', 'audit');
  await emit('trade-002', 'finance,audit');
  await emit('marketing-blast', 'marketing');
  await emit('anonymous', null);

  print('');
  print('Accepted payloads: $accepted');
  print('');
  print('Done.');
  observer.stop();
}
