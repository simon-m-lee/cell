# How to Use Context in the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What is Context?](#what-is-context)
3. [Core Concepts](#core-concepts)
4. [Context System (Root Context)](#context-system-root-context)
5. [Creating Contexts](#creating-contexts)
6. [Predefined Context Factories](#predefined-context-factories)
7. [Ontology Dimensions](#ontology-dimensions)
8. [Context Inheritance](#context-inheritance)
9. [Using Context with Cells](#using-context-with-cells)
10. [Testing Context](#testing-context)
11. [Best Practices](#best-practices)
12. [Complete Example](#complete-example)

---

## Introduction

**Context** is the operational environment that defines the security tier, execution priority, and administrative authority of a Cell. It acts as a mandatory metadata layer that informs validation rules and processing mechanisms about the provenance and permissions of any entity attempting to interact with a node.

### When to Use Context

| Scenario | Recommended Approach |
|----------|---------------------|
| Default configuration | Use `Context.system` |
| Application logic | Use `Context.module()` |
| Infrastructure nodes | Use `Context.core()` |
| Sensitive operations | Use `Context.secureEnclave()` |
| Public interfaces | Use `Context.publicInterface()` |
| Autonomous reasoning | Use `Context.shieldedCortex()` |
| Input ingestion | Use `Context.receptor()` |
| Policy enforcement | Use `Context.integrityGate()` |
| Maintenance tasks | Use `Context.homeostasis()` |
| Simulation/testing | Use `Context.sandbox()` |

---

## What is Context?

A `Context` is the **operational environment** that defines:

- **Security Tier** - How sensitive is this operation?
- **Execution Priority** - How urgent is this operation?
- **Authority Domain** - What areas does this operate in?
- **Compliance Requirements** - What regulations apply?
- **Stakeholders** - Who is responsible?

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Immutable** | Cannot be modified after creation |
| **Inheritable** | Supports prototype-based inheritance |
| **Type-Safe** | Strong typing with Governance dimensions |
| **Composable** | Can combine multiple dimensions |
| **Auditable** | Provides lineage for tracing |
| **Governed** | Controls what operations are allowed |

### Relationship with Cell

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CELL                                             │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       CONTEXT                                        │   │
│  │                                                                      │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │                    ONTOLOGY (Structural)                     │    │   │
│  │  │  • type: "payment_processor"                                │    │   │
│  │  │  • domains: "finance"                                       │    │   │
│  │  │  • taxonomy: "module"                                       │    │   │
│  │  │  • constraints: { max_amount: 10000 }                      │    │   │
│  │  │  • compliance: "PCI-DSS"                                   │    │   │
│  │  └─────────────────────────────────────────────────────────────┘    │   │
│  │                                                                      │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │                    MANDATE (Authority)                       │    │   │
│  │  │  • role: "Admin"                                            │    │   │
│  │  │  • clearance: Clearance.administrative                      │    │   │
│  │  │  • authority: "READ, WRITE"                                 │    │   │
│  │  │  • isolation: Isolation.scoped                             │    │   │
│  │  └─────────────────────────────────────────────────────────────┘    │   │
│  │                                                                      │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │                   PROVENANCE (History)                       │    │   │
│  │  │  • actor: "admin_001"                                       │    │   │
│  │  │  • reason: "Manual override"                                │    │   │
│  │  │  • strategy: ReasoningStrategy.manual                      │    │   │
│  │  │  • traceId: "abc-123-def"                                   │    │   │
│  │  └─────────────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Core Concepts

### 1. Context is Immutable

Once created, a Context cannot be changed. To modify, create a new Context using `evolve()`:

```dart
// ❌ Can't modify
final context = Context.system;
// context.domains = 'finance';  // Not allowed

// ✅ Create a new one
final newContext = context.evolve((evolvable) {
  if (evolvable == Ontology.domains) {
    return Ontology.domains.entry('finance');
  }
  return null;
});
```

### 2. Context Supports Inheritance

Contexts can inherit from other contexts:

```dart
final base = Context.module('base');
final specialized = base.evolve((evolvable) {
  if (evolvable == Ontology.subDomains) {
    return Ontology.subDomains.entry('specialized');
  }
  return null;
});
```

### 3. Context is Type-Safe

Each dimension has a specific type:

```dart
// ✅ Type-safe dimensions
final domainEntry = Ontology.domains.entry('finance');  // String
final constraintEntry = Ontology.constraints.entry({'max': 100});  // Map
final clearanceEntry = Mandate.clearance.entry(Clearance.administrative);  // Enum

// ❌ Type mismatch (compiler error)
// Ontology.domains.entry(42);  // Error: int is not String
```

### 4. Context Provides Lineage

Track the evolution of a dimension:

```dart
final context = Context.module('finance');
final evolved = context.evolve(...);
final lineage = evolved.lineage(Ontology.domains);
// ['finance', 'finance, treasury']
```

---

## Context System (Root Context)

### What is Context.system?

`Context.system` is the canonical root context for the entire framework. It serves as the ultimate fallback for all ontological lookups.

```dart
// Default context for all cells
final cell = Cell();  // context = Context.system

// Safe defaults
print(Context.system.domains);    // null
print(Context.system.constraints); // null
```

### Properties of Context.system

| Property | Value |
|----------|-------|
| `type` | null |
| `domains` | null |
| `taxonomy` | null |
| `constraints` | null |
| `compliance` | null |
| `stakeholders` | null |
| `priority` | null |

### When to Use Context.system

- Default for most application code
- When no specific security requirements
- For development and testing
- For simple prototypes

---

## Creating Contexts

### Method 1: Using Named Parameters

```dart
final context = Context(
  type: 'payment_processor',
  identity: 'payment_gateway_01',
  domains: 'finance',
  subDomains: 'payments, refunds',
  stakeholders: 'finance_team, compliance',
  constraints: {'max_amount': 10000, 'currency': 'USD'},
  compliance: 'PCI-DSS',
  version: '2.0.0',
);
```

### Method 2: Using Entries

```dart
final context = Context.fromEntries([
  Ontology.type.entry('payment_processor'),
  Ontology.domains.entry('finance'),
  Ontology.constraints.entry({'max_amount': 10000}),
  Ontology.compliance.entry('PCI-DSS'),
]);
```

### Method 3: Using Factories

```dart
// Infrastructure
final coreContext = Context.core('gateway', identity: 'ingress_01');

// Application logic
final moduleContext = Context.module('payment', identity: 'payment_processor');

// Secure operations
final secureContext = Context.secureEnclave(
  partOf: 'PaymentModule',
  compliances: 'PCI-DSS, GDPR',
);

// Public interface
final publicContext = Context.publicInterface(
  partOf: 'API Gateway',
  domains: 'Web/v1',
  stakeholders: 'Mobile_App, Partner_API',
);
```

### Method 4: Using Describe (AI-Powered)

```dart
final context = Context.describe(
  'A secure audit log for the Healthcare domain compliant with HIPAA'
);
// Automatically extracts:
// - domains: healthcare
// - compliance: HIPAA
// - taxonomy: audit_log
```

---

## Predefined Context Factories

### 1. Context.core

For infrastructure nodes, gateways, and architectural plumbing:

```dart
final context = Context.core(
  'gateway',                    // Required: type
  identity: 'ingress_01',       // Optional: instance name
  partOf: 'Edge_Service',       // Optional: parent module
  others: {'rate_limit': 1000}, // Optional: custom metadata
);

// Properties:
// - type: 'gateway'
// - taxonomy: 'core'
// - domains: 'system'
// - priority: 0 (highest)
```

### 2. Context.module

For domain-specific logic, feature components, and business logic:

```dart
final context = Context.module(
  'payment_engine',             // Required: type
  identity: 'v3_processor',     // Optional: instance name
  partOf: 'Checkout_Service',   // Optional: parent module
  others: {'currency': 'USD'},  // Optional: custom metadata
);

// Properties:
// - type: 'payment_engine'
// - taxonomy: 'module'
// - domains: 'logic'
// - priority: 10 (standard)
```

### 3. Context.secureEnclave

For high-integrity state, sensitive logic, or administrative policies:

```dart
final context = Context.secureEnclave(
  partOf: 'CryptoModule',       // Required: parent module
  compliances: 'FIPS-140-2, PCI-DSS', // Required: regulations
  constraints: {'min_key_size': 2048}, // Optional: limits
  others: {'hardware_id': 'HSM-001'},  // Optional: metadata
);

// Properties:
// - taxonomy: 'enclave'
// - domains: 'security'
// - subDomains: 'integrity-gate'
// - isNot: 'External_Signals,Unauthenticated_Telemetry'
// - sensitivity: Sensitivity.restricted
// - audit_level: AuditLevel.full
// - priority: 0 (highest)
```

### 4. Context.publicInterface

For boundary nodes interacting with external users or systems:

```dart
final context = Context.publicInterface(
  partOf: 'Public_Web_API',     // Required: interface name
  domains: 'Web/v1',            // Required: functional domain
  stakeholders: 'Mobile_App_Users, Partner_SDK', // Optional: external entities
  others: {'rate_limit': 100},  // Optional: metadata
);

// Properties:
// - taxonomy: 'interface'
// - subDomains: 'ingress'
// - isNot: 'Internal_Commands,Private_State_Mutation'
// - sensitivity: Sensitivity.public
// - audit_level: AuditLevel.none
// - priority: 50 (standard)
```

### 5. Context.shieldedCortex

For high-reasoning nodes performing sensitive autonomous decisions:

```dart
final context = Context.shieldedCortex(
  partOf: 'Trading_Floor_A',    // Required: governing unit
  domains: 'Finance/HighFreq',   // Required: functional domain
  compliances: 'SEC, FINRA',     // Required: regulations
  constraints: {'max_position': 1000000}, // Optional: limits
  others: {'model_version': 'v3'}, // Optional: metadata
);

// Properties:
// - taxonomy: 'cortex'
// - subDomains: 'reasoning-enclave'
// - isNot: 'Background_Noise,Unverified_Inference'
// - strategy: ReasoningStrategy.formal
// - sensitivity: Sensitivity.restricted
// - audit_level: AuditLevel.detailed
// - priority: 10 (high)
```

### 6. Context.receptor

For nodes specialized in normalizing and validating environmental stimuli:

```dart
final context = Context.receptor(
  dataSources: 'MQTT_Broker, IoT_Devices', // Required: origins
  domains: 'Telemetry',          // Required: functional area
  others: {'sample_rate': 100},  // Optional: metadata
);

// Properties:
// - dataSources: 'MQTT_Broker, IoT_Devices'
// - domains: 'Telemetry'
// - subDomains: 'Receptor'
// - taxonomy: 'sensor_receptor'
// - audit_level: AuditLevel.minimal
// - sensitivity: Sensitivity.public
// - priority: 40 (elevated)
```

### 7. Context.integrityGate

For nodes acting as the framework's "Judicial Branch":

```dart
final context = Context.integrityGate(
  partOf: 'Treasury/Compliance', // Required: organizational unit
  compliances: 'SOX, Internal_Policy_v2', // Required: standards
  constraints: {'fail_closed': true}, // Optional: parameters
  others: {'audit_strictness': 'high'}, // Optional: metadata
);

// Properties:
// - taxonomy: 'governance_gate'
// - subDomains: 'integrity-gate'
// - strategy: ReasoningStrategy.reflexive
// - sensitivity: Sensitivity.restricted
// - audit_level: AuditLevel.full
// - priority: 0 (highest)
// - strict_mode: true
```

### 8. Context.homeostasis

For internal maintenance, resource balancing, and systemic health:

```dart
final context = Context.homeostasis(
  partOf: 'System/Memory',      // Required: system module
  label: 'LruCacheMonitor',      // Optional: human-readable label
  constraints: {'max_memory_mb': 512}, // Optional: limits
  others: {'cleanup_interval': 60}, // Optional: metadata
);

// Properties:
// - taxonomy: 'stability_loop'
// - subDomains: 'Homeostasis'
// - strategy: ReasoningStrategy.reflexive
// - sensitivity: Sensitivity.internal
// - priority: 75 (high maintenance)
```

### 9. Context.sandbox

For speculative reasoning, risk-free simulation, and experimentation:

```dart
final context = Context.sandbox(
  partOf: 'Finance/Strategies',  // Required: system module
  reason: 'Evaluating heuristic v2 performance', // Optional: justification
  readOnlyParent: true,          // Optional: read-only access
  others: {'simulation_id': 'sim_001'}, // Optional: metadata
);

// Properties:
// - taxonomy: 'simulation_workspace'
// - subDomains: 'Sandbox'
// - strategy: ReasoningStrategy.probabilistic
// - ephemeral: true
// - sensitivity: Sensitivity.public
// - audit_level: AuditLevel.none
// - priority: 30 (lower than live)
```

### 10. Context.auditLog

For non-repudiation, forensic logging, and compliance tracking:

```dart
final context = Context.auditLog(
  partOf: 'Treasury/Ledger',    // Required: audited module
  compliances: 'PCI-DSS, SOC2', // Required: regulations
  others: {'retention_days': 365}, // Optional: metadata
);

// Properties:
// - taxonomy: 'audit_ledger'
// - subDomains: 'compliance-logging'
// - strategy: ReasoningStrategy.deterministic
// - sensitivity: Sensitivity.private
// - audit_level: AuditLevel.full
// - priority: 90 (background)
```

### 11. Context.transientTask

For short-lived computational scenes or one-off agentic missions:

```dart
final context = Context.transientTask(
  partOf: 'System/Maintenance', // Required: module
  stakeholders: 'MigrationTeam', // Required: responsible entities
  lease: Duration(hours: 1),    // Required: validity duration
  constraints: {'batch_size': 1000}, // Optional: limits
  others: {'task_id': 'migrate_001'}, // Optional: metadata
);

// Properties:
// - taxonomy: 'transient_worker'
// - subDomains: 'Ephemeral_Task'
// - strategy: ReasoningStrategy.probabilistic
// - lease_duration_ms: 3600000 (1 hour)
// - auto_delete: true
// - priority: 60 (standard background)
```

---

## Ontology Dimensions

### Static Pillars (Non-Evolvable)

These dimensions cannot be changed after creation:

| Dimension | Type | Purpose | Example |
|-----------|------|---------|---------|
| `domains` | `String` | High-level functional areas | `'Finance, PII'` |
| `dataSources` | `String` | Origins of information | `'Auth_Service, User_DB'` |
| `taxonomy` | `String` | Categorical identity | `'Repository'` |
| `topology` | `String` | Network role | `'Principal'` |
| `version` | `String` | Structural revision | `'2.1.0'` |

### Fluid Boundaries (Evolvable)

These dimensions can be refined using `evolve()`:

| Dimension | Type | Purpose | Example |
|-----------|------|---------|---------|
| `type` | `String` | Category of operation | `'security_event'` |
| `identity` | `String` | Unique instance name | `'Auth_Node_ReadOnly'` |
| `subDomains` | `String` | Specialized operational zones | `'Tax_Calculation, VAT'` |
| `stakeholders` | `String` | Accountable entities | `'Finance_Admin'` |
| `constraints` | `Map<String, dynamic>` | Operational rules | `{'max_value': 100}` |
| `isNot` | `String` | Exclusionary boundaries | `'Currency_Exchange'` |
| `compliance` | `String` | Regulatory frameworks | `'GDPR, SOC2'` |
| `partOf` | `String` | Parent container | `'Global_Ledger_Service'` |

### Using Ontology Dimensions

```dart
// Create entries
final domainEntry = Ontology.domains.entry('finance');
final typeEntry = Ontology.type.entry('payment_processor');
final constraintEntry = Ontology.constraints.entry({'max_amount': 10000});

// Build context
final context = Context.fromEntries([domainEntry, typeEntry, constraintEntry]);

// Access values
print(context.domains);      // 'finance'
print(context.type);         // 'payment_processor'
print(context.constraints);  // {'max_amount': 10000}
```

---

## Context Inheritance

### Prototype-Based Inheritance

Contexts can inherit from other contexts:

```dart
// Parent context
final parent = Context.module('finance', stakeholders: 'admin');

// Child context - inherits from parent
final child = parent.evolve((evolvable) {
  if (evolvable == Ontology.subDomains) {
    return Ontology.subDomains.entry('payments');
  }
  return null;
});

print(child.domains);      // 'finance' (inherited)
print(child.stakeholders); // 'admin' (inherited)
print(child.subDomains);   // 'payments' (overridden)
```

### Inheritance Chain

```dart
// Root
final root = Context.system;

// Level 1
final level1 = root.evolve((evolvable) {
  return Ontology.type.entry('module');
});

// Level 2
final level2 = level1.evolve((evolvable) {
  return Ontology.domains.entry('finance');
});

// Level 3
final level3 = level2.evolve((evolvable) {
  return Ontology.subDomains.entry('payments');
});

// Resolution:
// - type: 'module' (from level1)
// - domains: 'finance' (from level2)
// - subDomains: 'payments' (from level3)
```

### Lineage Tracking

```dart
final context = Context.module('finance');
final evolved = context.evolve((evolvable) {
  if (evolvable == Ontology.domains) {
    return Ontology.domains.entry('finance, treasury');
  }
  return null;
});

final lineage = evolved.lineage(Ontology.domains);
// ['finance', 'finance, treasury']
```

---

## Using Context with Cells

### Basic Cell with Context

```dart
final context = Context.module('auth');
final cell = Cell(
  context: context,
  receptor: Receptor.passThrough,
);

print(cell.context.domains); // 'auth'
```

### Governed Cell with Context

```dart
final context = Context.secureEnclave(
  partOf: 'CryptoModule',
  compliances: 'FIPS-140-2',
);

final cell = Cell.governed(
  context: context,
  receptor: Receptor.passThrough,
  testRule: TestCell.allowAll,
  synapses: Synapses.enabled,
  forceLock: true,
);
```

### Cell with Deputy Context

```dart
final cell = Cell(...);

// Read-only deputy
final readOnly = await cell.deputy(
  context: DeputyContext.observer(
    baseContext: Context.system,
    task: 'Monitor',
  ),
);
```

### Context-Aware Validation

```dart
final contextAwareRule = TestCell<Cell>((object, {host, arguments, user}) {
  final ctx = host?.context;
  return ctx?.domains?.contains('Admin') ?? false;
});

final cell = Cell(
  testRule: contextAwareRule,
  context: Context.module('Admin', stakeholders: 'Admin'),
);
```

---

## Testing Context

### Unit Testing Context

```dart
import 'package:test/test.dart';

void main() {
  test('Context creates correctly', () {
    final context = Context.module('auth');
    expect(context.taxonomy, 'module');
    expect(context.domains, 'logic');
    expect(context.priority, 10);
  });

  test('Context inherits properties', () {
    final parent = Context.module('base');
    final child = parent.evolve((evolvable) {
      if (evolvable == Ontology.subDomains) {
        return Ontology.subDomains.entry('specialized');
      }
      return null;
    });
    
    expect(child.taxonomy, 'module');
    expect(child.domains, 'logic');
    expect(child.subDomains, 'specialized');
  });

  test('Context lineage tracks evolution', () {
    final context = Context.module('finance');
    final evolved = context.evolve((evolvable) {
      if (evolvable == Ontology.domains) {
        return Ontology.domains.entry('finance, treasury');
      }
      return null;
    });
    
    expect(evolved.lineage(Ontology.domains), ['finance', 'finance, treasury']);
  });
}
```

### Testing Context with Rules

```dart
test('Rule uses context', () {
  final rule = TestCell<Cell>((object, {host, arguments, user}) {
    return host?.context.domains?.contains('Admin') ?? false;
  });
  
  final adminContext = Context.module('Admin', stakeholders: 'Admin');
  final adminCell = Cell(testRule: rule, context: adminContext);
  
  final userContext = Context.module('User');
  final userCell = Cell(testRule: rule, context: userContext);
  
  expect(rule.call('anything', host: adminCell), true);
  expect(rule.call('anything', host: userCell), false);
});
```

---

## Best Practices

### 1. Use Predefined Factories

```dart
// ✅ GOOD - Use factories
final context = Context.module('payment');

// ❌ BAD - Manual construction
final context = Context(
  type: 'payment',
  domains: 'logic',
  taxonomy: 'module',
);
```

### 2. Use Evolve for Changes

```dart
// ✅ GOOD - Evolve from existing
final base = Context.module('finance');
final specialized = base.evolve((evolvable) {
  if (evolvable == Ontology.subDomains) {
    return Ontology.subDomains.entry('payments');
  }
  return null;
});

// ❌ BAD - Recreate from scratch
final specialized = Context(
  type: 'module',
  domains: 'logic',
  subDomains: 'payments',
);
```

### 3. Use Static Pillars for Identity

```dart
// ✅ GOOD - Static identity
final context = Context.module('auth');  // taxonomy is 'module'

// ❌ BAD - Trying to change static pillar (ignored)
final evolved = context.evolve((evolvable) {
  return Ontology.taxonomy.entry('gateway');  // Ignored - not evolvable
});
```

### 4. Use Constraints for Runtime Rules

```dart
// ✅ GOOD - Runtime constraints
final context = Context(
  constraints: {'max_retries': 3, 'timeout': 5000},
);

// ❌ BAD - Hardcoded values
// Use constraints for values that need to be configured at runtime
```

### 5. Document Context Purpose

```dart
/// Secure payment processing context.
///
/// Features:
/// - PCI-DSS compliant
/// - Admin-only access
/// - Maximum amount: $10,000
final paymentContext = Context.secureEnclave(
  partOf: 'PaymentModule',
  compliances: 'PCI-DSS',
  constraints: {'max_amount': 10000},
);
```

---

## Complete Example

Here's a complete multi-tenant application using Context:

```dart
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// 1. Tenant Contexts
// ─────────────────────────────────────────────────────────────────────────

class TenantConfig {
  final String id;
  final String domain;
  final List<String> features;
  final Map<String, dynamic> limits;

  TenantConfig({
    required this.id,
    required this.domain,
    this.features = const [],
    this.limits = const {},
  });
}

Context createTenantContext(TenantConfig tenant) {
  return Context.module(
    tenant.id,
    identity: 'tenant_${tenant.id}',
    partOf: 'MultiTenantApp',
    others: {
      'features': tenant.features,
      'limits': tenant.limits,
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────
// 2. Feature-Specific Contexts
// ─────────────────────────────────────────────────────────────────────────

Context createFeatureContext(TenantConfig tenant, String feature) {
  final base = createTenantContext(tenant);
  return base.evolve((evolvable) {
    if (evolvable == Ontology.subDomains) {
      return Ontology.subDomains.entry(feature);
    }
    if (evolvable == Ontology.constraints) {
      return Ontology.constraints.entry({
        'feature': feature,
        ...tenant.limits,
      });
    }
    return null;
  });
}

// ─────────────────────────────────────────────────────────────────────────
// 3. Role-Based Contexts
// ─────────────────────────────────────────────────────────────────────────

Context createRoleContext(Context base, String role) {
  return base.evolve((evolvable) {
    if (evolvable == Ontology.stakeholders) {
      return Ontology.stakeholders.entry(role);
    }
    if (evolvable == Ontology.constraints) {
      return Ontology.constraints.entry({'role': role});
    }
    return null;
  });
}

// ─────────────────────────────────────────────────────────────────────────
// 4. Cell Creation
// ─────────────────────────────────────────────────────────────────────────

Cell createTenantCell(TenantConfig tenant, String role) {
  final tenantContext = createTenantContext(tenant);
  final roleContext = createRoleContext(tenantContext, role);
  
  return Cell(
    context: roleContext,
    receptor: Receptor((cell, pulse, {user}) {
      final ctx = cell.context;
      print('Processing in tenant: ${ctx.type}');
      print('Role: ${ctx.stakeholders}');
      
      // Check feature availability
      final features = ctx.others?['features'] as List? ?? [];
      if (features.contains('analytics')) {
        print('Analytics enabled');
      }
      
      return pulse;
    }),
    testRule: TestCell((object, {host, arguments, user}) {
      final ctx = host?.context;
      final role = ctx?.stakeholders ?? '';
      return role.contains('Admin') || role.contains('Editor');
    }),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// 5. Main Demo
// ─────────────────────────────────────────────────────────────────────────

void main() {
  print('═══ Multi-Tenant Context Demo ═══\n');
  
  // Define tenants
  final tenantA = TenantConfig(
    id: 'tenant-a',
    domain: 'finance',
    features: ['reporting', 'analytics'],
    limits: {'max_users': 100},
  );
  
  final tenantB = TenantConfig(
    id: 'tenant-b',
    domain: 'hr',
    features: ['employee-management'],
    limits: {'max_users': 50},
  );
  
  // Create cells
  final adminCell = createTenantCell(tenantA, 'Admin');
  final editorCell = createTenantCell(tenantB, 'Editor');
  final viewerCell = createTenantCell(tenantA, 'Viewer');
  
  // Test contexts
  print('Tenant A Admin:');
  print('  Type: ${adminCell.context.type}');
  print('  Stakeholders: ${adminCell.context.stakeholders}');
  print('  Features: ${adminCell.context.others?['features']}');
  
  print('\nTenant B Editor:');
  print('  Type: ${editorCell.context.type}');
  print('  Stakeholders: ${editorCell.context.stakeholders}');
  print('  Features: ${editorCell.context.others?['features']}');
  
  // Test validation
  final testRule = adminCell.validate;
  print('\nValidation:');
  print('  Admin tenant: ${testRule.call('data', host: adminCell)}');
  print('  Viewer tenant: ${testRule.call('data', host: viewerCell)}');
  
  print('\n═══ Done ═══');
}
```

**Expected Output:**
```
═══ Multi-Tenant Context Demo ═══

Tenant A Admin:
  Type: tenant-a
  Stakeholders: Admin
  Features: [reporting, analytics]

Tenant B Editor:
  Type: tenant-b
  Stakeholders: Editor
  Features: [employee-management]

Validation:
  Admin tenant: true
  Viewer tenant: false

═══ Done ═══
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **Context** | Operational environment for a cell |
| **Ontology** | Structural dimensions (identity, domains, constraints) |
| **Mandate** | Authority dimensions (role, clearance, permissions) |
| **Provenance** | Historical dimensions (actor, reason, strategy) |
| **Inheritance** | Prototype-based via `evolve()` |
| **Lineage** | Track evolution of dimensions |

### Key Rules

1. **Context is immutable** - Use `evolve()` to create new ones
2. **Static pillars cannot change** - Use evolvable dimensions for runtime changes
3. **Use predefined factories** - Prefer `module()`, `secureEnclave()`, etc.
4. **Document your contexts** - Explain purpose and constraints
5. **Use constraints** - For runtime configuration
6. **Check lineage** - For debugging and auditing

### Common Patterns

```dart
// Pattern: Module context
final context = Context.module('payment');

// Pattern: Secure context
final context = Context.secureEnclave(
  partOf: 'CryptoModule',
  compliances: 'FIPS-140-2',
);

// Pattern: Evolution
final evolved = base.evolve((evolvable) {
  if (evolvable == Ontology.domains) {
    return Ontology.domains.entry('finance');
  }
  return null;
});

// Pattern: Deputy context
final deputy = DeputyContext.observer(
  baseContext: Context.system,
  task: 'Monitor',
);

// Pattern: Context-aware validation
final rule = TestCell<Cell>((_, {host, ...}) => host.context.domains == 'admin');
```