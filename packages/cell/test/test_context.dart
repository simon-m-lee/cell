// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:test/test.dart';
import 'package:cell/cell.dart';

void main() {
  group('GovernanceEntry', () {
    test('binds a typed value to a governance dimension', () {
      final entry = Ontology.taxonomy.entry('Processor');
      expect(entry.key, Ontology.taxonomy);
      expect(entry.value, 'Processor');
    });

    test('constructor is equivalent to Governance.entry', () {
      final viaFactory = Ontology.identity.entry('node-1');
      const viaCtor = GovernanceEntry(Ontology.identity, 'node-1');
      expect(viaCtor.key, viaFactory.key);
      expect(viaCtor.value, viaFactory.value);
    });

    test('toEntry produces a MapEntry with the same key and value', () {
      final entry = Ontology.domains.entry('Finance');
      final mapped = entry.toEntry();
      expect(mapped.key, Ontology.domains);
      expect(mapped.value, 'Finance');
    });

    test('supports collection and enum value types', () {
      final constraints = Ontology.constraints.entry({'max': 10});
      final clearance = Mandate.clearance.entry(Clearance.administrative);
      final strategy = Provenance.strategy.entry(ReasoningStrategy.manual);
      expect(constraints.value, {'max': 10});
      expect(clearance.value, Clearance.administrative);
      expect(strategy.value, ReasoningStrategy.manual);
    });
  });

  group('Ontology', () {
    test('static pillars are not evolvable', () {
      expect(Ontology.domains.evolvable, isFalse);
      expect(Ontology.dataSources.evolvable, isFalse);
      expect(Ontology.taxonomy.evolvable, isFalse);
      expect(Ontology.topology.evolvable, isFalse);
      expect(Ontology.version.evolvable, isFalse);
    });

    test('fluid boundaries are evolvable', () {
      expect(Ontology.type.evolvable, isTrue);
      expect(Ontology.identity.evolvable, isTrue);
      expect(Ontology.subDomains.evolvable, isTrue);
      expect(Ontology.stakeholders.evolvable, isTrue);
      expect(Ontology.constraints.evolvable, isTrue);
      expect(Ontology.isNot.evolvable, isTrue);
      expect(Ontology.compliance.evolvable, isTrue);
      expect(Ontology.partOf.evolvable, isTrue);
    });

    test('isType validates the dimension value type', () {
      expect(Ontology.taxonomy.isType('Audit_Repository'), isTrue);
      expect(Ontology.taxonomy.isType(42), isFalse);
      expect(Ontology.constraints.isType({'max_value': 100}), isTrue);
      expect(Ontology.constraints.isType('not-a-map'), isFalse);
    });

    test('compose includes every resolved dimension and omits nulls', () {
      final entries = Ontology.compose((dimension) {
        if (dimension == Ontology.taxonomy) {
          return Ontology.taxonomy.entry('Processor');
        }
        if (dimension == Ontology.domains) {
          return Ontology.domains.entry('Finance');
        }
        return null;
      }).toList();

      expect(entries, hasLength(2));
      final context = Context.fromEntries(entries.cast());
      expect(context.taxonomy, 'Processor');
      expect(context.domains, 'Finance');
      expect(context.type, isNull);
    });

    test('evolve yields only fluid boundaries', () {
      final seen = <Governance>[];
      final entries = Ontology.evolve((evolvable) {
        seen.add(evolvable);
        if (evolvable == Ontology.identity) {
          return Ontology.identity.entry('refined');
        }
        return null;
      }).toList();

      expect(seen, isNot(contains(Ontology.taxonomy)));
      expect(seen, isNot(contains(Ontology.domains)));
      expect(seen, contains(Ontology.identity));
      expect(seen, contains(Ontology.type));
      expect(entries, hasLength(1));
      expect(entries.single.value, 'refined');
    });
  });

  group('Context', () {
    group('system', () {
      test('is a reusable singleton with empty ontology', () {
        expect(identical(Context.system, Context.system), isTrue);
        expect(Context.system.type, isNull);
        expect(Context.system.identity, isNull);
        expect(Context.system.taxonomy, isNull);
        expect(Context.system.topology, isNull);
        expect(Context.system.dataSources, isNull);
        expect(Context.system.constraints, isNull);
        expect(Context.system.stakeholders, isNull);
        expect(Context.system.domains, isNull);
        expect(Context.system.subDomains, isNull);
        expect(Context.system.version, isNull);
        expect(Context.system.isNot, isNull);
        expect(Context.system.compliance, isNull);
        expect(Context.system.partOf, isNull);
        expect(Context.system[Ontology.taxonomy], isNull);
        expect(Context.system.lineage(Ontology.domains), isEmpty);
      });

      test('evolve produces a specialized context without mutating system', () {
        final evolved = Context.system.evolve((evolvable) {
          if (evolvable == Ontology.identity) {
            return Ontology.identity.entry('system-child');
          }
          return null;
        });
        expect(Context.system.identity, isNull);
        expect(evolved.identity, 'system-child');
        expect(identical(evolved, Context.system), isFalse);
      });
    });

    group('describe', () {
      test('returns a Context whose ontology getters are unset', () {
        final context = Context.describe(
          'A secure audit log for the Healthcare domain compliant with HIPAA',
        );
        expect(context, isA<Context>());
        expect(context.taxonomy, isNull);
        expect(context.domains, isNull);
        expect(context.compliance, isNull);
        expect(context.type, isNull);
        expect(context[Ontology.taxonomy], isNull);
        expect(context.lineage(Ontology.domains), isEmpty);
      });

      test('evolve materializes ontology from the description context', () {
        final described = Context.describe('unused description');
        final evolved = described.evolve((evolvable) {
          if (evolvable == Ontology.subDomains) {
            return Ontology.subDomains.entry('billing');
          }
          return null;
        });
        expect(evolved.subDomains, 'billing');
        expect(described.subDomains, isNull);
      });
    });

    group('primary constructor', () {
      test('stores every named ontological dimension', () {
        final context = Context(
          type: 'payment_processor',
          identity: 'payment_gateway_01',
          domains: 'finance',
          dataSources: 'Auth_Service, User_DB',
          taxonomy: 'module',
          topology: 'Principal',
          version: '2.1.0',
          subDomains: 'payments, refunds',
          stakeholders: 'finance_team, compliance',
          constraints: {'max_amount': 10000, 'currency': 'USD'},
          isNot: 'Currency_Exchange',
          compliances: 'PCI-DSS',
          partOf: 'Checkout_Service',
        );

        expect(context.type, 'payment_processor');
        expect(context.identity, 'payment_gateway_01');
        expect(context.domains, 'finance');
        expect(context.dataSources, 'Auth_Service, User_DB');
        expect(context.taxonomy, 'module');
        expect(context.topology, 'Principal');
        expect(context.version, '2.1.0');
        expect(context.subDomains, 'payments, refunds');
        expect(context.stakeholders, 'finance_team, compliance');
        expect(context.constraints, {'max_amount': 10000, 'currency': 'USD'});
        expect(context.isNot, 'Currency_Exchange');
        expect(context.compliance, 'PCI-DSS');
        expect(context.partOf, 'Checkout_Service');
      });

      test('omitted dimensions remain null', () {
        final context = Context(type: 'only-type');
        expect(context.type, 'only-type');
        expect(context.identity, isNull);
        expect(context.taxonomy, isNull);
        expect(context.domains, isNull);
        expect(context.constraints, isNull);
        expect(context.compliance, isNull);
      });

      test('index operator returns local dimension values', () {
        final context = Context(
          type: 'gateway',
          domains: 'system',
          constraints: {'rate_limit': 1000},
        );
        expect(context[Ontology.type], 'gateway');
        expect(context[Ontology.domains], 'system');
        expect(context[Ontology.constraints], {'rate_limit': 1000});
        expect(context[Ontology.taxonomy], isNull);
        expect(context[Mandate.role], isNull);
      });
    });

    group('fromEntries', () {
      test('builds a context from governance entries', () {
        final context = Context.fromEntries([
          Ontology.type.entry('payment_processor'),
          Ontology.domains.entry('finance'),
          Ontology.constraints.entry({'max_amount': 10000}),
          Ontology.compliance.entry('PCI-DSS'),
        ]);
        expect(context.type, 'payment_processor');
        expect(context.domains, 'finance');
        expect(context.constraints, {'max_amount': 10000});
        expect(context.compliance, 'PCI-DSS');
      });

      test('inherits unset dimensions from an explicit parent', () {
        final parent = Context(
          domains: 'finance',
          taxonomy: 'module',
          identity: 'root',
        );
        final child = Context.fromEntries([
          Ontology.subDomains.entry('payments'),
          Ontology.identity.entry('child'),
        ], parent: parent);

        expect(child.subDomains, 'payments');
        expect(child.identity, 'child');
        expect(child.domains, 'finance');
        expect(child.taxonomy, 'module');
        expect(parent.identity, 'root');
        expect(parent.subDomains, isNull);
      });

      test('local values shadow parent values', () {
        final parent = Context(identity: 'parent', type: 'base');
        final child = Context.fromEntries([
          Ontology.identity.entry('child'),
        ], parent: parent);
        expect(child.identity, 'child');
        expect(child.type, 'base');
        expect(child[Ontology.identity], 'child');
        expect(child[Ontology.type], 'base');
      });
    });

    group('named factories', () {
      test('core is a system-space infrastructure blueprint', () {
        final context = Context.core(
          'Gateway',
          identity: 'Public_Ingress_01',
          partOf: 'Edge_Service',
        );
        expect(context.type, 'Gateway');
        expect(context.identity, 'Public_Ingress_01');
        expect(context.partOf, 'Edge_Service');
        expect(context.taxonomy, 'core');
        expect(context.domains, 'system');
      });

      test('module is a user-space application blueprint', () {
        final context = Context.module(
          'PaymentEngine',
          identity: 'V3_Processor',
          partOf: 'Checkout_Service',
        );
        expect(context.type, 'PaymentEngine');
        expect(context.identity, 'V3_Processor');
        expect(context.partOf, 'Checkout_Service');
        expect(context.taxonomy, 'module');
        expect(context.domains, 'logic');
      });

      test('secureEnclave is a privileged security environment', () {
        final context = Context.secureEnclave(
          partOf: 'CryptoModule',
          compliances: 'FIPS-140-2, PCI-DSS',
        );
        expect(context.partOf, 'CryptoModule');
        expect(context.taxonomy, 'enclave');
        expect(context.domains, 'security');
        expect(context.subDomains, 'integrity-gate');
        expect(context.compliance, 'FIPS-140-2, PCI-DSS');
        expect(context.isNot, 'External_Signals,Unauthenticated_Telemetry');
      });

      test('publicInterface is a sanitized ingress boundary', () {
        final context = Context.publicInterface(
          partOf: 'Public_Web_API',
          domains: 'Web/v1',
          stakeholders: 'Mobile_App_Users, Partner_SDK',
        );
        expect(context.partOf, 'Public_Web_API');
        expect(context.taxonomy, 'interface');
        expect(context.domains, 'Web/v1');
        expect(context.subDomains, 'ingress');
        expect(context.stakeholders, 'Mobile_App_Users, Partner_SDK');
        expect(context.isNot, 'Internal_Commands,Private_State_Mutation');
      });

      test('shieldedCortex isolates high-reasoning logic', () {
        final context = Context.shieldedCortex(
          partOf: 'Trading_Floor_A',
          domains: 'Finance/HighFreq',
          compliances: 'SEC, FINRA',
        );
        expect(context.partOf, 'Trading_Floor_A');
        expect(context.taxonomy, 'cortex');
        expect(context.domains, 'Finance/HighFreq');
        expect(context.subDomains, 'reasoning-enclave');
        expect(context.compliance, 'SEC, FINRA');
        expect(context.isNot, 'Background_Noise,Unverified_Inference');
      });

      test('receptor hydrates inbound sensory sources', () {
        final context = Context.receptor(
          dataSources: 'MQTT_Broker, IoT_Devices',
          domains: 'Telemetry',
        );
        expect(context.dataSources, 'MQTT_Broker, IoT_Devices');
        expect(context.domains, 'Telemetry');
        expect(context.subDomains, 'Receptor');
        expect(context.taxonomy, 'sensor_receptor');
      });

      test('integrityGate is a judicial validation barrier', () {
        final context = Context.integrityGate(
          partOf: 'Treasury/Compliance',
          compliances: 'SOX, Internal_Policy_v2',
        );
        expect(context.partOf, 'Treasury/Compliance');
        expect(context.taxonomy, 'governance_gate');
        expect(context.domains, 'security');
        expect(context.subDomains, 'integrity-gate');
        expect(context.compliance, 'SOX, Internal_Policy_v2');
      });

      test('homeostasis is a metabolic stability loop', () {
        final context = Context.homeostasis(
          partOf: 'System/Memory',
          label: 'LruCacheMonitor',
        );
        expect(context.partOf, 'System/Memory');
        expect(context.taxonomy, 'stability_loop');
        expect(context.domains, 'system');
        expect(context.subDomains, 'Homeostasis');
      });

      test('sandbox is a speculative simulation workspace', () {
        final context = Context.sandbox(
          partOf: 'Finance/Strategies',
          reason: 'Evaluating heuristic v2 performance',
        );
        expect(context.partOf, 'Finance/Strategies');
        expect(context.taxonomy, 'simulation_workspace');
        expect(context.subDomains, 'Sandbox');
      });

      test('auditLog is a forensic compliance ledger', () {
        final context = Context.auditLog(
          partOf: 'Treasury/Ledger',
          compliances: 'PCI-DSS, SOC2',
        );
        expect(context.partOf, 'Treasury/Ledger');
        expect(context.taxonomy, 'audit_ledger');
        expect(context.domains, 'maintenance');
        expect(context.subDomains, 'compliance-logging');
        expect(context.compliance, 'PCI-DSS, SOC2');
      });

      test('transientTask is a leased ephemeral worker', () {
        final context = Context.transientTask(
          partOf: 'System/Maintenance',
          stakeholders: 'MigrationTeam',
          lease: Duration(hours: 1),
        );
        expect(context.partOf, 'System/Maintenance');
        expect(context.taxonomy, 'transient_worker');
        expect(context.stakeholders, 'MigrationTeam');
        expect(context.subDomains, 'Ephemeral_Task');
      });
    });

    group('Context.deputy and Context.pulse', () {
      test('deputy factory returns a DeputyContext', () {
        final base = Context.module('RoomController', identity: 'Room_302');
        final deputy = Context.deputy(
          baseContext: base,
          authority: 'LIGHTS_AND_TEMP',
          role: 'Housekeeping',
          isolation: Isolation.scoped,
          clearance: Clearance.standard,
          justification: 'Daily cleaning cycle',
        );
        expect(deputy, isA<DeputyContext>());
        final mandate = deputy as DeputyContext;
        expect(mandate[Mandate.authority], 'LIGHTS_AND_TEMP');
        expect(mandate.role, 'Housekeeping');
        expect(mandate.justification, 'Daily cleaning cycle');
        expect(mandate.type, 'RoomController');
        expect(mandate.identity, 'Room_302');
      });

      test('pulse factory returns a PulseContext', () {
        final pulse = Context.pulse(
          actor: 'service_daemon',
          reason: 'Cache invalidation',
          purpose: 'MAINTENANCE',
          priority: 30,
          traceId: 'custom-trace-123',
        );
        expect(pulse, isA<PulseContext>());
        final provenance = pulse as PulseContext;
        expect(provenance.actor, 'service_daemon');
        expect(provenance.reason, 'Cache invalidation');
        expect(provenance.purpose, 'MAINTENANCE');
        expect(provenance.priority, 30);
        expect(provenance.traceId, 'custom-trace-123');
      });
    });

    group('evolve', () {
      test('refines fluid boundaries and preserves the original', () {
        final original = Context.module('Original', identity: 'v1');
        final evolved = original.evolve((evolvable) {
          if (evolvable == Ontology.type) {
            return Ontology.type.entry('Evolved');
          }
          if (evolvable == Ontology.identity) {
            return Ontology.identity.entry('v2');
          }
          if (evolvable == Ontology.subDomains) {
            return Ontology.subDomains.entry('specialized');
          }
          return null;
        });

        expect(original.type, 'Original');
        expect(original.identity, 'v1');
        expect(original.subDomains, isNull);
        expect(evolved.type, 'Evolved');
        expect(evolved.identity, 'v2');
        expect(evolved.subDomains, 'specialized');
        expect(evolved.taxonomy, 'module');
        expect(evolved.domains, 'logic');
      });

      test('ignores attempts to change static pillars', () {
        final original = Context(
          taxonomy: 'module',
          domains: 'finance',
          version: '1.0.0',
          type: 'Ledger',
        );
        final evolved = original.evolve((evolvable) {
          if (evolvable == Ontology.taxonomy) {
            return Ontology.taxonomy.entry('hacked');
          }
          if (evolvable == Ontology.domains) {
            return Ontology.domains.entry('unrelated');
          }
          if (evolvable == Ontology.version) {
            return Ontology.version.entry('9.9.9');
          }
          if (evolvable == Ontology.type) {
            return Ontology.type.entry('LedgerV2');
          }
          return null;
        });

        expect(evolved.taxonomy, 'module');
        expect(evolved.domains, 'finance');
        expect(evolved.version, '1.0.0');
        expect(evolved.type, 'LedgerV2');
      });

      test('can tighten constraints and compliance', () {
        final original = Context(
          constraints: {'max_value': 100},
          compliances: 'SOC2',
        );
        final evolved = original.evolve((evolvable) {
          if (evolvable == Ontology.constraints) {
            return Ontology.constraints.entry({'max_value': 50, 'read_only': true});
          }
          if (evolvable == Ontology.compliance) {
            return Ontology.compliance.entry('SOC2, GDPR');
          }
          return null;
        });
        expect(original.constraints, {'max_value': 100});
        expect(evolved.constraints, {'max_value': 50, 'read_only': true});
        expect(evolved.compliance, 'SOC2, GDPR');
      });
    });

    group('lineage', () {
      test('is empty when the dimension was never set', () {
        expect(Context().lineage(Ontology.subDomains), isEmpty);
      });

      test('returns the local value for a root context', () {
        final context = Context(subDomains: 'payments');
        expect(context.lineage(Ontology.subDomains), ['payments']);
      });

      test('walks the parent chain from root to leaf', () {
        final root = Context(subDomains: 'finance', identity: 'root');
        final mid = root.evolve((evolvable) {
          if (evolvable == Ontology.subDomains) {
            return Ontology.subDomains.entry('payments');
          }
          return null;
        });
        final leaf = mid.evolve((evolvable) {
          if (evolvable == Ontology.subDomains) {
            return Ontology.subDomains.entry('refunds');
          }
          if (evolvable == Ontology.identity) {
            return Ontology.identity.entry('leaf');
          }
          return null;
        });

        expect(leaf.lineage(Ontology.subDomains), ['finance', 'payments', 'refunds']);
        expect(leaf.lineage(Ontology.identity), ['root', 'leaf']);
        expect(mid.lineage(Ontology.subDomains), ['finance', 'payments']);
      });
    });

    group('equality', () {
      test('identical instances are equal', () {
        final context = Context.module('Auth');
        expect(context, same(context));
        expect(context, equals(context));
      });

      test('independently constructed contexts are distinct records', () {
        final a = Context(type: 'Gateway', identity: 'ingress');
        final b = Context(type: 'Gateway', identity: 'ingress');
        expect(identical(a, b), isFalse);
        expect(a, isNot(equals(b)));
        expect(a.type, b.type);
        expect(a.identity, b.identity);
      });

      test('different dimensions are not equal', () {
        final a = Context.module('Auth');
        final b = Context.module('Billing');
        expect(a, isNot(equals(b)));
      });

      test('an evolved child is not equal to its parent', () {
        final parent = Context.module('Auth', identity: 'root');
        final child = parent.evolve((evolvable) {
          if (evolvable == Ontology.identity) {
            return Ontology.identity.entry('child');
          }
          return null;
        });
        expect(child, isNot(equals(parent)));
      });

      test('system is not equal to an empty constructed context', () {
        expect(Context.system, isNot(equals(Context())));
      });
    });
  });

  group('Mandate', () {
    test('role is a static pillar; remaining dimensions are fluid', () {
      expect(Mandate.role.evolvable, isFalse);
      expect(Mandate.authority.evolvable, isTrue);
      expect(Mandate.isolation.evolvable, isTrue);
      expect(Mandate.sovereignty.evolvable, isTrue);
      expect(Mandate.clearance.evolvable, isTrue);
      expect(Mandate.auditLevel.evolvable, isTrue);
      expect(Mandate.justification.evolvable, isTrue);
      expect(Mandate.constraints.evolvable, isTrue);
    });

    test('isType validates mandate value types', () {
      expect(Mandate.role.isType('Auditor'), isTrue);
      expect(Mandate.role.isType(1), isFalse);
      expect(Mandate.clearance.isType(Clearance.standard), isTrue);
      expect(Mandate.isolation.isType(Isolation.sandboxed), isTrue);
      expect(Mandate.constraints.isType({'max_hop_count': 5}), isTrue);
    });

    test('compose and evolve filter dimensions correctly', () {
      final composed = Mandate.compose((dimension) {
        if (dimension == Mandate.role) return Mandate.role.entry('Auditor');
        if (dimension == Mandate.authority) {
          return Mandate.authority.entry('READ');
        }
        return null;
      }).toList();
      expect(composed, hasLength(2));

      final seen = <Governance>[];
      final evolved = Mandate.evolve((evolvable) {
        seen.add(evolvable);
        return null;
      }).toList();
      expect(evolved, isEmpty);
      expect(seen, isNot(contains(Mandate.role)));
      expect(seen, contains(Mandate.authority));
      expect(seen, contains(Mandate.clearance));
    });
  });

  group('DeputyContext', () {
    group('system', () {
      test('exposes safe mandate defaults', () {
        expect(identical(DeputyContext.system, DeputyContext.system), isTrue);
        expect(DeputyContext.system.role, isNull);
        expect(DeputyContext.system.justification, isNull);
        expect(DeputyContext.system.clearance, Clearance.standard);
        expect(DeputyContext.system.isolation, Isolation.scoped);
        expect(DeputyContext.system.sovereignty, Sovereignty.sovereign);
        expect(DeputyContext.system.auditLevel, AuditLevel.standard);
        expect(DeputyContext.system.taxonomy, isNull);
        expect(DeputyContext.system[Mandate.authority], isNull);
        expect(DeputyContext.system.lineage(Ontology.domains), isEmpty);
        expect(DeputyContext.system.compliance, isNull);
        expect(DeputyContext.system.constraints, isNull);
        expect(DeputyContext.system.dataSources, isNull);
        expect(DeputyContext.system.domains, isNull);
        expect(DeputyContext.system.isNot, isNull);
        expect(DeputyContext.system.partOf, isNull);
        expect(DeputyContext.system.stakeholders, isNull);
        expect(DeputyContext.system.subDomains, isNull);
        expect(DeputyContext.system.topology, isNull);
        expect(DeputyContext.system.version, isNull);
        expect(DeputyContext.system.identity, isNull);
        expect(DeputyContext.system.type, isNull);
      });

      test('evolve from system creates a specialized deputy', () {
        final evolved = DeputyContext.system.evolve((evolvable) {
          if (evolvable == Mandate.justification) {
            return Mandate.justification.entry('narrowed');
          }
          return null;
        });
        expect(evolved, isA<DeputyContext>());
        expect(evolved.justification, 'narrowed');
        expect(DeputyContext.system.justification, isNull);
      });
    });

    group('constructor', () {
      test('requires authority and links ontology from the base context', () {
        final base = Context.module(
          'RoomController',
          identity: 'Room_302_Master',
        );
        final deputy = DeputyContext(
          baseContext: base,
          authority: 'LIGHTS_AND_TEMP',
          role: 'Housekeeping',
          isolation: Isolation.restricted,
          clearance: Clearance.administrative,
          justification: 'Daily cleaning cycle',
          constraints: {'max_hop_count': 3},
        );

        expect(deputy[Mandate.authority], 'LIGHTS_AND_TEMP');
        expect(deputy.role, 'Housekeeping');
        expect(deputy.isolation, Isolation.restricted);
        expect(deputy.clearance, Clearance.administrative);
        expect(deputy.justification, 'Daily cleaning cycle');
        expect(deputy.constraints, {'max_hop_count': 3});
        expect(deputy.type, 'RoomController');
        expect(deputy.identity, 'Room_302_Master');
        expect(deputy.taxonomy, 'module');
        expect(deputy.domains, 'logic');
      });

      test('defaults isolation, clearance, sovereignty, and auditLevel', () {
        final deputy = DeputyContext(
          baseContext: Context.system,
          authority: 'READ',
        );
        expect(deputy.isolation, Isolation.scoped);
        expect(deputy.clearance, Clearance.standard);
        expect(deputy.sovereignty, Sovereignty.sovereign);
        expect(deputy.auditLevel, AuditLevel.standard);
        expect(deputy.role, isNull);
        expect(deputy.justification, isNull);
        expect(deputy.constraints, isNull);
      });

      test('stores standard clearance when it is the default', () {
        final deputy = DeputyContext(
          baseContext: Context.system,
          authority: 'READ',
          clearance: Clearance.standard,
        );
        expect(deputy.clearance, Clearance.standard);
      });
    });

    group('named factories', () {
      late Context base;

      setUp(() {
        base = Context.module('Principal', identity: 'root');
      });

      test('observer is a read-oriented monitoring mandate', () {
        final deputy = DeputyContext.observer(
          baseContext: base,
          task: 'Render Dashboard',
          clearance: Clearance.observational,
        );
        expect(deputy[Mandate.authority], 'OBSERVATION');
        expect(deputy.role, 'Observer');
        expect(deputy.clearance, Clearance.observational);
        expect(deputy.type, 'Principal');
      });

      test('delegate is an operational mutating mandate', () {
        final deputy = DeputyContext.delegate(
          baseContext: base,
          task: 'PRUNE_EXPIRED_TOKENS',
        );
        expect(deputy[Mandate.authority], 'DELEGATED_TASK');
        expect(deputy.role, 'Delegate');
        expect(deputy.clearance, Clearance.standard);
      });

      test('sandbox virtualizes mutations', () {
        final deputy = DeputyContext.sandbox(
          baseContext: base,
          role: 'Profit_Projection_Model',
        );
        expect(deputy[Mandate.authority], 'SIMULATE');
        expect(deputy.role, 'Profit_Projection_Model');
        expect(deputy.isolation, Isolation.sandboxed);
        expect(deputy.clearance, Clearance.minimal);
      });

      test('sandbox default role is Reasoning_Sandbox', () {
        final deputy = DeputyContext.sandbox(baseContext: base);
        expect(deputy.role, 'Reasoning_Sandbox');
      });

      test('intervention is an emergency sentinel mandate', () {
        final deputy = DeputyContext.intervention(
          baseContext: base,
          reason: 'Isolating compromised node #502',
        );
        expect(deputy[Mandate.authority], 'SYSTEM_PROTECTION');
        expect(deputy.role, 'Sentinel');
        expect(deputy.clearance, Clearance.administrative);
      });

      test('janitor is a structural hygiene mandate', () {
        final deputy = DeputyContext.janitor(
          baseContext: base,
          target: 'Telemetry_Buffer',
        );
        expect(deputy[Mandate.authority], 'RESOURCE_MANAGEMENT');
        expect(deputy.role, 'Janitor');
        expect(deputy.clearance, Clearance.administrative);
      });

      test('architect is an infrastructure orchestration mandate', () {
        final deputy = DeputyContext.architect(
          baseContext: base,
          mission: 'Scaling up the payment module',
        );
        expect(deputy[Mandate.authority], 'INFRASTRUCTURE_EVOLUTION');
        expect(deputy.role, 'Architect');
        expect(deputy.clearance, Clearance.standard);
      });

      test('auditor is a read-only compliance witness', () {
        final deputy = DeputyContext.auditor(
          baseContext: base,
          regulation: 'SOC2',
        );
        expect(deputy[Mandate.authority], 'REGULATORY_AUDIT');
        expect(deputy.role, 'Witness');
        expect(deputy.clearance, Clearance.observational);
      });

      test('ambassador is a cross-domain negotiator', () {
        final deputy = DeputyContext.ambassador(
          baseContext: base,
          targetDomain: 'Partner_API',
        );
        expect(deputy[Mandate.authority], 'CROSS_DOMAIN_COMMUNICATION');
        expect(deputy.role, 'Ambassador');
        expect(deputy.clearance, Clearance.minimal);
      });

      test('shielded is a privileged enclave mandate', () {
        final deputy = DeputyContext.shielded(
          baseContext: base,
          reason: 'Processing payment keys',
        );
        expect(deputy[Mandate.authority], 'SECURE_REASONING');
        expect(deputy.role, 'Sentinel');
        expect(deputy.clearance, Clearance.administrative);
      });

      test('gatekeeper is a policy enforcement mandate', () {
        final deputy = DeputyContext.gatekeeper(baseContext: base);
        expect(deputy[Mandate.authority], 'GOVERNANCE_ENFORCEMENT');
        expect(deputy.role, 'Gatekeeper');
        expect(deputy.clearance, Clearance.observational);
      });

      test('homeostasis is a background maintenance mandate', () {
        final deputy = DeputyContext.homeostasis(baseContext: base);
        expect(deputy[Mandate.authority], 'SYSTEM_MAINTENANCE');
        expect(deputy.role, 'Service_Daemon');
        expect(deputy.clearance, Clearance.standard);
      });
    });

    group('fromEntries', () {
      test('can assemble a mandate from mixed ontology and mandate entries', () {
        final parent = Context.module('Vault');
        final deputy = DeputyContext.fromEntries([
          Mandate.authority.entry('SIGN'),
          Mandate.role.entry('Notary'),
          Mandate.auditLevel.entry(AuditLevel.full),
          Mandate.sovereignty.entry(Sovereignty.supervised),
          Ontology.identity.entry('notary-1'),
        ], parent: parent);

        expect(deputy[Mandate.authority], 'SIGN');
        expect(deputy.role, 'Notary');
        expect(deputy.auditLevel, AuditLevel.full);
        expect(deputy.sovereignty, Sovereignty.supervised);
        expect(deputy.identity, 'notary-1');
        expect(deputy.taxonomy, 'module');
      });
    });

    group('evolve', () {
      test('refines fluid mandate dimensions and keeps role immutable', () {
        final original = DeputyContext(
          baseContext: Context.module('Auth'),
          authority: 'READ, WRITE',
          role: 'Delegate',
          clearance: Clearance.administrative,
          justification: 'Primary task',
        );
        final evolved = original.evolve((evolvable) {
          if (evolvable == Mandate.clearance) {
            return Mandate.clearance.entry(Clearance.observational);
          }
          if (evolvable == Mandate.authority) {
            return Mandate.authority.entry('READ');
          }
          if (evolvable == Mandate.justification) {
            return Mandate.justification.entry('Sub-task audit');
          }
          if (evolvable == Mandate.role) {
            return Mandate.role.entry('Impostor');
          }
          if (evolvable == Mandate.auditLevel) {
            return Mandate.auditLevel.entry(AuditLevel.full);
          }
          if (evolvable == Ontology.identity) {
            return Ontology.identity.entry('auth-readonly');
          }
          return null;
        });

        expect(original.role, 'Delegate');
        expect(original.clearance, Clearance.administrative);
        expect(original[Mandate.authority], 'READ, WRITE');
        expect(evolved.role, 'Delegate');
        expect(evolved.clearance, Clearance.observational);
        expect(evolved[Mandate.authority], 'READ');
        expect(evolved.justification, 'Sub-task audit');
        expect(evolved.auditLevel, AuditLevel.full);
        expect(evolved.identity, 'auth-readonly');
        expect(evolved.taxonomy, 'module');
      });

      test('inherits unset mandate fields from the parent deputy', () {
        final parent = DeputyContext(
          baseContext: Context.system,
          authority: 'WRITE',
          role: 'Delegate',
          isolation: Isolation.restricted,
          justification: 'parent-mission',
        );
        final child = parent.evolve((evolvable) {
          if (evolvable == Mandate.clearance) {
            return Mandate.clearance.entry(Clearance.minimal);
          }
          return null;
        });
        expect(child.role, 'Delegate');
        expect(child.isolation, Isolation.restricted);
        expect(child.justification, 'parent-mission');
        expect(child[Mandate.authority], 'WRITE');
        expect(child.clearance, Clearance.minimal);
        expect(parent.clearance, Clearance.standard);
      });
    });

    group('equality', () {
      test('independently constructed deputies are distinct records', () {
        final base = Context.module('Auth');
        final a = DeputyContext(
          baseContext: base,
          authority: 'READ',
          role: 'Observer',
        );
        final b = DeputyContext(
          baseContext: base,
          authority: 'READ',
          role: 'Observer',
        );
        expect(identical(a, b), isFalse);
        expect(a, isNot(equals(b)));
        expect(a.role, b.role);
        expect(a[Mandate.authority], b[Mandate.authority]);
      });

      test('different authority values are not equal', () {
        final base = Context.system;
        final a = DeputyContext(baseContext: base, authority: 'READ');
        final b = DeputyContext(baseContext: base, authority: 'WRITE');
        expect(a, isNot(equals(b)));
      });
    });
  });

  group('Clearance', () {
    test('levels are ranked from observational to unrestricted', () {
      expect(Clearance.observational.level, 0);
      expect(Clearance.minimal.level, 1);
      expect(Clearance.standard.level, 2);
      expect(Clearance.administrative.level, 3);
      expect(Clearance.privileged.level, 4);
      expect(Clearance.unrestricted.level, 5);
    });

    test('authorizes is inclusive of the required rank', () {
      expect(Clearance.administrative.authorizes(Clearance.standard), isTrue);
      expect(Clearance.standard.authorizes(Clearance.standard), isTrue);
      expect(Clearance.observational.authorizes(Clearance.standard), isFalse);
      expect(Clearance.unrestricted.authorizes(Clearance.privileged), isTrue);
    });
  });

  group('Isolation', () {
    test('virtualization starts at sandboxed', () {
      expect(Isolation.shared.isVirtual, isFalse);
      expect(Isolation.scoped.isVirtual, isFalse);
      expect(Isolation.restricted.isVirtual, isFalse);
      expect(Isolation.sandboxed.isVirtual, isTrue);
      expect(Isolation.total.isVirtual, isTrue);
    });

    test('only restricted is guarded', () {
      expect(Isolation.restricted.isGuarded, isTrue);
      expect(Isolation.scoped.isGuarded, isFalse);
      expect(Isolation.sandboxed.isGuarded, isFalse);
    });
  });

  group('Sovereignty', () {
    test('supervised requires approval; preemptive can override', () {
      expect(Sovereignty.supervised.requiresApproval, isTrue);
      expect(Sovereignty.collaborative.requiresApproval, isFalse);
      expect(Sovereignty.sovereign.requiresApproval, isFalse);
      expect(Sovereignty.preemptive.requiresApproval, isFalse);
      expect(Sovereignty.preemptive.isPreemptive, isTrue);
      expect(Sovereignty.sovereign.isPreemptive, isFalse);
    });
  });

  group('AuditLevel', () {
    test('deep reasoning starts at detailed; none is silent', () {
      expect(AuditLevel.none.isSilent, isTrue);
      expect(AuditLevel.minimal.isSilent, isFalse);
      expect(AuditLevel.standard.requiresDeepReasoning, isFalse);
      expect(AuditLevel.detailed.requiresDeepReasoning, isTrue);
      expect(AuditLevel.full.requiresDeepReasoning, isTrue);
    });
  });

  group('Provenance', () {
    test('static pillars are not evolvable', () {
      expect(Provenance.actor.evolvable, isFalse);
      expect(Provenance.compliance.evolvable, isFalse);
      expect(Provenance.sensitivity.evolvable, isFalse);
      expect(Provenance.traceId.evolvable, isFalse);
      expect(Provenance.parentTraceId.evolvable, isFalse);
      expect(Provenance.integrity.evolvable, isFalse);
    });

    test('fluid boundaries are evolvable', () {
      expect(Provenance.reason.evolvable, isTrue);
      expect(Provenance.purpose.evolvable, isTrue);
      expect(Provenance.strategy.evolvable, isTrue);
      expect(Provenance.confidence.evolvable, isTrue);
      expect(Provenance.priority.evolvable, isTrue);
      expect(Provenance.auditLevel.evolvable, isTrue);
    });

    test('isType validates provenance value types', () {
      expect(Provenance.actor.isType('admin'), isTrue);
      expect(Provenance.confidence.isType(0.8), isTrue);
      expect(Provenance.confidence.isType('0.8'), isFalse);
      expect(Provenance.priority.isType(80), isTrue);
      expect(Provenance.sensitivity.isType(Sensitivity.secret), isTrue);
    });

    test('compose includes resolved dimensions', () {
      final entries = Provenance.compose((dimension) {
        switch (dimension) {
          case Provenance.actor:
            return Provenance.actor.entry('admin_01');
          case Provenance.reason:
            return Provenance.reason.entry('Manual override');
          case Provenance.priority:
            return Provenance.priority.entry(80);
          default:
            return null;
        }
      }).toList();
      expect(entries, hasLength(3));
    });

    test('evolve excludes static pillars', () {
      final seen = <Governance>[];
      Provenance.evolve((evolvable) {
        seen.add(evolvable);
        return null;
      }).toList();
      expect(seen, isNot(contains(Provenance.actor)));
      expect(seen, isNot(contains(Provenance.traceId)));
      expect(seen, contains(Provenance.reason));
      expect(seen, contains(Provenance.priority));
    });
  });

  group('PulseContext', () {
    group('system', () {
      test('is an empty telemetric fallback', () {
        expect(identical(PulseContext.system, PulseContext.system), isTrue);
        expect(PulseContext.system.actor, isNull);
        expect(PulseContext.system.reason, isNull);
        expect(PulseContext.system.purpose, isNull);
        expect(PulseContext.system.strategy, isNull);
        expect(PulseContext.system.confidence, isNull);
        expect(PulseContext.system.priority, isNull);
        expect(PulseContext.system.compliance, isNull);
        expect(PulseContext.system.sensitivity, isNull);
        expect(PulseContext.system.auditLevel, isNull);
        expect(PulseContext.system.traceId, isNull);
        expect(PulseContext.system.parentTraceId, isNull);
        expect(PulseContext.system.integrity, isNull);
        expect(PulseContext.system.others, isNull);
        expect(PulseContext.system[Provenance.actor], isNull);
      });

      test('evolve from system creates a specialized pulse context', () {
        final evolved = PulseContext.system.evolve((evolvable) {
          if (evolvable == Provenance.reason) {
            return Provenance.reason.entry('from-system');
          }
          return null;
        });
        expect(evolved.reason, 'from-system');
        expect(PulseContext.system.reason, isNull);
      });
    });

    group('constructor', () {
      test('stores every named provenance dimension', () {
        final context = PulseContext(
          actor: 'service_daemon',
          reason: 'Cache invalidation',
          purpose: 'MAINTENANCE',
          strategy: ReasoningStrategy.deterministic,
          confidence: 0.95,
          priority: 30,
          compliance: 'SOC2',
          sensitivity: Sensitivity.internal,
          auditLevel: AuditLevel.minimal,
          traceId: 'custom-trace-123',
          parentTraceId: 'parent-trace-000',
        );
        expect(context.actor, 'service_daemon');
        expect(context.reason, 'Cache invalidation');
        expect(context.purpose, 'MAINTENANCE');
        expect(context.strategy, ReasoningStrategy.deterministic);
        expect(context.confidence, 0.95);
        expect(context.priority, 30);
        expect(context.compliance, 'SOC2');
        expect(context.sensitivity, Sensitivity.internal);
        expect(context.auditLevel, AuditLevel.minimal);
        expect(context.traceId, 'custom-trace-123');
        expect(context.parentTraceId, 'parent-trace-000');
        expect(context.integrity, isNull);
      });

      test('auto-generates a unique traceId when omitted', () {
        final a = PulseContext(actor: 'admin');
        final b = PulseContext(actor: 'admin');
        expect(a.traceId, isNotNull);
        expect(a.traceId, isNotEmpty);
        expect(a.traceId, isNot(equals(b.traceId)));
      });

      test('does not auto-link parentTraceId from a generic base context', () {
        final context = PulseContext(
          baseContext: Context.system,
          actor: 'admin',
        );
        expect(context.parentTraceId, isNull);
      });

      test('inherits ontology from a ContextBase parent', () {
        final base = Context.module('PaymentEngine', identity: 'V3');
        final context = PulseContext(
          baseContext: base,
          actor: 'cashier',
          reason: 'checkout',
        );
        expect(context.type, 'PaymentEngine');
        expect(context.identity, 'V3');
        expect(context.taxonomy, 'module');
        expect(context.actor, 'cashier');
      });

      test('inherits provenance from a PulseContext parent', () {
        final parent = PulseContext(
          actor: 'orchestrator',
          reason: 'root cause',
          purpose: 'PARENT_MISSION',
          traceId: 'root-trace',
        );
        final child = PulseContext(
          baseContext: parent,
          purpose: 'CHILD_MISSION',
        );
        expect(child.actor, 'orchestrator');
        expect(child.reason, 'root cause');
        expect(child.purpose, 'CHILD_MISSION');
        expect(child.traceId, isNot(equals('root-trace')));
        expect(child[Provenance.actor], 'orchestrator');
      });

      test('stores others even without a parent', () {
        final context = PulseContext(
          actor: 'admin',
          others: {'region': 'eu-west', 'ticket': 42},
        );
        expect(context.others, {'region': 'eu-west', 'ticket': 42});
      });

      test('stores others when a parent is also provided', () {
        final parent = PulseContext(actor: 'parent', others: {'from': 'parent'});
        final child = PulseContext(
          baseContext: parent,
          actor: 'child',
          others: {'from': 'child'},
        );
        expect(child.others, {'from': 'child'});
      });
    });

    group('named factories', () {
      test('userAction captures explicit human intent', () {
        final context = PulseContext.userAction(
          baseContext: Context.system,
          actor: 'user_123',
          reason: 'Profile update',
          purpose: 'TRANSACTION_COMMIT',
          priority: 70,
          sensitivity: Sensitivity.private,
        );
        expect(context.actor, 'user_123');
        expect(context.reason, 'Profile update');
        expect(context.purpose, 'TRANSACTION_COMMIT');
        expect(context.strategy, ReasoningStrategy.manual);
        expect(context.confidence, 1.0);
        expect(context.priority, 70);
        expect(context.auditLevel, AuditLevel.standard);
        expect(context.sensitivity, Sensitivity.private);
        expect(context.traceId, isNotNull);
      });

      test('userAction defaults purpose, priority, and sensitivity', () {
        final context = PulseContext.userAction(
          baseContext: Context.system,
          actor: 'user_123',
          reason: 'Click',
        );
        expect(context.purpose, 'USER_INTERACTION');
        expect(context.priority, 60);
        expect(context.sensitivity, Sensitivity.public);
      });

      test('aiInference captures probabilistic autonomous intent', () {
        final context = PulseContext.aiInference(
          baseContext: Context.system,
          actor: 'Heuristic_Optimizer_v2',
          reason: 'Detected high latency',
          confidence: 0.82,
        );
        expect(context.actor, 'Heuristic_Optimizer_v2');
        expect(context.strategy, ReasoningStrategy.probabilistic);
        expect(context.confidence, 0.82);
        expect(context.priority, 20);
        expect(context.auditLevel, AuditLevel.detailed);
        expect(context.sensitivity, Sensitivity.internal);
        expect(context.purpose, 'AUTONOMOUS_OPTIMIZATION');
      });

      test('inference matches the aiInference blueprint', () {
        final context = PulseContext.inference(
          baseContext: Context.system,
          actor: 'Resource_Optimizer_Agent',
          reason: 'Detected high latency',
          confidence: 0.82,
          purpose: 'RESOURCE_SCALING',
        );
        expect(context.strategy, ReasoningStrategy.probabilistic);
        expect(context.auditLevel, AuditLevel.detailed);
        expect(context.purpose, 'RESOURCE_SCALING');
        expect(context.confidence, 0.82);
      });

      test('regulated forces forensic compliance markers', () {
        final context = PulseContext.regulated(
          actor: 'Payment_Processor_B',
          framework: 'PCI-DSS',
          reason: 'Authorizing Transaction #992',
        );
        expect(context.actor, 'Payment_Processor_B');
        expect(context.compliance, 'PCI-DSS');
        expect(context.sensitivity, Sensitivity.confidential);
        expect(context.auditLevel, AuditLevel.full);
        expect(context.strategy, ReasoningStrategy.deterministic);
        expect(context.priority, 85);
        expect(context.purpose, 'REGULATED_TRANSACTION');
        expect(context.confidence, 1.0);
        expect(context.reason, 'Authorizing Transaction #992');
      });

      test('regulated default reason mentions the framework', () {
        final context = PulseContext.regulated(
          actor: 'Clerk',
          framework: 'HIPAA',
        );
        expect(context.reason, 'Executing within HIPAA framework.');
      });

      test('homeostasis is a low-priority maintenance signal', () {
        final context = PulseContext.homeostasis(
          actor: 'Cache_Janitor_Service',
          reason: 'Evicting stale entries',
          priority: 15,
        );
        expect(context.purpose, 'SYSTEM_MAINTENANCE');
        expect(context.priority, 15);
        expect(context.auditLevel, AuditLevel.minimal);
        expect(context.strategy, ReasoningStrategy.deterministic);
        expect(context.sensitivity, Sensitivity.public);
        expect(context.confidence, 1.0);
      });

      test('systemInternal uses a fixed system_daemon actor', () {
        final context = PulseContext.systemInternal(
          baseContext: Context.system,
          reason: 'Reclaiming stagnant somatic state',
          purpose: 'GARBAGE_COLLECTION',
        );
        expect(context.actor, 'system_daemon');
        expect(context.purpose, 'GARBAGE_COLLECTION');
        expect(context.priority, 35);
        expect(context.auditLevel, AuditLevel.minimal);
        expect(context.strategy, ReasoningStrategy.deterministic);
      });

      test('complianceAudit is a forensic witness signal', () {
        final context = PulseContext.complianceAudit(
          baseContext: Context.system,
          actor: 'Security_Monitor_01',
          framework: 'HIPAA',
          reason: 'Quarterly access log verification',
        );
        expect(context.compliance, 'HIPAA');
        expect(context.sensitivity, Sensitivity.confidential);
        expect(context.auditLevel, AuditLevel.full);
        expect(context.purpose, 'AUDIT_LOG');
        expect(context.priority, 35);
        expect(context.strategy, ReasoningStrategy.deterministic);
      });

      test('selfCorrection prefixes the target field in reason', () {
        final context = PulseContext.selfCorrection(
          baseContext: Context.system,
          actor: 'Homeostasis_Guard',
          reason: 'Value out of bounds (150 > 100)',
          targetField: 'somatic_pressure',
        );
        expect(
          context.reason,
          'Homeostasis Recovery (somatic_pressure): Value out of bounds (150 > 100)',
        );
        expect(context.purpose, 'SELF_HEALING');
        expect(context.priority, 85);
        expect(context.confidence, 0.9);
        expect(context.strategy, ReasoningStrategy.deterministic);
      });

      test('infrastructureChange uses formal strategy', () {
        final context = PulseContext.infrastructureChange(
          baseContext: Context.system,
          actor: 'Orchestrator_Node_A',
          reason: 'Node saturation above 85%',
        );
        expect(context.strategy, ReasoningStrategy.formal);
        expect(context.purpose, 'INFRASTRUCTURE_REFACTOR');
        expect(context.priority, 40);
        expect(context.sensitivity, Sensitivity.internal);
      });

      test('securityIntervention is an emergency shield', () {
        final context = PulseContext.securityIntervention(
          baseContext: Context.system,
          actor: 'Sentinel_Prime',
          reason: 'Brute-force pattern detected',
        );
        expect(context.reason, 'SECURITY_SHIELD: Brute-force pattern detected');
        expect(context.strategy, ReasoningStrategy.reflexive);
        expect(context.priority, 100);
        expect(context.sensitivity, Sensitivity.secret);
        expect(context.auditLevel, AuditLevel.full);
        expect(context.purpose, 'THREAT_MITIGATION');
      });

      test('telemetry is unaudited background observation', () {
        final context = PulseContext.telemetry(
          baseContext: Context.system,
          actor: 'Throughput_Monitor',
          reason: 'Reporting batch completion latency',
        );
        expect(context.purpose, 'METRIC_COLLECTION');
        expect(context.priority, 10);
        expect(context.auditLevel, AuditLevel.none);
        expect(context.sensitivity, Sensitivity.public);
      });

      test('collaboration records a delegation handoff', () {
        final context = PulseContext.collaboration(
          baseContext: Context.system,
          actor: 'Orchestrator_Agent',
          targetAgent: 'Database_Resident',
          task: 'Fetch user transaction history',
        );
        expect(
          context.reason,
          'DELEGATION: Assigning Fetch user transaction history to Database_Resident',
        );
        expect(context.purpose, 'COLLABORATIVE_TASK');
        expect(context.priority, 60);
        expect(context.auditLevel, AuditLevel.full);
        expect(context.sensitivity, Sensitivity.private);
      });

      test('hypothesis is a non-committal simulation', () {
        final context = PulseContext.hypothesis(
          baseContext: Context.system,
          actor: 'Prediction_Agent_01',
          theory: 'Scaling memory allocation by 2x',
        );
        expect(
          context.reason,
          'HYPOTHESIS_TEST: Scaling memory allocation by 2x',
        );
        expect(context.strategy, ReasoningStrategy.stochastic);
        expect(context.confidence, 0.0);
        expect(context.auditLevel, AuditLevel.none);
        expect(context.purpose, 'SIMULATION');
      });

      test('instruction is a critical manual override', () {
        final context = PulseContext.instruction(
          baseContext: Context.system,
          humanActor: 'admin_user_01',
          directive: 'FLUSH_ALL_SOMATIC_BUFFERS',
        );
        expect(context.actor, 'admin_user_01');
        expect(context.reason, 'USER_DIRECTIVE: FLUSH_ALL_SOMATIC_BUFFERS');
        expect(context.purpose, 'MANUAL_OVERRIDE');
        expect(context.priority, 90);
        expect(context.auditLevel, AuditLevel.full);
        expect(context.strategy, ReasoningStrategy.deterministic);
      });

      test('factories link parentTraceId when baseContext is a PulseContext', () {
        final parent = PulseContext(actor: 'root', traceId: 'root-id');
        final child = PulseContext.userAction(
          baseContext: parent,
          actor: 'user_1',
          reason: 'follow-up',
        );
        expect(child.parentTraceId, 'root-id');
        expect(child.traceId, isNot(equals('root-id')));
      });
    });

    group('evolve', () {
      test('refines fluid provenance and preserves static pillars', () {
        final original = PulseContext(
          actor: 'admin_01',
          reason: 'Manual override',
          purpose: 'USER_INTERACTION',
          priority: 60,
          traceId: 'trace-fixed',
          sensitivity: Sensitivity.public,
          compliance: 'SOC2',
        );
        final evolved = original.evolve((evolvable) {
          if (evolvable == Provenance.reason) {
            return Provenance.reason.entry('Refined for storage');
          }
          if (evolvable == Provenance.priority) {
            return Provenance.priority.entry(75);
          }
          if (evolvable == Provenance.actor) {
            return Provenance.actor.entry('malicious_actor');
          }
          if (evolvable == Provenance.traceId) {
            return Provenance.traceId.entry('spoofed');
          }
          if (evolvable == Provenance.compliance) {
            return Provenance.compliance.entry('none');
          }
          return null;
        });

        expect(original.reason, 'Manual override');
        expect(original.priority, 60);
        expect(evolved.reason, 'Refined for storage');
        expect(evolved.priority, 75);
        expect(evolved.actor, 'admin_01');
        expect(evolved.traceId, 'trace-fixed');
        expect(evolved.compliance, 'SOC2');
        expect(evolved.sensitivity, Sensitivity.public);
        expect(evolved.purpose, 'USER_INTERACTION');
      });

      test('can evolve ontology identity alongside provenance', () {
        final original = PulseContext(
          baseContext: Context.module('Auth', identity: 'Auth_Node'),
          actor: 'admin',
        );
        final evolved = original.evolve((evolvable) {
          if (evolvable == Ontology.identity) {
            return Ontology.identity.entry('Auth_Node_ReadOnly');
          }
          if (evolvable == Provenance.purpose) {
            return Provenance.purpose.entry('AUDIT');
          }
          return null;
        });
        expect(evolved.identity, 'Auth_Node_ReadOnly');
        expect(evolved.type, 'Auth');
        expect(evolved.purpose, 'AUDIT');
        expect(evolved.actor, 'admin');
      });

      test('others passed to evolve are stored on the child', () {
        final original = PulseContext(actor: 'admin', others: {'stage': 'root'});
        final evolved = original.evolve(
          (evolvable) {
            if (evolvable == Provenance.reason) {
              return Provenance.reason.entry('next-stage');
            }
            return null;
          },
          others: {'stage': 'child'},
        );
        expect(evolved.others, {'stage': 'child'});
        expect(evolved.reason, 'next-stage');
        expect(original.others, {'stage': 'root'});
      });
    });

    group('lineage and index', () {
      test('index operator walks parent provenance', () {
        final root = PulseContext(actor: 'admin', reason: 'start');
        final child = root.evolve((evolvable) {
          if (evolvable == Provenance.reason) {
            return Provenance.reason.entry('refined');
          }
          return null;
        });
        expect(child[Provenance.actor], 'admin');
        expect(child[Provenance.reason], 'refined');
        expect(child[Provenance.purpose], isNull);
      });

      test('lineage traces evolved ontology identity through a pulse parent', () {
        final base = Context.module('Auth', identity: 'root');
        final pulse = PulseContext(baseContext: base, actor: 'admin');
        final child = pulse.evolve((evolvable) {
          if (evolvable == Ontology.identity) {
            return Ontology.identity.entry('child');
          }
          return null;
        });
        expect(child.lineage(Ontology.identity), ['root', 'child']);
        expect(child.type, 'Auth');
      });
    });

    group('equality', () {
      test('independently constructed pulse contexts are distinct records', () {
        final a = PulseContext(
          actor: 'admin',
          reason: 'update',
          traceId: 't-1',
        );
        final b = PulseContext(
          actor: 'admin',
          reason: 'update',
          traceId: 't-1',
        );
        expect(identical(a, b), isFalse);
        expect(a, isNot(equals(b)));
        expect(a.actor, b.actor);
        expect(a.traceId, b.traceId);
      });

      test('auto-generated traceIds make otherwise identical contexts unequal', () {
        final a = PulseContext(actor: 'admin');
        final b = PulseContext(actor: 'admin');
        expect(a, isNot(equals(b)));
      });
    });
  });

  group('Identity', () {
    test('next generates unique UUID-shaped identifiers', () {
      final a = Identity.next();
      final b = Identity.next();
      expect(a, isNotEmpty);
      expect(a, isNot(equals(b)));
      expect(a.split('-'), hasLength(5));
    });
  });

  group('ReasoningStrategy', () {
    test('classifies stochastic, mandated, and agentic strategies', () {
      expect(ReasoningStrategy.stochastic.isStochastic, isTrue);
      expect(ReasoningStrategy.probabilistic.isStochastic, isFalse);
      expect(ReasoningStrategy.deterministic.isSystemMandated, isTrue);
      expect(ReasoningStrategy.reflexive.isSystemMandated, isTrue);
      expect(ReasoningStrategy.formal.isSystemMandated, isFalse);
      expect(ReasoningStrategy.manual.isAgentic, isTrue);
      expect(ReasoningStrategy.probabilistic.isAgentic, isTrue);
      expect(ReasoningStrategy.deterministic.isAgentic, isFalse);
    });
  });

  group('Sensitivity', () {
    test('masking and high-risk thresholds follow classification rank', () {
      expect(Sensitivity.public.requiresMasking, isFalse);
      expect(Sensitivity.internal.requiresMasking, isFalse);
      expect(Sensitivity.confidential.requiresMasking, isTrue);
      expect(Sensitivity.restricted.requiresMasking, isTrue);
      expect(Sensitivity.restricted.isHighRisk, isTrue);
      expect(Sensitivity.secret.isHighRisk, isTrue);
      expect(Sensitivity.confidential.isHighRisk, isFalse);
    });
  });

  group('PriorityTier', () {
    test('fromValue maps numeric urgency onto semantic tiers', () {
      expect(PriorityTier.fromValue(0), PriorityTier.background);
      expect(PriorityTier.fromValue(20), PriorityTier.background);
      expect(PriorityTier.fromValue(21), PriorityTier.routine);
      expect(PriorityTier.fromValue(50), PriorityTier.routine);
      expect(PriorityTier.fromValue(51), PriorityTier.high);
      expect(PriorityTier.fromValue(80), PriorityTier.high);
      expect(PriorityTier.fromValue(81), PriorityTier.critical);
      expect(PriorityTier.fromValue(95), PriorityTier.critical);
      expect(PriorityTier.fromValue(96), PriorityTier.emergency);
      expect(PriorityTier.fromValue(100), PriorityTier.emergency);
    });

    test('urgent tiers start at critical', () {
      expect(PriorityTier.high.isUrgent, isFalse);
      expect(PriorityTier.critical.isUrgent, isTrue);
      expect(PriorityTier.emergency.isUrgent, isTrue);
    });
  });
}
