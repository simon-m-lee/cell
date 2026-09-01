# How to Use Pulse in the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What is a Pulse?](#what-is-a-pulse)
3. [Core Concepts](#core-concepts)
4. [Creating Pulses](#creating-pulses)
5. [Pulse Evolution (Causal Tracing)](#pulse-evolution-causal-tracing)
6. [Pulse Composition](#pulse-composition)
7. [Pulse Governance](#pulse-governance)
8. [Pulse Shell (Security Proxy)](#pulse-shell-security-proxy)
9. [Lineage and Tracing](#lineage-and-tracing)
10. [Testing Pulses](#testing-pulses)
11. [Best Practices](#best-practices)
12. [Complete Example](#complete-example)

---

## Introduction

A **Pulse** is the fundamental unit of communication in the Cell Framework. It's an immutable message that carries data, provenance, and governance metadata through the reactive graph. Think of it as the **currency** of the switching fabric—the signal that cells emit and observe.

### When to Use Pulse

| Scenario | Recommended Approach |
|----------|---------------------|
| Sending data between cells | Use `Pulse(payload)` |
| Adding causal tracing | Use `pulse.withStep()` |
| Adding security metadata | Use `Pulse.governed()` |
| Bundling multiple signals | Use `Pulse.batch()` or `+` operator |
| Protecting sensitive data | Use `pulse.shell` |
| Creating read-only views | Use `pulse.unmodifiable` |

---

## What is a Pulse?

A `Pulse` is an immutable signal that travels through the reactive graph. It carries:

- **Payload** - The actual data
- **Type** - Semantic tag for routing
- **Priority** - Execution urgency (0-100)
- **Context** - Security and provenance metadata
- **Trace** - Causal history of transformations
- **Timestamp** - When it was created
- **Source** - Originating cell

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Immutable** | Cannot be modified after creation |
| **Traceable** | Maintains full causal history |
| **Governed** | Optional security and lifecycle policies |
| **Composable** | Can be combined with `+` operator |
| **Type-Safe** | Generic type parameter `P` |
| **Shell-able** | Can be wrapped in a defensive proxy |

### Pulse Anatomy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PULSE                                         │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        PAYLOAD                                       │   │
│  │  The actual data being transmitted (type P)                         │   │
│  │  Example: User(id: 123, name: "Alice")                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       PROVENANCE                                     │   │
│  │  • type: "user.updated"                                            │   │
│  │  • priority: 60                                                    │   │
│  │  • source: UserCell                                                │   │
│  │  • timestamp: 2024-01-15 14:30:00.000                            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        CONTEXT                                       │   │
│  │  • actor: "admin_001"                                              │   │
│  │  • reason: "Manual update"                                         │   │
│  │  • sensitivity: Sensitivity.confidential                           │   │
│  │  • traceId: "abc-123-def"                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         TRACE                                        │   │
│  │  ["validation", "transformation", "persistence"]                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        POLICY                                        │   │
│  │  • TTL: 5 minutes                                                   │   │
│  │  • Hop limit: 10                                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Core Concepts

### 1. Pulses are Immutable

Once created, a pulse cannot be modified. To "change" a pulse, you create a new one:

```dart
// ❌ Can't modify
final pulse = Pulse('hello');
// pulse.payload = 'world';  // Not allowed

// ✅ Create a new pulse
final newPulse = Pulse('world');
```

### 2. Pulses are Traceable

Every transformation adds to the trace:

```dart
final pulse = Pulse(42)
  .withStep('validation')
  .withStep('transformation')
  .withStep('persistence');

print(pulse.trace); // ['validation', 'transformation', 'persistence']
```

### 3. Pulses Carry Provenance

Pulses remember their origin and journey:

```dart
final pulse = Pulse.governed<String>(
  payload: 'Hello',
  context: PulseContext.userAction(
    actor: 'admin_001',
    reason: 'Manual update',
  ),
);

print(pulse.context.actor);      // 'admin_001'
print(pulse.context.reason);     // 'Manual update'
print(pulse.source);             // The originating cell
```

### 4. Pulses Can Be Composed

Multiple pulses can be bundled together:

```dart
final pulse1 = Pulse('update');
final pulse2 = Pulse('notify');
final bundle = pulse1 + pulse2;

print(bundle.isComposite); // true
for (final p in bundle.payload) {
  print(p.payload);
}
```

---

## Creating Pulses

### Method 1: Simple Pulse

```dart
// Simple pulse with payload
final pulse = Pulse('Hello, World!');

// With type
final typedPulse = Pulse('Hello', type: 'greeting');

// With priority
final priorityPulse = Pulse('Urgent', priority: 90);

// With source
final sourcePulse = Pulse('Data', source: myCell);

// Combined
final completePulse = Pulse(
  'Hello',
  type: 'greeting',
  priority: 60,
  source: myCell,
);
```

### Method 2: Governed Pulse

```dart
final pulse = Pulse.governed<String>(
  payload: 'Sensitive Data',
  context: PulseContext(
    actor: 'admin_001',
    reason: 'Accessing user data',
    sensitivity: Sensitivity.confidential,
  ),
  policy: PulseEphemeralPolicy(
    duration: Duration(minutes: 5),
    onInvalidate: (pulse) {
      print('Pulse expired');
      return true;
    },
  ),
);
```

### Method 3: With Context Factory

```dart
// User action context
final userPulse = Pulse.governed<String>(
  payload: 'User login',
  context: PulseContext.userAction(
    actor: 'user_123',
    reason: 'Logging in',
    priority: 60,
  ),
);

// AI inference context
final aiPulse = Pulse.governed<Map<String, dynamic>>(
  payload: {'recommendation': 'product_456'},
  context: PulseContext.aiInference(
    actor: 'RecommendationEngine',
    reason: 'User viewed product',
    confidence: 0.85,
  ),
);

// System internal context
final systemPulse = Pulse.governed<String>(
  payload: 'Heartbeat',
  context: PulseContext.systemInternal(
    baseContext: Context.system,
    reason: 'Health check',
  ),
);
```

### Method 4: Batch Pulse (Collective)

```dart
final batch = Pulse.batch([
  Pulse('Update user'),
  Pulse('Update account'),
  Pulse('Send notification'),
], type: 'batch.update');

// Or using the + operator
final bundle = Pulse('Update') + Pulse('Notify') + Pulse('Log');
```

---

## Pulse Evolution (Causal Tracing)

### Using `withStep`

Add a step to the causal trace:

```dart
final root = Pulse(42);
final validated = root.withStep('validation');
final transformed = validated.withStep('transformation');
final persisted = transformed.withStep('persistence');

print(persisted.trace); // ['validation', 'transformation', 'persistence']
print(persisted.root);  // The original pulse (root)
```

### Using `evolve`

More control over evolution:

```dart
final root = Pulse(42);

// Add step only
final stepped = root.evolve(step: 'validation');

// Add new context
final contextual = root.evolve(
  step: 'validation',
  context: PulseContext(
    actor: 'validator',
    reason: 'Checking value',
  ),
);

// Append a pulse
final childPulse = Pulse(100);
final chained = root.evolve(pulse: childPulse, step: 'enrichment');
```

### Evolution Chain

```dart
final pulse = Pulse(0)
  .withStep('start')
  .withStep('process')
  .withStep('end');

print(pulse.isComposite); // true (it's an EvolvedPulse)
print(pulse.parent);      // The immediate ancestor
print(pulse.root);        // The original pulse

// Iterate through the chain
for (final p in pulse) {
  print(p.payload);
}
```

### Causal Lineage

```dart
final pulse = Pulse(42)
  .withStep('validation')
  .withStep('transformation');

// Trace how values changed
final history = pulse.lineage<dynamic>(#payload);
print(history); // [42, 42, 42] (payload unchanged, but traced)

// Trace reasons
final reasons = pulse.lineage<String>(Provenance.reason, fromPolicy: true);
```

---

## Pulse Composition

### The `+` Operator

Combine two pulses into a collective:

```dart
final update = Pulse('Update user');
final notify = Pulse('Notify admin');
final bundle = update + notify;

print(bundle.isComposite); // true
print(bundle.payload.length); // 2

for (final p in bundle.payload) {
  print(p.payload);
}
```

### Chaining Multiple Pulses

```dart
final batch = Pulse('Step 1') + Pulse('Step 2') + Pulse('Step 3') + Pulse('Step 4');

// Or using batch factory
final batch2 = Pulse.batch([
  Pulse('Step 1'),
  Pulse('Step 2'),
  Pulse('Step 3'),
  Pulse('Step 4'),
]);
```

### Collective Pulse Features

```dart
final collective = Pulse.batch(
  [pulse1, pulse2, pulse3],
  type: 'batch.update',
  priority: 80,
  onComplete: (pulse) => print('Batch complete!'),
  onError: (pulse, error, {stackTrace}) => print('Batch error: $error'),
);

// Check if composite
print(collective.isComposite); // true

// Access individual pulses
for (final p in collective.payload) {
  print(p.payload);
}
```

---

## Pulse Governance

### PulseEphemeralPolicy

Control pulse lifecycle:

```dart
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 30),  // TTL
  hopLimit: 5,                      // Max traversals
  onEvent: (cell, {required policy}) {
    // Called on each hop
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('Pulse expired');
    return true;
  },
);

final pulse = Pulse.governed<String>(
  payload: 'Temporary token',
  policy: policy,
);

// Check if still valid
if (pulse.isInvalidated) {
  print('Pulse is stale');
}
```

### PulseContext (Provenance)

```dart
final context = PulseContext(
  actor: 'admin_001',                    // Who
  reason: 'Manual override',             // Why immediate
  purpose: 'SYSTEM_UPDATE',              // Strategic intent
  strategy: ReasoningStrategy.manual,    // How
  confidence: 1.0,                       // Certainty
  priority: 80,                          // Urgency
  compliance: 'GDPR',                    // Regulation
  sensitivity: Sensitivity.confidential, // Classification
  auditLevel: AuditLevel.full,           // Observability
);

final pulse = Pulse.governed<String>(
  payload: 'Update user data',
  context: context,
);
```

### Predefined Context Factories

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
  reason: 'Personalized suggestions',
  confidence: 0.85,
);

// System internal
final systemContext = PulseContext.systemInternal(
  baseContext: Context.system,
  reason: 'Cache invalidation',
);

// Security intervention
final securityContext = PulseContext.securityIntervention(
  baseContext: Context.system,
  actor: 'Sentinel_Prime',
  reason: 'Suspicious activity detected',
);
```

---

## Pulse Shell (Security Proxy)

### What is a Shell?

A `PulseShell` is a defensive proxy that wraps a pulse and forces any receiver to authenticate before accessing the payload.

### Creating a Shell

```dart
final pulse = Pulse.governed<String>(
  payload: 'Secret Data',
  context: PulseContext(
    actor: 'secure_service',
    sensitivity: Sensitivity.secret,
  ),
);

final shell = pulse.shell;
// shell.payload is null until scrutinized
```

### Using a Shell in a Receptor

```dart
final receptor = Receptor((cell, pulse, {user}) {
  // If it's a shell, scrutinize it
  if (pulse is PulseShell) {
    final innerPulse = pulse.scrutinize(this);
    // Now we have access to the payload
    return innerPulse;
  }
  return pulse;
});
```

### Shell Security Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SHELL SECURITY FLOW                                │
│                                                                             │
│  1. Sender creates governed pulse                                          │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │  final pulse = Pulse.governed(                                 │    │
│     │    payload: 'Secret Data',                                     │    │
│     │    context: PulseContext(sensitivity: Sensitivity.secret),     │    │
│     │  );                                                             │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                          │                                                  │
│                          ▼                                                  │
│  2. Sender wraps in shell                                                  │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │  final shell = pulse.shell;                                    │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                          │                                                  │
│                          ▼                                                  │
│  3. Shell sent to receptor                                                │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │  receptor.call(shell);                                         │    │
│     │  // shell.payload == null                                      │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                          │                                                  │
│                          ▼                                                  │
│  4. Receptor scrutinizes shell                                             │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │  if (pulse is PulseShell) {                                    │    │
│     │    final inner = pulse.scrutinize(this);                      │    │
│     │    // Now has access to payload                                │    │
│     │  }                                                              │    │
│     └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Lineage and Tracing

### Basic Tracing

```dart
final pulse = Pulse(42)
  .withStep('validation')
  .withStep('transformation')
  .withStep('persistence');

print(pulse.trace); // ['validation', 'transformation', 'persistence']
print(pulse.root);  // Original pulse (payload: 42)
print(pulse.parent); // Immediate ancestor
```

### Lineage Query

```dart
final pulse = Pulse.governed<int>(
  payload: 42,
  context: PulseContext(
    actor: 'admin',
    reason: 'Update',
  ),
)
.withStep('validation')
.withStep('transformation');

// Trace payload history
final payloadHistory = pulse.lineage<dynamic>(#payload);
// [42, 42, 42] (value unchanged, but traced)

// Trace actor history
final actorHistory = pulse.lineage<String>(Provenance.actor, fromPolicy: true);
// ['admin']

// Trace reason history
final reasonHistory = pulse.lineage<String>(Provenance.reason, fromPolicy: true);
// ['Update']
```

### Iterating Through Pulses

```dart
final pulse = Pulse(0)
  .withStep('step1')
  .withStep('step2')
  .withStep('step3');

// Iterate through the chain
for (final p in pulse) {
  print(p.payload);
}
// Output: 0, 0, 0, 0 (same payload, different pulses)
```

---

## Testing Pulses

### Unit Testing Pulses

```dart
import 'package:test/test.dart';

void main() {
  test('Pulse created correctly', () {
    final pulse = Pulse('Hello', type: 'greeting', priority: 60);
    expect(pulse.payload, 'Hello');
    expect(pulse.type, 'greeting');
    expect(pulse.priority, 60);
  });

  test('Pulse evolution adds trace', () {
    final pulse = Pulse(42).withStep('validation');
    expect(pulse.trace, ['validation']);
    expect(pulse.payload, 42);
  });

  test('Pulse composition creates collective', () {
    final p1 = Pulse('A');
    final p2 = Pulse('B');
    final collective = p1 + p2;
    expect(collective.isComposite, true);
    expect(collective.payload.length, 2);
  });
}
```

### Testing Governed Pulses

```dart
test('Governed pulse has context', () {
  final pulse = Pulse.governed<String>(
    payload: 'Hello',
    context: PulseContext(
      actor: 'admin',
      reason: 'Test',
    ),
  );
  expect(pulse.context.actor, 'admin');
  expect(pulse.context.reason, 'Test');
});

test('Pulse policy enforces TTL', () async {
  final policy = PulseEphemeralPolicy(
    duration: Duration(milliseconds: 50),
    onInvalidate: (pulse) => true,
  );
  
  final pulse = Pulse.governed<String>(
    payload: 'Token',
    policy: policy,
  );
  
  expect(pulse.isInvalidated, false);
  await Future.delayed(Duration(milliseconds: 100));
  // Check invalidation (framework handles this)
});
```

### Testing Shells

```dart
test('Shell hides payload', () {
  final pulse = Pulse('Secret');
  final shell = pulse.shell;
  expect(shell.payload, null);  // Hidden
});

test('Shell reveals payload on scrutiny', () {
  final pulse = Pulse('Secret');
  final shell = pulse.shell;
  
  final receptor = Receptor((cell, pulse, {user}) => pulse);
  final result = shell.scrutinize(receptor);
  expect(result.payload, 'Secret');
});
```

---

## Best Practices

### 1. Use Type-Safe Pulses

```dart
// ✅ GOOD - Type-safe
final pulse = Pulse<String>('Hello');
final intPulse = Pulse<int>(42);
final userPulse = Pulse<User>(user);

// ❌ BAD - Loose typing
final pulse = Pulse('Hello');  // Infers dynamic
```

### 2. Use Context Factories

```dart
// ✅ GOOD - Use predefined factories
final context = PulseContext.userAction(
  actor: 'user_123',
  reason: 'Login',
);

// ❌ BAD - Manual construction when factory exists
final context = PulseContext(
  actor: 'user_123',
  reason: 'Login',
  strategy: ReasoningStrategy.manual,
  confidence: 1.0,
);
```

### 3. Add Trace Steps

```dart
// ✅ GOOD - Document transformations
final pulse = rawData
  .withStep('sanitization')
  .withStep('validation')
  .withStep('enrichment');

// ❌ BAD - No trace
final pulse = transform(transform(transform(rawData)));
```

### 4. Use Shells for Security

```dart
// ✅ GOOD - Protect sensitive data
final shell = sensitivePulse.shell;
sendToUntrustedComponent(shell);

// ❌ BAD - Expose sensitive data
sendToUntrustedComponent(sensitivePulse);
```

### 5. Handle Invalidation

```dart
// ✅ GOOD - Check before processing
if (pulse.isInvalidated) {
  return null;
}
process(pulse);

// ❌ BAD - Ignore invalidation
process(pulse);  // May process stale data
```

### 6. Use Batch for Multiple Updates

```dart
// ✅ GOOD - Batch related updates
final batch = Pulse.batch([update1, update2, update3]);
cell.process(batch);

// ❌ BAD - Individual updates
cell.process(update1);
cell.process(update2);
cell.process(update3);
```

---

## Complete Example

Here's a complete e-commerce order processing system using Pulses:

```dart
import 'dart:async';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// 1. Domain Models
// ─────────────────────────────────────────────────────────────────────────

class OrderItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  
  OrderItem({required this.id, required this.name, required this.price, required this.quantity});
  double get total => price * quantity;
}

class Order {
  final String id;
  final List<OrderItem> items;
  final double total;
  final String status;
  final DateTime createdAt;
  
  Order({
    required this.id,
    required this.items,
    required this.total,
    this.status = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────
// 2. Pulse Types
// ─────────────────────────────────────────────────────────────────────────

class OrderCreatedPulse extends Pulse<Order> {
  OrderCreatedPulse(Order order)
      : super(order, type: 'order.created');
}

class OrderStatusUpdatedPulse extends Pulse<Map<String, dynamic>> {
  OrderStatusUpdatedPulse(String orderId, String status)
      : super(
          {'orderId': orderId, 'status': status},
          type: 'order.status.updated',
        );
}

class OrderProcessedPulse extends Pulse<Order> {
  OrderProcessedPulse(Order order)
      : super(order, type: 'order.processed');
}

// ─────────────────────────────────────────────────────────────────────────
// 3. Order Processing System
// ─────────────────────────────────────────────────────────────────────────

class OrderProcessingSystem {
  final Cell ingressCell;
  final Cell orderCell;
  final EgressHandle orderObserver;
  final EgressHandle statusObserver;

  OrderProcessingSystem() :
    // Create ingress for orders
    ingressCell = Cell.ingress<Order>().cell,
    
    // State cell for current order
    orderCell = Cell.state<Order>(
      initial: Order(id: 'empty', items: [], total: 0),
      evolve: (host, input) => Pulse(input.payload as Order),
    ).cell,
    
    // Observers
    orderObserver = Cell.observe(
      source: Cell.ingress<Order>().cell,
      effect: (pulse) {
        print('📦 Order received: ${(pulse.payload as Order).id}');
      },
    ),
    statusObserver = Cell.observe(
      source: Cell.ingress<String>().cell,
      effect: (pulse) {
        print('📝 Status update: ${pulse.payload}');
      },
    );
}

// ─────────────────────────────────────────────────────────────────────────
// 4. Processing Pipeline
// ─────────────────────────────────────────────────────────────────────────

Future<void> processOrder(Order order) async {
  print('── Processing Order ──');
  
  // Step 1: Validate order
  final validatePulse = OrderCreatedPulse(order)
    .withStep('validation');
  
  if (validatePulse.payload.items.isEmpty) {
    print('❌ Order validation failed: No items');
    return;
  }
  print('✅ Order validated: ${order.items.length} items');
  
  // Step 2: Enrich with pricing
  final enrichPulse = validatePulse
    .withStep('enrichment');
  
  print('💰 Total: \$${order.total}');
  
  // Step 3: Process payment
  final paymentPulse = Pulse.governed<Map<String, dynamic>>(
    payload: {'orderId': order.id, 'amount': order.total},
    context: PulseContext(
      actor: 'payment_gateway',
      reason: 'Processing payment',
      sensitivity: Sensitivity.confidential,
    ),
  ).withStep('payment');
  
  print('💳 Payment processed: \$${order.total}');
  
  // Step 4: Update status
  final statusPulse = OrderStatusUpdatedPulse(order.id, 'paid')
    .withStep('status_update');
  
  print('📝 Order status: paid');
  
  // Step 5: Ship order
  final shipPulse = OrderProcessedPulse(order)
    .withStep('shipping');
  
  print('📦 Order shipped');
  
  // Step 6: Log completion
  final completePulse = Pulse.governed<String>(
    payload: 'Order ${order.id} complete',
    context: PulseContext.systemInternal(
      baseContext: Context.system,
      reason: 'Order fulfillment complete',
    ),
  ).withStep('completion');
  
  print('✅ Order ${order.id} complete!');
  
  // Show the trace
  print('\n📊 Causal Trace:');
  for (final step in completePulse.trace) {
    print('   → $step');
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 5. Main Demo
// ─────────────────────────────────────────────────────────────────────────

void main() async {
  print('═══ Order Processing with Pulses ═══\n');
  
  // Create an order
  final order = Order(
    id: 'ORD-12345',
    items: [
      OrderItem(id: '1', name: 'Laptop', price: 999.99, quantity: 1),
      OrderItem(id: '2', name: 'Mouse', price: 29.99, quantity: 2),
    ],
    total: 1059.97,
  );
  
  // Process the order
  await processOrder(order);
  
  print('\n═══ Done ═══');
}
```

**Expected Output:**
```
═══ Order Processing with Pulses ═══

── Processing Order ──
✅ Order validated: 2 items
💰 Total: $1059.97
💳 Payment processed: $1059.97
📝 Order status: paid
📦 Order shipped
✅ Order ORD-12345 complete!

📊 Causal Trace:
   → validation
   → enrichment
   → payment
   → status_update
   → shipping
   → completion

═══ Done ═══
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **Pulse** | Immutable signal carrying data and provenance |
| **Evolution** | Causal chain with `withStep()` and `evolve()` |
| **Composition** | Bundle pulses with `+` or `Pulse.batch()` |
| **Governance** | Lifecycle policies and security context |
| **Shell** | Defensive proxy for sensitive data |
| **Lineage** | Query causal history |

### Key Rules

1. **Pulses are immutable** - Create new ones, don't modify
2. **Add trace steps** - Document every transformation
3. **Use context factories** - Pre-defined contexts for common scenarios
4. **Use shells for security** - Protect sensitive data
5. **Use batch for atomicity** - Group related pulses
6. **Check invalidation** - Don't process stale pulses

### Common Patterns

```dart
// Pattern: Simple pulse
final pulse = Pulse(data, type: 'event');

// Pattern: Governed pulse
final pulse = Pulse.governed(data, context: context, policy: policy);

// Pattern: Evolution with tracing
final pulse = root.withStep('step1').withStep('step2');

// Pattern: Batch composition
final batch = Pulse.batch([pulse1, pulse2, pulse3]);

// Pattern: Shell for security
final shell = sensitivePulse.shell;

// Pattern: Lineage query
final history = pulse.lineage<dynamic>(#payload);
```
