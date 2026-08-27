# How to Use DeputyContext in the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What is DeputyContext?](#what-is-deputycontext)
3. [Core Concepts](#core-concepts)
4. [DeputyContext System](#deputycontext-system)
5. [Creating a DeputyContext](#creating-a-deputycontext)
6. [Predefined DeputyContext Factories](#predefined-deputycontext-factories)
7. [Mandate Dimensions](#mandate-dimensions)
8. [Clearance Levels](#clearance-levels)
9. [Isolation Levels](#isolation-levels)
10. [Sovereignty Levels](#sovereignty-levels)
11. [Using with Deputies](#using-with-deputies)
12. [Testing DeputyContext](#testing-deputycontext)
13. [Best Practices](#best-practices)
14. [Complete Example](#complete-example)

---

## Introduction

**DeputyContext** is the mandate and authority profile for a deputy—a restricted proxy that shares a cell's state but operates under different permissions. It defines what a deputy **can do**, **who it is**, and **how it operates**.

### When to Use DeputyContext

| Scenario | Recommended Factory |
|----------|---------------------|
| Read-only monitoring | `DeputyContext.observer()` |
| Active state mutation | `DeputyContext.delegate()` |
| Safe simulation | `DeputyContext.sandbox()` |
| Emergency recovery | `DeputyContext.intervention()` |
| Resource cleanup | `DeputyContext.janitor()` |
| Structural changes | `DeputyContext.architect()` |
| Compliance auditing | `DeputyContext.auditor()` |
| Cross-domain communication | `DeputyContext.ambassador()` |
| Secure reasoning | `DeputyContext.shielded()` |
| Policy enforcement | `DeputyContext.gatekeeper()` |
| Background maintenance | `DeputyContext.homeostasis()` |

---

## What is DeputyContext?

`DeputyContext` is the mandate profile that defines a deputy's:
- **Authority** - What actions it can perform
- **Role** - Its semantic identity
- **Clearance** - Its security rank
- **Isolation** - Its execution boundary
- **Sovereignty** - Its decision-making autonomy
- **Justification** - Why it exists

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Immutable** | Cannot be modified after creation |
| **Inheritable** | Supports prototype-based inheritance |
| **Type-Safe** | Strong typing with Mandate dimensions |
| **Auditable** | Provides justification for actions |
| **Restrictive** | Only narrows permissions, never widens |

### Relationship with Cell

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CELL PRINCIPAL                                     │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        STATE & LOGIC                                 │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │   │
│  │  │    BOX      │  │  RECEPTOR   │  │  TESTCELL   │                 │   │
│  │  │   Storage   │  │  Transform  │  │  Validate   │                 │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         DEPUTY (Proxy)                               │   │
│  │                                                                      │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │                    DEPUTY CONTEXT (Mandate)                  │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │   │   │
│  │  │  │  AUTHORITY  │  │    ROLE     │  │  CLEARANCE  │          │   │   │
│  │  │  │  "READ"     │  │  "Observer" │  │ observation│          │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘          │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │   │   │
│  │  │  │  ISOLATION  │  │ SOVEREIGNTY │  │JUSTIFICATION│          │   │   │
│  │  │  │  "scoped"   │  │ "supervised"│  │ "Audit task"│          │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘          │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Core Concepts

### 1. Authority

The **functional permission** or "verb" authorized for the deputy:

```dart
final context = DeputyContext(
  baseContext: Context.system,
  authority: 'READ',  // Can only read
  // or 'READ, WRITE' for read-write
  // or 'ADMIN' for administrative actions
);
```

### 2. Role

The **semantic identity** of the deputy:

```dart
final context = DeputyContext(
  baseContext: Context.system,
  authority: 'READ',
  role: 'Observer',  // Identity for auditing
);
```

### 3. Clearance

The **security rank** of the deputy:

```dart
final context = DeputyContext(
  baseContext: Context.system,
  authority: 'READ',
  clearance: Clearance.observational,  // Lowest clearance
);
```

### 4. Isolation

The **execution boundary** of the deputy:

```dart
final context = DeputyContext(
  baseContext: Context.system,
  authority: 'READ',
  isolation: Isolation.scoped,  // Restricted scope
);
```

### 5. Sovereignty

The **decision-making autonomy**:

```dart
final context = DeputyContext(
  baseContext: Context.system,
  authority: 'READ',
  sovereignty: Sovereignty.supervised,  // Needs approval
);
```

### 6. Justification

The **rationale** for the deputy's existence:

```dart
final context = DeputyContext(
  baseContext: Context.system,
  authority: 'READ',
  justification: 'Audit task for compliance',  // Why it exists
);
```

---

## DeputyContext System

### What is DeputyContext.system?

`DeputyContext.system` is the canonical root context for deputies, providing safe defaults:

```dart
// Default deputy context
final context = DeputyContext.system;

// Properties:
// - authority: null
// - role: null
// - clearance: Clearance.standard
// - isolation: Isolation.scoped
// - sovereignty: Sovereignty.sovereign
// - justification: null
```

### When to Use DeputyContext.system

- Default for most deputies
- When no specific authority needed
- For development and testing
- For simple read-only views

---

## Creating a DeputyContext

### Method 1: Basic Constructor

```dart
final context = DeputyContext(
  baseContext: Context.system,
  authority: 'READ',
  role: 'Observer',
  isolation: Isolation.scoped,
  clearance: Clearance.observational,
  sovereignty: Sovereignty.supervised,
  justification: 'Monitoring system health',
  constraints: {'max_ops': 1000},
);
```

### Method 2: From Entries

```dart
final context = DeputyContext.fromEntries([
  Mandate.authority.entry('READ'),
  Mandate.role.entry('Observer'),
  Mandate.clearance.entry(Clearance.observational),
  Mandate.isolation.entry(Isolation.scoped),
  Mandate.sovereignty.entry(Sovereignty.supervised),
  Mandate.justification.entry('Monitoring'),
]);
```

### Method 3: Using Factories

```dart
// Observer (read-only)
final observer = DeputyContext.observer(
  baseContext: Context.system,
  task: 'Monitor Dashboard',
);

// Delegate (active task)
final delegate = DeputyContext.delegate(
  baseContext: Context.system,
  task: 'Cleanup Cache',
);

// Sandbox (simulation)
final sandbox = DeputyContext.sandbox(
  baseContext: Context.system,
  role: 'What-If Analyzer',
);
```

---

## Predefined DeputyContext Factories

### 1. DeputyContext.observer

For read-only monitoring:

```dart
final context = DeputyContext.observer(
  baseContext: Context.system,
  task: 'Dashboard Monitoring',
  clearance: Clearance.observational,
);

// Properties:
// - authority: 'OBSERVATION'
// - role: 'Observer'
// - clearance: Clearance.observational (or custom)
// - isolation: Isolation.scoped
```

### 2. DeputyContext.delegate

For active state-mutating tasks:

```dart
final context = DeputyContext.delegate(
  baseContext: Context.system,
  task: 'Cleanup Cache',
  clearance: Clearance.standard,
);

// Properties:
// - authority: 'DELEGATED_TASK'
// - role: 'Delegate'
// - clearance: Clearance.standard (or custom)
```

### 3. DeputyContext.sandbox

For safe simulation:

```dart
final context = DeputyContext.sandbox(
  baseContext: Context.system,
  role: 'Profit_Projection_Model',
);

// Properties:
// - authority: 'SIMULATE'
// - role: 'Reasoning_Sandbox' (or custom)
// - isolation: Isolation.sandboxed
// - clearance: Clearance.minimal
```

### 4. DeputyContext.intervention

For emergency recovery:

```dart
final context = DeputyContext.intervention(
  baseContext: Context.system,
  reason: 'Isolating compromised node #502',
);

// Properties:
// - authority: 'SYSTEM_PROTECTION'
// - role: 'Sentinel'
// - clearance: Clearance.administrative
// - justification: 'Isolating compromised node #502'
// - sovereignty: Sovereignty.preemptive
// - isolation: Isolation.sandboxed
```

### 5. DeputyContext.janitor

For resource cleanup:

```dart
final context = DeputyContext.janitor(
  baseContext: Context.system,
  target: 'Telemetry_Buffer',
  clearance: Clearance.administrative,
);

// Properties:
// - authority: 'RESOURCE_MANAGEMENT'
// - role: 'Janitor'
// - clearance: Clearance.administrative
// - target: 'Telemetry_Buffer'
```

### 6. DeputyContext.architect

For structural changes:

```dart
final context = DeputyContext.architect(
  baseContext: Context.system,
  mission: 'Scaling payment module',
  clearance: Clearance.standard,
);

// Properties:
// - authority: 'INFRASTRUCTURE_EVOLUTION'
// - role: 'Architect'
// - clearance: Clearance.standard
// - mission_intent: 'Scaling payment module'
```

### 7. DeputyContext.auditor

For compliance auditing:

```dart
final context = DeputyContext.auditor(
  baseContext: Context.system,
  regulation: 'SOC2',
);

// Properties:
// - authority: 'REGULATORY_AUDIT'
// - role: 'Witness'
// - clearance: Clearance.observational
// - target_regulation: 'SOC2'
// - force_audit: 'full'
// - observational_only: true
```

### 8. DeputyContext.ambassador

For cross-domain communication:

```dart
final context = DeputyContext.ambassador(
  baseContext: Context.system,
  targetDomain: 'Partner_API',
);

// Properties:
// - authority: 'CROSS_DOMAIN_COMMUNICATION'
// - role: 'Ambassador'
// - clearance: Clearance.minimal
// - external_domain: 'Partner_API'
// - permeability: 'selective'
// - translation_required: true
```

### 9. DeputyContext.shielded

For secure reasoning:

```dart
final context = DeputyContext.shielded(
  baseContext: Context.system,
  reason: 'Processing payment keys',
);

// Properties:
// - authority: 'SECURE_REASONING'
// - role: 'Sentinel'
// - clearance: Clearance.administrative
// - justification: 'Processing payment keys'
// - isolated: true
// - enclave_type: 'privileged_logic'
```

### 10. DeputyContext.gatekeeper

For policy enforcement:

```dart
final context = DeputyContext.gatekeeper(
  baseContext: Context.system,
);

// Properties:
// - authority: 'GOVERNANCE_ENFORCEMENT'
// - role: 'Gatekeeper'
// - clearance: Clearance.observational
// - force_audit: 'full'
// - enforcement_type: 'policy_guardrail'
```

### 11. DeputyContext.homeostasis

For background maintenance:

```dart
final context = DeputyContext.homeostasis(
  baseContext: Context.system,
);

// Properties:
// - authority: 'SYSTEM_MAINTENANCE'
// - role: 'Service_Daemon'
// - clearance: Clearance.standard
// - scope: 'infrastructure'
// - category: 'metabolic'
// - priority: 'background'
```

---

## Mandate Dimensions

### Static Pillars (Non-Evolvable)

| Dimension | Type | Purpose | Example |
|-----------|------|---------|---------|
| `role` | `String` | Semantic identity | `'Observer'` |

### Fluid Boundaries (Evolvable)

| Dimension | Type | Purpose | Example |
|-----------|------|---------|---------|
| `authority` | `String` | Functional permission | `'READ, WRITE'` |
| `isolation` | `Isolation` | Execution boundary | `Isolation.scoped` |
| `sovereignty` | `Sovereignty` | Decision-making autonomy | `Sovereignty.supervised` |
| `clearance` | `Clearance` | Security rank | `Clearance.standard` |
| `auditLevel` | `AuditLevel` | Observability depth | `AuditLevel.full` |
| `justification` | `String` | Rationale | `'Compliance audit'` |
| `constraints` | `Map<String, dynamic>` | Operational boundaries | `{'max_ops': 1000}` |

---

## Clearance Levels

### Clearance Overview

| Level | Value | Description | Use Case |
|-------|-------|-------------|----------|
| `observational` | 0 | Read-only | UI, monitoring, logging |
| `minimal` | 1 | Safe mutations | Sandbox, simulation |
| `standard` | 2 | Default | General operations |
| `administrative` | 3 | Structural changes | Archiving, cleanup |
| `privileged` | 4 | Cross-domain | Gateways, ambassadors |
| `unrestricted` | 5 | Absolute authority | System recovery |

### Using Clearance

```dart
// Read-only observer
final observer = DeputyContext.observer(
  baseContext: Context.system,
  task: 'Monitor',
  clearance: Clearance.observational,
);

// Administrator
final admin = DeputyContext.intervention(
  baseContext: Context.system,
  reason: 'Emergency',
);
// clearance: Clearance.administrative

// Checking clearance
if (context.clearance.authorizes(Clearance.standard)) {
  print('Has standard clearance');
}
```

---

## Isolation Levels

### Isolation Overview

| Level | Description | Use Case |
|-------|-------------|----------|
| `shared` | Direct live execution | Standard operations |
| `scoped` | Restricted domain | Limited scope |
| `restricted` | Zero-trust filtering | Security-sensitive |
| `sandboxed` | Virtualized execution | Simulation, testing |
| `total` | Air-gapped | Observation only |

### Using Isolation

```dart
// Sandboxed for simulation
final sandbox = DeputyContext.sandbox(
  baseContext: Context.system,
  role: 'Simulator',
);
// isolation: Isolation.sandboxed

// Scoped for limited operations
final scoped = DeputyContext.delegate(
  baseContext: Context.system,
  task: 'Update',
);
// isolation: Isolation.scoped (default)

// Checking isolation
if (context.isolation.isVirtual) {
  print('Virtual execution');
}
```

---

## Sovereignty Levels

### Sovereignty Overview

| Level | Description | Use Case |
|-------|-------------|----------|
| `supervised` | Needs approval | High-risk actions |
| `collaborative` | Mixed autonomy | Human-in-the-loop |
| `sovereign` | Full autonomy | Standard operations |
| `preemptive` | Emergency overrides | System safety |

### Using Sovereignty

```dart
// Supervised (needs approval)
final supervised = DeputyContext(
  baseContext: Context.system,
  authority: 'WRITE',
  sovereignty: Sovereignty.supervised,
);

// Sovereign (full autonomy)
final sovereign = DeputyContext.delegate(
  baseContext: Context.system,
  task: 'Cleanup',
);
// sovereignty: Sovereignty.sovereign (default)

// Checking sovereignty
if (context.sovereignty.requiresApproval) {
  print('Needs approval');
}
if (context.sovereignty.isPreemptive) {
  print('Emergency override');
}
```

---

## Using with Deputies

### Basic Deputy

```dart
// Create a cell
final cell = ValueCell<int>(value: 42);

// Create a deputy with context
final context = DeputyContext.observer(
  baseContext: Context.system,
  task: 'Read-only view',
);

final deputy = await cell.deputy(
  context: context,
  testRule: TestCell.readOnly,
);

// deputy shares state but has restricted permissions
print(deputy.value);  // 42
// deputy.emit(100);  // Blocked
```

### Custom Deputy

```dart
final cell = ValueCell<User>(value: user);

final context = DeputyContext(
  baseContext: Context.system,
  authority: 'UPDATE_PROFILE',
  role: 'ProfileEditor',
  clearance: Clearance.standard,
  isolation: Isolation.scoped,
  sovereignty: Sovereignty.supervised,
  justification: 'User profile update',
  constraints: {'max_fields': 5},
);

final deputy = await cell.deputy(context: context);
```

### Factory-Based Deputy

```dart
// Observer deputy
final observer = await cell.deputy(
  context: DeputyContext.observer(
    baseContext: Context.system,
    task: 'Monitor',
  ),
);

// Delegate deputy
final delegate = await cell.deputy(
  context: DeputyContext.delegate(
    baseContext: Context.system,
    task: 'Cleanup',
  ),
);

// Sandbox deputy
final sandbox = await cell.deputy(
  context: DeputyContext.sandbox(
    baseContext: Context.system,
    role: 'What-If',
  ),
);
```

### OpenCell Deputy

```dart
final openCell = Cell.open();

final deputy = await openCell.deputy(
  context: DeputyContext.gatekeeper(
    baseContext: Context.system,
  ),
);
// deputy is also an OpenCell with restricted permissions
```

---

## Testing DeputyContext

### Unit Testing

```dart
import 'package:test/test.dart';

void main() {
  test('DeputyContext creates correctly', () {
    final context = DeputyContext(
      baseContext: Context.system,
      authority: 'READ',
      role: 'Observer',
      clearance: Clearance.observational,
    );
    expect(context.authority, 'READ');
    expect(context.role, 'Observer');
    expect(context.clearance, Clearance.observational);
  });

  test('DeputyContext inherits from base', () {
    final base = Context.module('finance');
    final context = DeputyContext(
      baseContext: base,
      authority: 'READ',
    );
    expect(context.domains, 'logic');  // From base
    expect(context.authority, 'READ');  // Local
  });

  test('DeputyContext evolves correctly', () {
    final context = DeputyContext(
      baseContext: Context.system,
      authority: 'READ',
      clearance: Clearance.standard,
    );
    final evolved = context.evolve((evolvable) {
      if (evolvable == Mandate.clearance) {
        return Mandate.clearance.entry(Clearance.observational);
      }
      return null;
    });
    expect(evolved.authority, 'READ');
    expect(evolved.clearance, Clearance.observational);
  });
}
```

### Testing with Deputies

```dart
test('Deputy respects context', () async {
  final cell = ValueCell<int>(value: 42);
  
  final context = DeputyContext.observer(
    baseContext: Context.system,
    task: 'Test',
  );
  
  final deputy = await cell.deputy(context: context);
  
  expect(deputy.value, 42);
  // deputy._emit(100);  // Should be blocked
});

test('Deputy with clearance', () async {
  final cell = ValueCell<int>(value: 42);
  
  final context = DeputyContext(
    baseContext: Context.system,
    authority: 'WRITE',
    clearance: Clearance.standard,
  );
  
  final deputy = await cell.deputy(context: context);
  // Deputy can write with standard clearance
});
```

---

## Best Practices

### 1. Use Predefined Factories

```dart
// ✅ GOOD - Use factories
final context = DeputyContext.observer(
  baseContext: Context.system,
  task: 'Monitor',
);

// ❌ BAD - Manual construction
final context = DeputyContext(
  baseContext: Context.system,
  authority: 'OBSERVATION',
  role: 'Observer',
);
```

### 2. Set Appropriate Clearance

```dart
// ✅ GOOD - Read-only observer
clearance: Clearance.observational

// ✅ GOOD - Standard operations
clearance: Clearance.standard

// ✅ GOOD - Administrative tasks
clearance: Clearance.administrative

// ❌ BAD - Too high for simple tasks
clearance: Clearance.unrestricted
```

### 3. Document Justification

```dart
// ✅ GOOD - Clear justification
justification: 'System health monitoring for compliance'

// ❌ BAD - Vague justification
justification: 'Task'
```

### 4. Use Constraints

```dart
// ✅ GOOD - With constraints
constraints: {'max_ops': 1000, 'timeout_ms': 5000}

// ❌ BAD - No constraints
// constraints: null
```

### 5. Set Appropriate Sovereignty

```dart
// ✅ GOOD - Supervised for risky actions
sovereignty: Sovereignty.supervised

// ✅ GOOD - Sovereign for routine tasks
sovereignty: Sovereignty.sovereign

// ❌ BAD - Preemptive for routine tasks
sovereignty: Sovereignty.preemptive
```

### 6. Use Isolation for Safety

```dart
// ✅ GOOD - Sandbox for simulations
isolation: Isolation.sandboxed

// ✅ GOOD - Scoped for limited operations
isolation: Isolation.scoped

// ❌ BAD - Shared for sensitive operations
isolation: Isolation.shared
```

---

## Complete Example

Here's a complete multi-tenant system with different deputy contexts:

```dart
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// 1. Domain Models
// ─────────────────────────────────────────────────────────────────────────

class User {
  final String id;
  final String name;
  final String role;
  final bool isActive;

  User({
    required this.id,
    required this.name,
    required this.role,
    this.isActive = true,
  });

  @override
  String toString() => 'User($name, role: $role)';
}

class Document {
  final String id;
  final String title;
  final String content;
  final Sensitivity sensitivity;

  Document({
    required this.id,
    required this.title,
    required this.content,
    this.sensitivity = Sensitivity.public,
  });

  @override
  String toString() => 'Document($title, sensitivity: ${sensitivity.name})';
}

// ─────────────────────────────────────────────────────────────────────────
// 2. Document Management Cell
// ─────────────────────────────────────────────────────────────────────────

final documentCell = ValueCell<List<Document>>(
  value: [
    Document(
      id: 'DOC-001',
      title: 'Q4 Report',
      content: 'Quarterly results...',
      sensitivity: Sensitivity.confidential,
    ),
    Document(
      id: 'DOC-002',
      title: 'Public Announcement',
      content: 'Company update...',
      sensitivity: Sensitivity.public,
    ),
    Document(
      id: 'DOC-003',
      title: 'API Key',
      content: 'sk-abc123...',
      sensitivity: Sensitivity.secret,
    ),
  ],
  transform: (host, input, {user, bind}) {
    final docs = input.payload as List<Document>?;
    if (docs == null) return null;
    return Pulse(docs);
  },
);

// ─────────────────────────────────────────────────────────────────────────
// 3. Create Different Deputies
// ─────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  print('═══ Multi-Tenant System with DeputyContext ═══\n');

  // 1. Read-only observer
  print('1. Read-only Observer:');
  final observerContext = DeputyContext.observer(
    baseContext: Context.system,
    task: 'Document Viewer',
    clearance: Clearance.observational,
  );
  final observer = await documentCell.deputy(
    context: observerContext,
    testRule: TestCell.readOnly,
  );
  
  final docs = observer.value as List<Document>?;
  print('   Viewing ${docs?.length ?? 0} documents');
  for (final doc in docs ?? []) {
    print('   - ${doc.title} (${doc.sensitivity.name})');
  }

  // 2. Compliance auditor
  print('\n2. Compliance Auditor:');
  final auditorContext = DeputyContext.auditor(
    baseContext: Context.system,
    regulation: 'GDPR',
  );
  final auditor = await documentCell.deputy(
    context: auditorContext,
  );
  // Auditor can see everything but can't modify

  // 3. Janitor for cleanup
  print('\n3. Janitor:');
  final janitorContext = DeputyContext.janitor(
    baseContext: Context.system,
    target: 'Expired Documents',
    clearance: Clearance.administrative,
  );
  final janitor = await documentCell.deputy(
    context: janitorContext,
  );
  // Janitor can remove expired documents

  // 4. Sandbox for what-if analysis
  print('\n4. Sandbox:');
  final sandboxContext = DeputyContext.sandbox(
    baseContext: Context.system,
    role: 'What-If Analyzer',
  );
  final sandbox = await documentCell.deputy(
    context: sandboxContext,
  );
  // Sandbox can simulate but not commit

  // 5. Security intervention
  print('\n5. Security Intervention:');
  final interventionContext = DeputyContext.intervention(
    baseContext: Context.system,
    reason: 'Suspicious access detected',
  );
  final sentinel = await documentCell.deputy(
    context: interventionContext,
  );
  // Sentinel can override and block access

  print('\n═══ Done ═══');
}
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **DeputyContext** | Mandate profile for deputies |
| **Authority** | Functional permissions (verbs) |
| **Role** | Semantic identity |
| **Clearance** | Security rank (0-5) |
| **Isolation** | Execution boundary |
| **Sovereignty** | Decision-making autonomy |
| **Justification** | Rationale for existence |

### Key Rules

1. **Use factories for common scenarios** - `observer`, `delegate`, etc.
2. **Set appropriate clearance** - Match to required permissions
3. **Document justification** - Explain why deputy exists
4. **Use isolation for safety** - Sandbox for simulations
5. **Use sovereignty for control** - Supervised for risky actions
6. **Add constraints** - Limit operations

### Common Patterns

```dart
// Pattern: Read-only observer
final context = DeputyContext.observer(
  baseContext: Context.system,
  task: 'Monitor',
);

// Pattern: Active delegate
final context = DeputyContext.delegate(
  baseContext: Context.system,
  task: 'Cleanup',
);

// Pattern: Safe sandbox
final context = DeputyContext.sandbox(
  baseContext: Context.system,
  role: 'Simulator',
);

// Pattern: Emergency intervention
final context = DeputyContext.intervention(
  baseContext: Context.system,
  reason: 'Emergency',
);

// Pattern: Custom mandate
final context = DeputyContext(
  baseContext: Context.system,
  authority: 'CUSTOM_ACTION',
  role: 'CustomRole',
  clearance: Clearance.standard,
  isolation: Isolation.scoped,
);
```