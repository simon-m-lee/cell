# How to Use Nucleus in the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What is a Nucleus?](#what-is-a-nucleus)
3. [Core Concepts](#core-concepts)
4. [Creating a Nucleus](#creating-a-nucleus)
5. [Nucleus Inheritance (Prototype Pattern)](#nucleus-inheritance-prototype-pattern)
6. [Activating a Nucleus](#activating-a-nucleus)
7. [Cloning a Nucleus](#cloning-a-nucleus)
8. [Nucleus with ValueCell](#nucleus-with-valuecell)
9. [Testing Nucleus](#testing-nucleus)
10. [Best Practices](#best-practices)
11. [Complete Example](#complete-example)

---

## Introduction

A **Nucleus** is the immutable blueprint that defines a `Cell`'s behavior. It encapsulates everything a cell needs to function:
- **Receptor** - How it transforms incoming pulses
- **TestCell** - What it's allowed to accept
- **Context** - What tier/domain it belongs to
- **Synapses** - Who it notifies on change
- **EphemeralPolicy** - Lifecycle management

### When to Use Nucleus

| Scenario | Recommended Approach |
|----------|---------------------|
| Creating a standard cell | Use `Cell` or `Cell.state` factories |
| Creating a governed cell | Use `Cell.governed` |
| Creating a deputy/proxy | Use `Cell.deputy` |
| Custom infrastructure | Use `Nucleus` directly |
| Sharing behavior across cells | Use `Nucleus` with inheritance |
| Serializing/deserializing cell behavior | Use `Nucleus` |

---

## What is a Nucleus?

A `Nucleus` is a **stateless blueprint** that defines a cell's behavior. It is immutable and can be shared across multiple cells.

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Immutable** | Once created, cannot be modified |
| **Flyweight** | Can be shared across many cells |
| **Inheritable** | Supports prototype-based inheritance |
| **Clonable** | Can be cloned for independent use |
| **Activable** | Can be bound to a live cell |

### Relationship with Cell

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CELL FRAMEWORK                                   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         CELL (Live Instance)                        │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │                    NUCLEUS (Blueprint)                       │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │   │   │
│  │  │  │  RECEPTOR   │  │  TESTCELL   │  │  CONTEXT    │          │   │   │
│  │  │  │  Transform  │  │  Validate   │  │  Security   │          │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘          │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │   │   │
│  │  │  │  SYNAPSES   │  │  EPHEMERAL  │  │    BIND     │          │   │   │
│  │  │  │  Egress     │  │  Policy     │  │  Upstream   │          │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘          │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │                    STATE (Mutable)                           │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐                           │   │   │
│  │  │  │    BOX      │  │    LOCK     │                           │   │   │
│  │  │  │   Storage   │  │  Synchronization                        │   │   │
│  │  │  └─────────────┘  └─────────────┘                           │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### The Flyweight Pattern

Nucleus uses the **Flyweight Pattern** to minimize memory usage:

```dart
// Multiple cells can share the same nucleus
final sharedNucleus = Nucleus(
  receptor: Receptor.passThrough,
  testRule: TestCell.allowAll,
  context: Context.system,
);

final cell1 = Cell.fromNucleus(sharedNucleus);
final cell2 = Cell.fromNucleus(sharedNucleus);
// Both cells share the same blueprint
```

### Inheritance (Prototype Pattern)

Nucleus supports **prototype-based inheritance**:

```dart
final parent = Nucleus(
  receptor: myReceptor,
  testRule: myTestRule,
  context: Context.system,
);

final child = Nucleus.evolve(
  principal: parent,
  testRule: moreRestrictiveRule,  // Override only this
);
// child inherits receptor and context from parent
```

---

## Core Concepts

### 1. Nucleus is Immutable

Once created, a Nucleus cannot be changed. To modify behavior, create a new Nucleus or use `evolve`:

```dart
// ❌ Can't modify after creation
final nucleus = Nucleus(...);
// nucleus.receptor = newReceptor;  // Not allowed

// ✅ Create a new one with changes
final newNucleus = Nucleus.evolve(
  principal: nucleus,
  receptor: newReceptor,
);
```

### 2. Nucleus is a Flyweight

A single Nucleus can be used by many cells, saving memory:

```dart
final sharedNucleus = Nucleus(
  receptor: Receptor.passThrough,
  testRule: TestCell.allowAll,
  context: Context.system,
);

// 1000 cells sharing the same blueprint
for (int i = 0; i < 1000; i++) {
  final cell = Cell.fromNucleus(sharedNucleus);
}
```

### 3. Nucleus Supports Inheritance

Properties are resolved by walking up the `principal` chain:

```dart
// Root nucleus
final root = Nucleus(
  context: Context.system,
  receptor: Receptor.passThrough,
  testRule: TestCell.allowAll,
);

// Child nucleus - overrides testRule only
final child = Nucleus.evolve(
  principal: root,
  testRule: myStrictRule,
);

// Grandchild - overrides receptor only
final grandchild = Nucleus.evolve(
  principal: child,
  receptor: myCustomReceptor,
);

// grandchild resolves:
// - context from root (Context.system)
// - testRule from child (myStrictRule)
// - receptor from grandchild (myCustomReceptor)
```

### 4. Nucleus is Optimized

Internally, Nucleus uses **bitmask optimization** to store only non-default values:

```dart
// This stores only what's needed
final nucleus = Nucleus(
  receptor: myReceptor,  // Non-default
  // context defaults to Context.system (not stored)
  // testRule defaults to TestCell.allowAll (not stored)
);
```

---

## Creating a Nucleus

### Method 1: Basic Constructor

```dart
final nucleus = Nucleus(
  receptor: Receptor.passThrough,
  testRule: TestCell.allowAll,
  context: Context.system,
  synapses: Synapses.enabled,
  forceLock: false,
);
```

### Method 2: With Ephemeral Policy

```dart
final nucleus = Nucleus(
  ephemeralPolicy: EphemeralPolicy(
    duration: Duration(minutes: 5),
    onEvent: (object, {required cell, policy, arguments, user}) {
      // Reset timer on access
      return (events: 0);
    },
    onInvalidate: (nucleus) {
      // Cleanup
      return true;
    },
  ),
  receptor: Receptor.passThrough,
  testRule: TestCell.allowAll,
  context: Context.system,
);
```

### Method 3: With Bind (Upstream Dependency)

```dart
final sourceCell = Cell.state<int>(initial: 0);

final nucleus = Nucleus(
  bind: sourceCell,
  receptor: Receptor((cell, pulse, {user}) {
    final value = pulse.payload as int;
    return Pulse(value * 2);
  }),
  testRule: TestCell.allowAll,
  context: Context.system,
);

final derivedCell = Cell.fromNucleus(nucleus);
// derivedCell automatically receives pulses from sourceCell
```

### Method 4: Using Nucleus.create (Typed)

```dart
final nucleus = Nucleus.create<MyCell>(
  receptor: Receptor((cell, pulse, {user}) {
    // cell is typed as MyCell
    return pulse;
  }),
  context: Context.module('my-module'),
);
```

### Method 5: Empty Nucleus (Root)

```dart
final empty = Nucleus.empty();
// All properties resolve to framework defaults
```

---

## Nucleus Inheritance (Prototype Pattern)

### Using Nucleus.evolve

```dart
// Base blueprint
final baseNucleus = Nucleus(
  context: Context.module('base'),
  receptor: Receptor((cell, pulse, {user}) {
    print('Base processing: ${pulse.payload}');
    return pulse;
  }),
  testRule: TestCell.allowAll,
);

// Specialized blueprint
final authNucleus = Nucleus.evolve(
  principal: baseNucleus,
  testRule: TestCell((value, {host, ...}) {
    // Only allow authenticated values
    return value is String && value.isNotEmpty;
  }),
);

// More specialized
final adminNucleus = Nucleus.evolve(
  principal: authNucleus,
  context: Context.module('admin', stakeholders: 'Admin'),
  receptor: Receptor((cell, pulse, {user}) {
    print('Admin processing: ${pulse.payload}');
    return pulse;
  }),
);

// adminNucleus inherits:
// - testRule from authNucleus
// - context from adminNucleus (overrides base)
// - receptor from adminNucleus (overrides base)
```

### Override Priority

Properties are resolved in this order:

1. **Local override** - explicitly set in the current nucleus
2. **Principal chain** - walk up the `principal` chain
3. **Default** - framework defaults

```dart
final root = Nucleus(
  context: Context.system,           // Default
  receptor: Receptor.passThrough,    // Default
  testRule: TestCell.allowAll,       // Default
);

final child = Nucleus.evolve(
  principal: root,
  testRule: myRule,                  // Override
);

// child resolves:
// - context: Context.system (from root)
// - receptor: Receptor.passThrough (from root)
// - testRule: myRule (local override)
```

---

## Activating a Nucleus

### Automatic Activation

When you create a cell from a nucleus, it's automatically activated:

```dart
final nucleus = Nucleus(...);
final cell = Cell.fromNucleus(nucleus);
// nucleus.isActivated == true
```

### Manual Activation

```dart
final nucleus = Nucleus(...);
final cell = MyCell();

final activated = nucleus.activate(cell);
if (activated) {
  print('Nucleus activated');
}
```

### Activation State

```dart
final nucleus = Nucleus(...);

print(nucleus.isActivated); // false

final cell = Cell.fromNucleus(nucleus);

print(nucleus.isActivated); // true
print(nucleus.cell);        // Returns the live cell
```

---

## Cloning a Nucleus

### Why Clone?

- Create independent copies
- Avoid sharing state between cells
- Create variations of a blueprint

### Using clone

```dart
final original = Nucleus(
  receptor: Receptor((cell, pulse, {user}) {
    print('Original processing');
    return pulse;
  }),
  context: Context.system,
);

final clone = original.clone;

// Original and clone are independent
final cell1 = Cell.fromNucleus(original);
final cell2 = Cell.fromNucleus(clone);
```

### Clone vs Evolve

| Feature | clone | evolve |
|---------|-------|--------|
| Purpose | Create independent copy | Inherit with overrides |
| Inheritance | No principal | Has principal |
| Sharing | Independent | Shares defaults |
| When to use | Duplicating behavior | Specializing behavior |

---

## Nucleus with ValueCell

### ValueNucleus

`ValueNucleus` is a specialized nucleus for state cells:

```dart
final valueNucleus = ValueNucleus<int>(
  transform: (host, input, {user}) {
    final delta = input.payload as int? ?? 1;
    return Pulse(host.value + delta);
  },
  context: Context.module('counter'),
  testRule: TestCell((value, {host, ...}) => value >= 0),
);

final handle = ValueCell.create(valueNucleus, value: 0);
// Creates a ValueCell with the blueprint
```

### ValueNucleus with Instruction

```dart
final instruction = Instruction<Cell, Pulse, Pulse>(
  (pulse, {cell, user}) => Pulse((pulse.payload as int) * 2),
);

final valueNucleus = ValueNucleus<int>.from(
  instruction: instruction,
  context: Context.module('doubler'),
);

final handle = ValueCell.create(valueNucleus, value: 1);
```

### ValueNucleus Evolution

```dart
final parent = ValueNucleus<int>(
  transform: (host, input, {user}) => Pulse(host.value + 1),
  context: Context.system,
);

final child = ValueNucleus<int>.evolve(
  principal: parent,
  testRule: TestCell((value, {host, ...}) => value > 0),
);
// child inherits transform from parent, but adds validation
```

---

## Testing Nucleus

### Unit Testing a Nucleus

```dart
import 'package:test/test.dart';

void main() {
  test('Nucleus creates correctly', () {
    final nucleus = Nucleus(
      receptor: Receptor.passThrough,
      testRule: TestCell.allowAll,
      context: Context.system,
    );
    
    expect(nucleus.receptor, Receptor.passThrough);
    expect(nucleus.testRule, TestCell.allowAll);
    expect(nucleus.context, Context.system);
  });
  
  test('Nucleus inherits properties', () {
    final parent = Nucleus(
      context: Context.module('parent'),
      receptor: Receptor.passThrough,
    );
    
    final child = Nucleus.evolve(
      principal: parent,
      testRule: myRule,
    );
    
    expect(child.context, Context.module('parent'));
    expect(child.receptor, Receptor.passThrough);
    expect(child.testRule, myRule);
  });
}
```

### Testing Activation

```dart
test('Nucleus activates correctly', () {
  final nucleus = Nucleus(...);
  final cell = MockCell();
  
  final activated = nucleus.activate(cell);
  expect(activated, true);
  expect(nucleus.isActivated, true);
  expect(nucleus.cell, cell);
});
```

### Testing with Mock Cell

```dart
class MockCell extends CellBase {
  MockCell() : super();
}

test('Nucleus works with mock cell', () {
  final nucleus = Nucleus(
    receptor: Receptor((cell, pulse, {user}) {
      return Pulse('processed: ${pulse.payload}');
    }),
  );
  
  final cell = MockCell();
  nucleus.activate(cell);
  
  final result = nucleus.receptor.call(Pulse('test'));
  expect(result.payload, 'processed: test');
});
```

---

## Best Practices

### 1. Use Factories for Creation

```dart
// ✅ GOOD - Factory function
Nucleus createAuthNucleus() {
  return Nucleus(
    context: Context.module('auth'),
    testRule: authRule,
    receptor: authReceptor,
  );
}

// ❌ BAD - Inline creation everywhere
final nucleus1 = Nucleus(...);  // Duplicated
final nucleus2 = Nucleus(...);  // Duplicated
```

### 2. Share Nuclei When Possible

```dart
// ✅ GOOD - Shared nucleus
final sharedNucleus = Nucleus(...);
final cell1 = Cell.fromNucleus(sharedNucleus);
final cell2 = Cell.fromNucleus(sharedNucleus);

// ❌ BAD - Separate nuclei for same behavior
final nucleus1 = Nucleus(...);
final nucleus2 = Nucleus(...);
```

### 3. Use evolve for Specialization

```dart
// ✅ GOOD - Inherit and specialize
final base = Nucleus(...);
final specialized = Nucleus.evolve(
  principal: base,
  testRule: stricterRule,
);

// ❌ BAD - Recreate from scratch
final specialized = Nucleus(
  // Same as base, with one change
  context: base.context,
  receptor: base.receptor,
  testRule: stricterRule,
);
```

### 4. Use clone for Independence

```dart
// ✅ GOOD - Clone for independent use
final clone = original.clone;
final cell = Cell.fromNucleus(clone);

// ❌ BAD - Share activated nucleus
final cell = Cell.fromNucleus(original);  // original is now activated
final cell2 = Cell.fromNucleus(original); // Will clone automatically
```

### 5. Document Your Blueprints

```dart
/// Authentication nucleus for user sessions.
///
/// Features:
/// - Validates session tokens
/// - Enforces role-based access
/// - Auto-expires after 30 minutes
Nucleus createAuthNucleus() {
  return Nucleus(
    ephemeralPolicy: EphemeralPolicy(
      duration: Duration(minutes: 30),
      onEvent: (object, {required cell, policy, arguments, user}) {
        // Reset expiration on activity
        return (events: 0);
      },
      onInvalidate: (nucleus) {
        // Cleanup session
        return true;
      },
    ),
    // ...
  );
}
```

---

## Complete Example

Here's a complete example showing a multi-tenant application using Nucleus:

```dart
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// 1. Define Tenant-Specific Behavior
// ─────────────────────────────────────────────────────────────────────────

class TenantContext {
  final String tenantId;
  final String domain;
  final List<String> features;

  TenantContext({
    required this.tenantId,
    required this.domain,
    this.features = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────
// 2. Base Nucleus
// ─────────────────────────────────────────────────────────────────────────

final baseNucleus = Nucleus(
  context: Context.module('multi-tenant'),
  receptor: Receptor((cell, pulse, {user}) {
    print('Processing in base nucleus');
    return pulse;
  }),
  testRule: TestCell((value, {host, ...}) => value != null),
);

// ─────────────────────────────────────────────────────────────────────────
// 3. Tenant-Specific Nuclei
// ─────────────────────────────────────────────────────────────────────────

Nucleus createTenantNucleus(TenantContext tenant) {
  return Nucleus.evolve(
    principal: baseNucleus,
    context: Context.module(tenant.domain),
    testRule: TestCell((value, {host, arguments, user}) {
      // Tenant-specific validation
      if (value is Map) {
        return value['tenantId'] == tenant.tenantId;
      }
      return true;
    }),
    user: tenant,  // Store tenant context
  );
}

// ─────────────────────────────────────────────────────────────────────────
// 4. Feature-Specific Nuclei
// ─────────────────────────────────────────────────────────────────────────

Nucleus createFeatureNucleus(TenantContext tenant, String feature) {
  final base = createTenantNucleus(tenant);
  
  return Nucleus.evolve(
    principal: base,
    receptor: Receptor((cell, pulse, {user}) {
      if (tenant.features.contains(feature)) {
        print('Feature $feature enabled for tenant ${tenant.tenantId}');
        return pulse;
      }
      print('Feature $feature disabled for tenant ${tenant.tenantId}');
      return null;
    }),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// 5. Usage
// ─────────────────────────────────────────────────────────────────────────

void main() {
  // Define tenants
  final tenantA = TenantContext(
    tenantId: 'tenant-a',
    domain: 'finance',
    features: ['reporting', 'analytics'],
  );
  
  final tenantB = TenantContext(
    tenantId: 'tenant-b',
    domain: 'hr',
    features: ['employee-management'],
  );

  // Create tenant-specific nuclei
  final nucleusA = createTenantNucleus(tenantA);
  final nucleusB = createTenantNucleus(tenantB);

  // Create cells from nuclei
  final cellA = Cell.fromNucleus(nucleusA);
  final cellB = Cell.fromNucleus(nucleusB);

  // Create feature-specific cells
  final reportingNucleus = createFeatureNucleus(tenantA, 'reporting');
  final reportingCell = Cell.fromNucleus(reportingNucleus);

  // Test
  print('Tenant A cell: ${cellA.context.domains}');
  print('Tenant B cell: ${cellB.context.domains}');
  print('Reporting cell: ${reportingCell.context.domains}');

  // All cells share the base behavior but with tenant-specific overrides
}
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **Nucleus** | Immutable blueprint for a cell |
| **Flyweight** | Shared across many cells |
| **Inheritance** | Prototype-based via `principal` |
| **Clone** | Create independent copy |
| **Activation** | Bind to a live cell |
| **ValueNucleus** | Specialized for state cells |

### Key Rules

1. **Nucleus is immutable** - Create new ones, don't modify
2. **Share when possible** - Flyweight pattern saves memory
3. **Use evolve for specialization** - Inherit and override
4. **Use clone for independence** - Create separate copies
5. **Activate once** - Activated nuclei can't be re-activated
6. **Document your blueprints** - Explain what each does

### Common Patterns

```dart
// Pattern: Base + specialization
final base = Nucleus(...);
final specialized = Nucleus.evolve(principal: base, ...);

// Pattern: Shared blueprint
final shared = Nucleus(...);
final cell1 = Cell.fromNucleus(shared);
final cell2 = Cell.fromNucleus(shared);

// Pattern: Clone for independence
final clone = original.clone;
final cell = Cell.fromNucleus(clone);

// Pattern: Factory function
Nucleus createMyNucleus() => Nucleus(...);
```