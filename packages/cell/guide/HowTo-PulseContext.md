# How to Use PulseContext in the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What is PulseContext?](#what-is-pulsecontext)
3. [Core Concepts](#core-concepts)
4. [Creating a PulseContext](#creating-a-pulsecontext)
5. [Predefined Context Factories](#predefined-context-factories)
6. [Provenance Dimensions](#provenance-dimensions)
7. [Context Inheritance](#context-inheritance)
8. [Using with Pulses](#using-with-pulses)
9. [Testing PulseContext](#testing-pulsecontext)
10. [Best Practices](#best-practices)
11. [Complete Example](#complete-example)

---

## Introduction

**PulseContext** is the provenance and accountability system for pulses. It documents the **causal trace**—who, why, and how—for every stimulus traversing the reactive graph. Think of it as the **black box recorder** for your reactive system.

### When to Use PulseContext

| Scenario | Recommended Approach |
|----------|---------------------|
| User actions | `PulseContext.userAction()` |
| AI-generated signals | `PulseContext.aiInference()` |
| System maintenance | `PulseContext.homeostasis()` |
| Compliance/auditing | `PulseContext.regulated()` |
| Security events | `PulseContext.securityIntervention()` |
| Collaborative tasks | `PulseContext.collaboration()` |
| Infrastructure changes | `PulseContext.infrastructureChange()` |
| Self-healing | `PulseContext.selfCorrection()` |
| Telemetry | `PulseContext.telemetry()` |
| Administrative commands | `PulseContext.instruction()` |
| Simulations | `PulseContext.hypothesis()` |
| System internal | `PulseContext.systemInternal()` |

---

## What is PulseContext?

`PulseContext` is the provenance metadata container that travels with every governed pulse. It provides the **causal trace**—the who, why, and how—of every signal in the system.

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Immutable** | Cannot be modified after creation |
| **Traceable** | Full causal history with lineage |
| **Inheritable** | Supports prototype-based inheritance |
| **Type-Safe** | Strong typing with Provenance dimensions |
| **Auditable** | Complete audit trail for compliance |
| **Explainable** | Supports XAI (Explainable AI) |

### PulseContext Anatomy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PULSE CONTEXT                                      │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    STATIC PILLARS (Identity)                         │   │
│  │  • actor: "admin_001"           - Who initiated the signal          │   │
│  │  • traceId: "abc-123-def"       - Unique causal anchor              │   │
│  │  • parentTraceId: "xyz-789-uvw" - Ancestral trace ID                │   │
│  │  • compliance: "GDPR"           - Regulatory framework              │   │
│  │  • sensitivity: Sensitivity.secret - Data classification            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    FLUID BOUNDARIES (Intent)                         │   │
│  │  • reason: "Manual override"     - Immediate causal logic           │   │
│  │  • purpose: "SYSTEM_UPDATE"     - Strategic intent                  │   │
│  │  • strategy: ReasoningStrategy.manual - Methodology                 │   │
│  │  • confidence: 1.0              - Certainty estimate                │   │
│  │  • priority: 80                 - Execution urgency                 │   │
│  │  • auditLevel: AuditLevel.full  - Observability depth               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Core Concepts

### 1. Static Pillars (Non-Evolvable)

These dimensions cannot be changed after creation:

| Dimension | Type | Purpose | Example |
|-----------|------|---------|---------|
| `actor` | `String` | Who initiated the signal | `'admin_001'` |
| `traceId` | `String` | Unique causal anchor | `'abc-123-def'` |
| `parentTraceId` | `String` | Ancestral trace ID | `'xyz-789-uvw'` |
| `compliance` | `String` | Regulatory framework | `'GDPR'` |
| `sensitivity` | `Sensitivity` | Data classification | `Sensitivity.secret` |

### 2. Fluid Boundaries (Evolvable)

These dimensions can be refined during evolution:

| Dimension | Type | Purpose | Example |
|-----------|------|---------|---------|
| `reason` | `String` | Immediate causal logic | `'Manual override'` |
| `purpose` | `String` | Strategic intent | `'SYSTEM_UPDATE'` |
| `strategy` | `ReasoningStrategy` | Methodology | `ReasoningStrategy.manual` |
| `confidence` | `double` | Certainty estimate | `0.85` |
| `priority` | `int` | Execution urgency | `80` |
| `auditLevel` | `AuditLevel` | Observability depth | `AuditLevel.full` |

### 3. Inheritance

PulseContext supports prototype-based inheritance:

```dart
final base = PulseContext(actor: 'system', reason: 'default');
final child = base.evolve((evolvable) {
  if (evolvable == Provenance.reason) {
    return Provenance.reason.entry('custom reason');
  }
  return null;
});
```

### 4. Lineage

Track the evolution of a dimension:

```dart
final context = PulseContext(actor: 'user');
final evolved = context.evolve(...);
final lineage = evolved.lineage(Provenance.actor);
// ['user', 'user (delegated)']
```

---

## Creating a PulseContext

### Method 1: Basic Constructor

```dart
final context = PulseContext(
  actor: 'admin_001',
  reason: 'Manual update',
  purpose: 'USER_ACTION',
  strategy: ReasoningStrategy.manual,
  confidence: 1.0,
  priority: 60,
  compliance: 'GDPR',
  sensitivity: Sensitivity.confidential,
  auditLevel: AuditLevel.standard,
);
```

### Method 2: From Entries

```dart
final context = PulseContext.fromEntries([
  Provenance.actor.entry('admin_001'),
  Provenance.reason.entry('Manual update'),
  Provenance.purpose.entry('USER_ACTION'),
  Provenance.strategy.entry(ReasoningStrategy.manual),
  Provenance.confidence.entry(1.0),
  Provenance.priority.entry(60),
]);
```

### Method 3: With Parent

```dart
final parent = PulseContext(actor: 'system', reason: 'parent');
final child = PulseContext(
  baseContext: parent,
  reason: 'child reason',
  priority: 80,
);
// child inherits actor from parent
```

### Method 4: Using Factories

```dart
// User action
final userContext = PulseContext.userAction(
  baseContext: Context.system,
  actor: 'user_123',
  reason: 'Profile update',
);

// AI inference
final aiContext = PulseContext.aiInference(
  baseContext: Context.system,
  actor: 'RecommendationEngine',
  reason: 'User viewed product',
  confidence: 0.85,
);
```

---

## Predefined Context Factories

### 1. PulseContext.userAction

For human-initiated actions:

```dart
final context = PulseContext.userAction(
  baseContext: Context.system,
  actor: 'user_123',
  reason: 'Confirming payment',
  purpose: 'TRANSACTION_COMMIT',
  priority: 60,
  sensitivity: Sensitivity.public,
);

// Properties:
// - strategy: ReasoningStrategy.manual
// - confidence: 1.0
// - auditLevel: AuditLevel.standard
// - priority: 60 (default)
```

### 2. PulseContext.aiInference

For AI-generated signals:

```dart
final context = PulseContext.aiInference(
  baseContext: Context.system,
  actor: 'Heuristic_Optimizer_v2',
  reason: 'Detected high latency',
  confidence: 0.82,
  purpose: 'RESOURCE_SCALING',
  priority: 20,
);

// Properties:
// - strategy: ReasoningStrategy.probabilistic
// - confidence: 0.82 (custom)
// - auditLevel: AuditLevel.detailed
// - priority: 20 (default)
```

### 3. PulseContext.regulated

For compliance-bound pulses:

```dart
final context = PulseContext.regulated(
  actor: 'Payment_Processor_B',
  framework: 'PCI-DSS',
  reason: 'Authorizing Transaction #992',
  baseContext: Context.system,
  sensitivity: Sensitivity.confidential,
);

// Properties:
// - compliance: 'PCI-DSS'
// - sensitivity: Sensitivity.confidential
// - auditLevel: AuditLevel.full
// - strategy: ReasoningStrategy.deterministic
// - priority: 85
// - purpose: 'REGULATED_TRANSACTION'
```

### 4. PulseContext.securityIntervention

For security events:

```dart
final context = PulseContext.securityIntervention(
  baseContext: Context.system,
  actor: 'Sentinel_Prime',
  reason: 'Brute-force pattern detected',
);

// Properties:
// - strategy: ReasoningStrategy.reflexive
// - priority: 100 (maximum)
// - sensitivity: Sensitivity.secret
// - auditLevel: AuditLevel.full
// - purpose: 'THREAT_MITIGATION'
// - confidence: 1.0
```

### 5. PulseContext.systemInternal

For system daemons:

```dart
final context = PulseContext.systemInternal(
  baseContext: Context.system,
  reason: 'Reclaiming stagnant state',
  purpose: 'GARBAGE_COLLECTION',
  priority: 35,
);

// Properties:
// - actor: 'system_daemon'
// - strategy: ReasoningStrategy.deterministic
// - confidence: 1.0
// - auditLevel: AuditLevel.minimal
// - sensitivity: Sensitivity.public
```

### 6. PulseContext.homeostasis

For maintenance tasks:

```dart
final context = PulseContext.homeostasis(
  actor: 'Cache_Janitor_Service',
  reason: 'Evicting stale entries',
  priority: 15,
);

// Properties:
// - purpose: 'SYSTEM_MAINTENANCE'
// - strategy: ReasoningStrategy.deterministic
// - confidence: 1.0
// - auditLevel: AuditLevel.minimal
// - sensitivity: Sensitivity.public
```

### 7. PulseContext.telemetry

For monitoring signals:

```dart
final context = PulseContext.telemetry(
  baseContext: Context.system,
  actor: 'Throughput_Monitor',
  reason: 'Reporting batch latency',
  purpose: 'METRIC_COLLECTION',
  priority: 10,
);

// Properties:
// - strategy: ReasoningStrategy.deterministic
// - confidence: 1.0
// - auditLevel: AuditLevel.none
// - sensitivity: Sensitivity.public
```

### 8. PulseContext.instruction

For administrative commands:

```dart
final context = PulseContext.instruction(
  baseContext: Context.system,
  humanActor: 'admin_user_01',
  directive: 'FLUSH_ALL_BUFFERS',
);

// Properties:
// - actor: 'admin_user_01'
// - strategy: ReasoningStrategy.deterministic
// - priority: 90
// - auditLevel: AuditLevel.full
// - purpose: 'MANUAL_OVERRIDE'
// - sensitivity: Sensitivity.public
```

### 9. PulseContext.infrastructureChange

For topology refactoring:

```dart
final context = PulseContext.infrastructureChange(
  baseContext: Context.system,
  actor: 'Orchestrator_Node_A',
  reason: 'Node saturation above 85%',
);

// Properties:
// - strategy: ReasoningStrategy.formal
// - confidence: 1.0
// - auditLevel: AuditLevel.standard
// - priority: 40
// - purpose: 'INFRASTRUCTURE_REFACTOR'
```

### 10. PulseContext.selfCorrection

For self-healing:

```dart
final context = PulseContext.selfCorrection(
  baseContext: Context.system,
  actor: 'Homeostasis_Guard',
  reason: 'Value out of bounds',
  targetField: 'somatic_pressure',
  confidence: 0.9,
);

// Properties:
// - strategy: ReasoningStrategy.deterministic
// - confidence: 0.9
// - auditLevel: AuditLevel.detailed
// - priority: 85
// - purpose: 'SELF_HEALING'
```

### 11. PulseContext.collaboration

For agent collaboration:

```dart
final context = PulseContext.collaboration(
  baseContext: Context.system,
  actor: 'Orchestrator_Agent',
  targetAgent: 'Database_Resident',
  task: 'Fetch user history',
);

// Properties:
// - strategy: ReasoningStrategy.deterministic
// - confidence: 1.0
// - auditLevel: AuditLevel.full
// - priority: 60
// - purpose: 'COLLABORATIVE_TASK'
```

### 12. PulseContext.hypothesis

For simulations:

```dart
final context = PulseContext.hypothesis(
  baseContext: Context.system,
  actor: 'Prediction_Agent_01',
  theory: 'Scaling memory allocation by 2x',
);

// Properties:
// - strategy: ReasoningStrategy.stochastic
// - confidence: 0.0
// - auditLevel: AuditLevel.none
// - priority: 20
// - purpose: 'SIMULATION'
```

### 13. PulseContext.audit

For compliance auditing:

```dart
final context = PulseContext.complianceAudit(
  baseContext: Context.system,
  actor: 'Security_Monitor_01',
  framework: 'HIPAA',
  reason: 'Quarterly access log verification',
  priority: 35,
);

// Properties:
// - compliance: 'HIPAA'
// - auditLevel: AuditLevel.full
// - strategy: ReasoningStrategy.deterministic
// - confidence: 1.0
// - purpose: 'AUDIT_LOG'
// - sensitivity: Sensitivity.confidential
```

---

## Provenance Dimensions

### Static Pillars

```dart
// actor - Who initiated the signal
Provenance.actor.entry('admin_001')

// traceId - Unique causal anchor
Provenance.traceId.entry('abc-123-def')

// parentTraceId - Ancestral trace ID
Provenance.parentTraceId.entry('xyz-789-uvw')

// compliance - Regulatory framework
Provenance.compliance.entry('GDPR')

// sensitivity - Data classification
Provenance.sensitivity.entry(Sensitivity.confidential)
```

### Fluid Boundaries

```dart
// reason - Immediate causal logic
Provenance.reason.entry('Manual override')

// purpose - Strategic intent
Provenance.purpose.entry('SYSTEM_UPDATE')

// strategy - Methodology
Provenance.strategy.entry(ReasoningStrategy.manual)

// confidence - Certainty estimate
Provenance.confidence.entry(0.85)

// priority - Execution urgency
Provenance.priority.entry(80)

// auditLevel - Observability depth
Provenance.auditLevel.entry(AuditLevel.full)
```

---

## Context Inheritance

### Basic Inheritance

```dart
// Parent context
final parent = PulseContext(
  actor: 'system',
  reason: 'parent reason',
  priority: 50,
);

// Child context - overrides reason, inherits actor
final child = PulseContext(
  baseContext: parent,
  reason: 'child reason',
  priority: 80,
);

print(child.actor);    // 'system' (inherited)
print(child.reason);   // 'child reason' (overridden)
print(child.priority); // 80 (overridden)
```

### Evolution

```dart
final base = PulseContext(
  actor: 'system',
  reason: 'base',
);

final evolved = base.evolve((evolvable) {
  if (evolvable == Provenance.reason) {
    return Provenance.reason.entry('evolved');
  }
  if (evolvable == Provenance.priority) {
    return Provenance.priority.entry(90);
  }
  return null;
});

print(evolved.actor);   // 'system' (inherited)
print(evolved.reason);  // 'evolved' (overridden)
print(evolved.priority); // 90 (overridden)
```

### Lineage Tracking

```dart
final base = PulseContext(actor: 'user');
final evolved = base.evolve((evolvable) {
  if (evolvable == Provenance.reason) {
    return Provenance.reason.entry('evolved');
  }
  return null;
});

final lineage = evolved.lineage(Provenance.actor);
// ['user', 'user']
```

---

## Using with Pulses

### Basic Usage

```dart
final context = PulseContext(
  actor: 'admin_001',
  reason: 'Manual update',
);

final pulse = Pulse.governed<String>(
  payload: 'Hello',
  context: context,
);
```

### With User Action

```dart
final context = PulseContext.userAction(
  actor: 'user_123',
  reason: 'Profile update',
  priority: 80,
);

final pulse = Pulse.governed<User>(
  payload: user,
  context: context,
);
```

### With AI Inference

```dart
final context = PulseContext.aiInference(
  actor: 'RecommendationEngine',
  reason: 'User viewed product',
  confidence: 0.85,
);

final pulse = Pulse.governed<Map<String, dynamic>>(
  payload: {'recommendation': 'product_456'},
  context: context,
);
```

### With Security Intervention

```dart
final context = PulseContext.securityIntervention(
  actor: 'Sentinel_Prime',
  reason: 'Suspicious activity detected',
);

final pulse = Pulse.governed<String>(
  payload: 'Security Alert',
  context: context,
);
```

### In a Receptor

```dart
final receptor = Receptor((cell, pulse, {user}) {
  final ctx = pulse.context;
  
  // Check authorization
  if (ctx.actor != 'admin_001') {
    print('Unauthorized: ${ctx.actor}');
    return null;
  }
  
  // Check confidence
  if (ctx.confidence != null && ctx.confidence! < 0.5) {
    print('Low confidence: ${ctx.confidence}');
    return null;
  }
  
  // Log the action
  print('Processing by ${ctx.actor}: ${ctx.reason}');
  
  return pulse;
});
```

### With Evolution

```dart
final pulse = Pulse.governed<String>(
  payload: 'Data',
  context: PulseContext(
    actor: 'system',
    reason: 'initial',
  ),
);

// Evolve the pulse
final evolved = pulse.evolve(
  step: 'processing',
  context: PulseContext(
    baseContext: pulse.context,
    reason: 'after processing',
  ),
);

print(evolved.context.actor);   // 'system' (inherited)
print(evolved.context.reason);  // 'after processing' (overridden)
```

---

## Testing PulseContext

### Unit Testing

```dart
import 'package:test/test.dart';

void main() {
  test('PulseContext creates correctly', () {
    final context = PulseContext(
      actor: 'admin_001',
      reason: 'Test',
      priority: 80,
    );
    expect(context.actor, 'admin_001');
    expect(context.reason, 'Test');
    expect(context.priority, 80);
  });

  test('PulseContext inherits properties', () {
    final parent = PulseContext(
      actor: 'system',
      reason: 'parent',
    );
    final child = PulseContext(
      baseContext: parent,
      reason: 'child',
    );
    expect(child.actor, 'system');
    expect(child.reason, 'child');
  });

  test('PulseContext evolves correctly', () {
    final base = PulseContext(
      actor: 'system',
      reason: 'base',
    );
    final evolved = base.evolve((evolvable) {
      if (evolvable == Provenance.reason) {
        return Provenance.reason.entry('evolved');
      }
      return null;
    });
    expect(evolved.actor, 'system');
    expect(evolved.reason, 'evolved');
  });
}
```

### Testing with Pulses

```dart
test('Pulse carries context', () {
  final context = PulseContext(
    actor: 'admin_001',
    reason: 'Test',
  );
  final pulse = Pulse.governed<String>(
    payload: 'Hello',
    context: context,
  );
  expect(pulse.context.actor, 'admin_001');
  expect(pulse.context.reason, 'Test');
});

test('Pulse context traces lineage', () {
  final base = PulseContext(actor: 'user');
  final pulse = Pulse.governed<String>(
    payload: 'Hello',
    context: base,
  );
  final evolved = pulse.evolve(
    step: 'processed',
    context: PulseContext(
      baseContext: base,
      reason: 'processed',
    ),
  );
  expect(evolved.context.actor, 'user');
  expect(evolved.context.reason, 'processed');
});
```

---

## Best Practices

### 1. Use Predefined Factories

```dart
// ✅ GOOD - Use factories
final context = PulseContext.userAction(
  actor: 'user_123',
  reason: 'Profile update',
);

// ❌ BAD - Manual construction
final context = PulseContext(
  actor: 'user_123',
  reason: 'Profile update',
  strategy: ReasoningStrategy.manual,
  confidence: 1.0,
);
```

### 2. Set Appropriate Confidence

```dart
// ✅ GOOD - AI with confidence
final context = PulseContext.aiInference(
  actor: 'AI_Model',
  reason: 'Prediction',
  confidence: 0.85,
);

// ❌ BAD - AI with 1.0 confidence (too certain)
final context = PulseContext.aiInference(
  actor: 'AI_Model',
  reason: 'Prediction',
  confidence: 1.0,  // Should be < 1.0 for AI
);
```

### 3. Use Appropriate Audit Level

```dart
// ✅ GOOD - Full audit for compliance
final context = PulseContext.regulated(
  actor: 'processor',
  framework: 'PCI-DSS',
  reason: 'Processing',
);

// ❌ BAD - No audit for compliance
final context = PulseContext.regulated(
  actor: 'processor',
  framework: 'PCI-DSS',
  reason: 'Processing',
  // auditLevel forced to full
);
```

### 4. Document Reasons

```dart
// ✅ GOOD - Clear reason
final context = PulseContext.userAction(
  actor: 'user_123',
  reason: 'Confirming payment for order #12345',
);

// ❌ BAD - Vague reason
final context = PulseContext.userAction(
  actor: 'user_123',
  reason: 'Click',
);
```

### 5. Use Parent Context for Tracing

```dart
// ✅ GOOD - Chain contexts
final parent = PulseContext(
  actor: 'system',
  reason: 'Started',
);
final child = PulseContext(
  baseContext: parent,
  reason: 'Processing',
);
final grandchild = PulseContext(
  baseContext: child,
  reason: 'Completed',
);

// ❌ BAD - No chain
final context = PulseContext(
  actor: 'system',
  reason: 'Completed',
);
```

---

## Complete Example

Here's a complete customer service system using PulseContext:

```dart
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// 1. Customer Service Domain
// ─────────────────────────────────────────────────────────────────────────

class CustomerAction {
  final String customerId;
  final String action;
  final Map<String, dynamic> data;

  CustomerAction({
    required this.customerId,
    required this.action,
    this.data = const {},
  });

  @override
  String toString() => 'CustomerAction($action for $customerId)';
}

// ─────────────────────────────────────────────────────────────────────────
// 2. Action Types
// ─────────────────────────────────────────────────────────────────────────

enum ActionType {
  userRequest,
  aiRecommendation,
  systemUpdate,
  securityCheck,
  complianceAudit,
}

// ─────────────────────────────────────────────────────────────────────────
// 3. Create Context Based on Action Type
// ─────────────────────────────────────────────────────────────────────────

PulseContext createContextForAction(
  ActionType type, {
  required String actor,
  required String reason,
  double? confidence,
  int? priority,
}) {
  switch (type) {
    case ActionType.userRequest:
      return PulseContext.userAction(
        actor: actor,
        reason: reason,
        priority: priority ?? 60,
      );

    case ActionType.aiRecommendation:
      return PulseContext.aiInference(
        actor: actor,
        reason: reason,
        confidence: confidence ?? 0.8,
        priority: priority ?? 20,
      );

    case ActionType.systemUpdate:
      return PulseContext.systemInternal(
        baseContext: Context.system,
        reason: reason,
        priority: priority ?? 35,
      );

    case ActionType.securityCheck:
      return PulseContext.securityIntervention(
        actor: actor,
        reason: reason,
      );

    case ActionType.complianceAudit:
      return PulseContext.complianceAudit(
        baseContext: Context.system,
        actor: actor,
        framework: 'GDPR',
        reason: reason,
        priority: priority ?? 35,
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 4. Processing Cell
// ─────────────────────────────────────────────────────────────────────────

final processor = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    final action = pulse.payload as CustomerAction;
    final ctx = pulse.context;

    print('\n📋 Processing Action: ${action.action}');
    print('   Customer: ${action.customerId}');
    print('   Actor: ${ctx.actor}');
    print('   Reason: ${ctx.reason}');
    print('   Strategy: ${ctx.strategy}');
    print('   Confidence: ${ctx.confidence}');
    print('   Priority: ${ctx.priority}');
    print('   TraceId: ${ctx.traceId}');

    // Process based on strategy
    if (ctx.strategy == ReasoningStrategy.probabilistic) {
      print('   🤖 AI Recommendation');
    } else if (ctx.strategy == ReasoningStrategy.manual) {
      print('   👤 User Action');
    } else if (ctx.strategy == ReasoningStrategy.reflexive) {
      print('   ⚡ Reflexive Response');
    }

    return pulse;
  }),
);

// ─────────────────────────────────────────────────────────────────────────
// 5. Main Demo
// ─────────────────────────────────────────────────────────────────────────

void main() {
  print('═══ Customer Service with PulseContext ═══\n');

  // User request
  final userAction = CustomerAction(
    customerId: 'CUST-001',
    action: 'Update Profile',
    data: {'name': 'Alice', 'email': 'alice@example.com'},
  );
  final userContext = createContextForAction(
    ActionType.userRequest,
    actor: 'user_123',
    reason: 'Profile update request',
  );
  final userPulse = Pulse.governed<CustomerAction>(
    payload: userAction,
    context: userContext,
  );
  processor._nucleus.receptor.call(userPulse);

  // AI recommendation
  final aiAction = CustomerAction(
    customerId: 'CUST-002',
    action: 'Product Recommendation',
    data: {'product': 'Laptop Pro', 'score': 0.92},
  );
  final aiContext = createContextForAction(
    ActionType.aiRecommendation,
    actor: 'Recommendation_Engine_v3',
    reason: 'User viewed similar products',
    confidence: 0.85,
  );
  final aiPulse = Pulse.governed<CustomerAction>(
    payload: aiAction,
    context: aiContext,
  );
  processor._nucleus.receptor.call(aiPulse);

  // System update
  final systemAction = CustomerAction(
    customerId: 'CUST-003',
    action: 'Cache Refresh',
    data: {},
  );
  final systemContext = createContextForAction(
    ActionType.systemUpdate,
    actor: 'Cache_Janitor',
    reason: 'Stale entries detected',
  );
  final systemPulse = Pulse.governed<CustomerAction>(
    payload: systemAction,
    context: systemContext,
  );
  processor._nucleus.receptor.call(systemPulse);

  // Security check
  final securityAction = CustomerAction(
    customerId: 'CUST-004',
    action: 'Access Audit',
    data: {'resource': 'sensitive_data.txt'},
  );
  final securityContext = createContextForAction(
    ActionType.securityCheck,
    actor: 'Sentinel_Guard',
    reason: 'Access pattern anomaly',
  );
  final securityPulse = Pulse.governed<CustomerAction>(
    payload: securityAction,
    context: securityContext,
  );
  processor._nucleus.receptor.call(securityPulse);

  print('\n═══ Done ═══');
}
```

**Expected Output:**
```
═══ Customer Service with PulseContext ═══

📋 Processing Action: Update Profile
   Customer: CUST-001
   Actor: user_123
   Reason: Profile update request
   Strategy: manual
   Confidence: 1.0
   Priority: 60
   TraceId: abc-123-def
   👤 User Action

📋 Processing Action: Product Recommendation
   Customer: CUST-002
   Actor: Recommendation_Engine_v3
   Reason: User viewed similar products
   Strategy: probabilistic
   Confidence: 0.85
   Priority: 20
   TraceId: ghi-789-jkl
   🤖 AI Recommendation

📋 Processing Action: Cache Refresh
   Customer: CUST-003
   Actor: Cache_Janitor
   Reason: Stale entries detected
   Strategy: deterministic
   Confidence: 1.0
   Priority: 35
   TraceId: mno-456-pqr
   👤 User Action

📋 Processing Action: Access Audit
   Customer: CUST-004
   Actor: Sentinel_Guard
   Reason: Access pattern anomaly
   Strategy: reflexive
   Confidence: 1.0
   Priority: 100
   TraceId: stu-789-vwx
   ⚡ Reflexive Response

═══ Done ═══
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **PulseContext** | Provenance metadata for pulses |
| **Static Pillars** | Identity dimensions (actor, traceId, etc.) |
| **Fluid Boundaries** | Intent dimensions (reason, purpose, etc.) |
| **Inheritance** | Prototype-based via `baseContext` |
| **Evolution** | Refine context with `evolve()` |
| **Lineage** | Track dimension evolution |
| **Strategy** | Reasoning method (manual, AI, etc.) |

### Key Rules

1. **Use factories for common scenarios** - `userAction`, `aiInference`, etc.
2. **Set appropriate confidence** - AI < 1.0, manual = 1.0
3. **Use parent context for tracing** - Chain contexts for lineage
4. **Document reasons clearly** - Explain why the action occurred
5. **Set appropriate audit level** - Full for compliance, none for telemetry
6. **Check strategy for processing** - Different handling for AI vs manual

### Common Patterns

```dart
// Pattern: User action
final context = PulseContext.userAction(
  actor: 'user_123',
  reason: 'Profile update',
);

// Pattern: AI inference
final context = PulseContext.aiInference(
  actor: 'AI_Model',
  reason: 'Prediction',
  confidence: 0.85,
);

// Pattern: Security intervention
final context = PulseContext.securityIntervention(
  actor: 'Sentinel',
  reason: 'Anomaly detected',
);

// Pattern: Context inheritance
final child = PulseContext(
  baseContext: parent,
  reason: 'child reason',
);

// Pattern: Context evolution
final evolved = base.evolve((evolvable) {
  if (evolvable == Provenance.reason) {
    return Provenance.reason.entry('evolved');
  }
  return null;
});
```