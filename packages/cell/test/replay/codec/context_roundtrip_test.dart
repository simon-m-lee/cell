// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';

import 'package:test/test.dart';

void main() {
  group('PulseContextCodec round-trip', () {
    test('the system context round-trips byte-identically', () {
      final json = PulseContextCodec.toJson(PulseContext.system);
      expect(json, {
        'lineage': [
          <String, Object?>{},
        ],
      });

      final decoded = PulseContextCodec.fromJson(json);
      expect(decoded.actor, isNull);
      expect(decoded.reason, isNull);
      expect(decoded.priority, isNull);
      expect(decoded.compliance, isNull);

      final reEncoded = canonicalJsonEncode(PulseContextCodec.toJson(decoded));
      expect(reEncoded, canonicalJsonEncode(json));
    });

    test('all provenance dimensions round-trip byte-identically', () {
      final context = PulseContext.fromEntries([
        Provenance.actor.entry('agent_7'),
        Provenance.reason.entry('Resource saturation'),
        Provenance.purpose.entry('TOPOLOGY_REFRESH'),
        Provenance.strategy.entry(ReasoningStrategy.probabilistic),
        Provenance.confidence.entry(0.85),
        Provenance.priority.entry(40),
        Provenance.compliance.entry('GDPR'),
        Provenance.sensitivity.entry(Sensitivity.confidential),
        Provenance.auditLevel.entry(AuditLevel.full),
        Provenance.traceId.entry('trace-1'),
        Provenance.parentTraceId.entry('trace-0'),
        Provenance.integrity.entry('sha256:abc'),
      ]);

      final json = PulseContextCodec.toJson(context);
      final decoded = PulseContextCodec.fromJson(json);

      expect(decoded.actor, 'agent_7');
      expect(decoded.reason, 'Resource saturation');
      expect(decoded.purpose, 'TOPOLOGY_REFRESH');
      expect(decoded.strategy, ReasoningStrategy.probabilistic);
      expect(decoded.confidence, 0.85);
      expect(decoded.priority, 40);
      expect(decoded.compliance, 'GDPR');
      expect(decoded.sensitivity, Sensitivity.confidential);
      expect(decoded.auditLevel, AuditLevel.full);
      expect(decoded.traceId, 'trace-1');
      expect(decoded.parentTraceId, 'trace-0');
      expect(decoded.integrity, 'sha256:abc');

      expect(
        canonicalJsonEncode(PulseContextCodec.toJson(decoded)),
        canonicalJsonEncode(json),
      );
    });

    test('a three-generation chain re-resolves inheritance after round-trip',
        () {
      final root = PulseContext.fromEntries([
        Provenance.actor.entry('root-actor'),
        Provenance.reason.entry('boot'),
      ]);
      final child = PulseContext.fromEntries(
        [Provenance.reason.entry('tick')],
        parent: root,
      );
      final leaf = PulseContext.fromEntries(
        [Provenance.confidence.entry(0.5)],
        parent: child,
      );

      expect(leaf.actor, 'root-actor'); // inherited from root
      expect(leaf.reason, 'tick'); // overridden by child

      final json = PulseContextCodec.toJson(leaf);
      expect(json['lineage'], hasLength(3)); // root first, leaf last

      final decoded = PulseContextCodec.fromJson(json);
      expect(decoded.actor, 'root-actor');
      expect(decoded.reason, 'tick');
      expect(decoded.confidence, 0.5);

      expect(
        canonicalJsonEncode(PulseContextCodec.toJson(decoded)),
        canonicalJsonEncode(json),
      );
    });

    test('the __others__ map is preserved verbatim', () {
      final context = PulseContext.fromEntries(
        [Provenance.actor.entry('a')],
        others: {
          'tenant': 'north',
          'nested': {'flag': true, 'list': [1, 2.5, 'x']},
          'count': 3,
        },
      );

      final decoded = PulseContextCodec.fromJson(PulseContextCodec.toJson(context));
      expect(decoded.others, {
        'tenant': 'north',
        'nested': {'flag': true, 'list': [1, 2.5, 'x']},
        'count': 3,
      });
      expect(
        canonicalJsonEncode(PulseContextCodec.toJson(decoded)),
        canonicalJsonEncode(PulseContextCodec.toJson(context)),
      );
    });

    test('ontology dimensions round-trip when a context sets them', () {
      final context = PulseContext.fromEntries([
        Ontology.taxonomy.entry('Repository'),
        Ontology.domains.entry('Finance'),
        Ontology.subDomains.entry('Ledger'),
        Ontology.dataSources.entry('Auth_Service'),
        Ontology.topology.entry('Leaf'),
        Ontology.version.entry('1.2.3'),
        Ontology.type.entry('audit'),
        Ontology.identity.entry('repo-1'),
        Ontology.stakeholders.entry('ops'),
        Ontology.isNot.entry('a gate'),
        Ontology.partOf.entry('core'),
        Ontology.constraints.entry({'maxDepth': 3}),
      ]);

      final json = PulseContextCodec.toJson(context);
      final decoded = PulseContextCodec.fromJson(json);

      expect(decoded.taxonomy, 'Repository');
      expect(decoded.domains, 'Finance');
      expect(decoded.subDomains, 'Ledger');
      expect(decoded.dataSources, 'Auth_Service');
      expect(decoded.topology, 'Leaf');
      expect(decoded.version, '1.2.3');
      expect(decoded.type, 'audit');
      expect(decoded.identity, 'repo-1');
      expect(decoded.stakeholders, 'ops');
      expect(decoded.isNot, 'a gate');
      expect(decoded.partOf, 'core');
      expect(decoded.constraints, {'maxDepth': 3});

      expect(
        canonicalJsonEncode(PulseContextCodec.toJson(decoded)),
        canonicalJsonEncode(json),
      );
    });
  });

  group('PulseContextCodec failures', () {
    test('missing lineage is a FormatException', () {
      expect(
        () => PulseContextCodec.fromJson(const {}),
        throwsFormatException,
      );
    });

    test('unknown governance key is a loud FormatException', () {
      expect(
        () => PulseContextCodec.fromJson({
          'lineage': [
            {'madeUpDimension': 'x'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('a non-map lineage entry is a FormatException', () {
      expect(
        () => PulseContextCodec.fromJson({
          'lineage': ['not-a-map'],
        }),
        throwsFormatException,
      );
    });
  });
}
