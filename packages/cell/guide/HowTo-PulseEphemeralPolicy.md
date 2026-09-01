# How to Use PulseEphemeralPolicy in the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What is PulseEphemeralPolicy?](#what-is-pulseephemeralpolicy)
3. [Core Concepts](#core-concepts)
4. [Creating a PulseEphemeralPolicy](#creating-a-pulseephemeralpolicy)
5. [Time-Based Policies](#time-based-policies)
6. [Hop-Based Policies](#hop-based-policies)
7. [Combined Policies](#combined-policies)
8. [Using with Pulses](#using-with-pulses)
9. [Testing PulseEphemeralPolicy](#testing-pulseephemeralpolicy)
10. [Best Practices](#best-practices)
11. [Complete Example](#complete-example)

---

## Introduction

**PulseEphemeralPolicy** is the lifecycle management system for individual pulses. It prevents "zombie signals" and infinite propagation loops by establishing hard boundaries for both temporal duration (TTL) and topological distance (Hops). Unlike `EphemeralPolicy` which manages cell lifecycles, `PulseEphemeralPolicy` governs the lifespan of individual signals as they traverse the reactive graph.

### When to Use PulseEphemeralPolicy

| Scenario | Recommended Approach |
|----------|---------------------|
| Authentication tokens | TTL-based policy |
| Broadcast messages | Hop-limit policy |
| Circuit breakers | Combined TTL + hop policy |
| One-time commands | TTL with short duration |
| Distributed propagation | Hop-limit with callbacks |
| Audit trails | Combined policy with logging |

---

## What is PulseEphemeralPolicy?

`PulseEphemeralPolicy` defines the **lifecycle constraints** and **termination logic** for a pulse as it traverses the reactive graph. It prevents signals from propagating forever and ensures timely cleanup of transient messages.

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Signal-Level** | Applies to individual pulses, not cells |
| **TTL Support** | Time-based expiration |
| **Hop Limit** | Distance-based expiration |
| **Lazy Timer** | TTL starts on first interaction, not creation |
| **Callback-based** | Custom logic on invalidation |
| **Hop Tracking** | Counts traversals through cells |

### When to Use PulseEphemeralPolicy vs EphemeralPolicy

| Aspect | PulseEphemeralPolicy | EphemeralPolicy |
|--------|---------------------|-----------------|
| **Scope** | Individual pulse | Entire cell |
| **Granularity** | Fine (per signal) | Coarse (per node) |
| **Duration** | Seconds, milliseconds | Minutes, hours |
| **Hop Tracking** | Yes | No |
| **Use Case** | Tokens, broadcasts | Caching, sessions |

---

## Core Concepts

### 1. TTL (Time-To-Live)

The maximum time a pulse can exist before expiration:

```dart
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 30),
  onEvent: (cell, {required policy}) {
    // Reset hop counter on each event
    return (hops: 0);
  },
  onInvalidate: (pulse) {
    print('Pulse expired after 30 seconds');
    return true;
  },
);
```

### 2. Hop Limit

The maximum number of cells a pulse can traverse:

```dart
final policy = PulseEphemeralPolicy(
  hopLimit: 5,
  onEvent: (cell, {required policy}) {
    // Increment hop counter
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('Pulse exceeded hop limit (5)');
    return true;
  },
);
```

### 3. Combined Constraints

Both TTL and hop limit can be used together:

```dart
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 10),
  hopLimit: 3,
  onEvent: (cell, {required policy}) {
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('Pulse expired (10s or 3 hops)');
    return true;
  },
);
```

### 4. Lazy Timer

The TTL timer starts on the **first interaction**, not at creation:

```dart
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 10),
  onEvent: (cell, {required policy}) {
    print('First interaction - timer starts now');
    return (hops: 0);
  },
  onInvalidate: (pulse) => true,
);

// Timer starts when pulse first reaches a cell
receptor.call(pulse);  // Timer starts NOW
// Pulse expires 10 seconds after this interaction
```

### 5. Hop Tracking

The hop counter tracks how many cells the pulse has traversed:

```dart
final policy = PulseEphemeralPolicy(
  hopLimit: 3,
  onEvent: (cell, {required policy}) {
    print('Hop ${policy.hops + 1}: traversing ${cell.runtimeType}');
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) => true,
);
```

---

## Creating a PulseEphemeralPolicy

### Method 1: TTL Only

```dart
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 10),
  onEvent: (cell, {required policy}) {
    // Reset hop counter on each event
    return (hops: 0);
  },
  onInvalidate: (pulse) {
    print('Pulse expired after 10 seconds');
    return true;
  },
);
```

### Method 2: Hop Limit Only

```dart
final policy = PulseEphemeralPolicy(
  hopLimit: 5,
  onEvent: (cell, {required policy}) {
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('Pulse exceeded hop limit');
    return true;
  },
);
```

### Method 3: Combined Policy

```dart
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 30),
  hopLimit: 3,
  onEvent: (cell, {required policy}) {
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('Pulse expired (30s or 3 hops)');
    return true;
  },
);
```

### Method 4: With User Data

```dart
final policy = PulseEphemeralPolicy(
  hopLimit: 3,
  user: {'source': 'auth_service', 'priority': 'high'},
  onEvent: (cell, {required policy}) {
    final user = policy._user as Map<String, dynamic>;
    print('Processing from ${user['source']}');
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('Pulse expired');
    return true;
  },
);
```

### Method 5: With Custom Hop Logic

```dart
final policy = PulseEphemeralPolicy(
  hopLimit: 5,
  onEvent: (cell, {required policy}) {
    // Only count certain cell types
    if (cell is ProcessingCell) {
      return (hops: policy.hops + 1);
    }
    // Skip counting for other cell types
    return (hops: policy.hops);
  },
  onInvalidate: (pulse) => true,
);
```

---

## Time-Based Policies

### Short-Lived Token

```dart
final tokenPolicy = PulseEphemeralPolicy(
  duration: Duration(seconds: 5),
  onEvent: (cell, {required policy}) {
    print('Token validation at ${cell.runtimeType}');
    return (hops: 0);
  },
  onInvalidate: (pulse) {
    print('🔑 Token expired after 5 seconds');
    return true;
  },
);

final tokenPulse = Pulse.governed<String>(
  payload: 'auth_token_123',
  policy: tokenPolicy,
);
```

### Session Timeout

```dart
final sessionPolicy = PulseEphemeralPolicy(
  duration: Duration(minutes: 5),
  onEvent: (cell, {required policy}) {
    print('Session activity at ${cell.runtimeType}');
    return (hops: 0);
  },
  onInvalidate: (pulse) {
    print('🔒 Session expired after 5 minutes');
    return true;
  },
);
```

### Command Timeout

```dart
final commandPolicy = PulseEphemeralPolicy(
  duration: Duration(seconds: 2),
  onEvent: (cell, {required policy}) {
    return (hops: 0);
  },
  onInvalidate: (pulse) {
    print('⏰ Command timed out');
    return true;
  },
);
```

---

## Hop-Based Policies

### Broadcast Limit

```dart
final broadcastPolicy = PulseEphemeralPolicy(
  hopLimit: 3,
  onEvent: (cell, {required policy}) {
    print('📡 Broadcast hop ${policy.hops + 1}/3 at ${cell.runtimeType}');
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('📡 Broadcast stopped after 3 hops');
    return true;
  },
);
```

### Pipeline Depth Limit

```dart
final pipelinePolicy = PulseEphemeralPolicy(
  hopLimit: 10,
  onEvent: (cell, {required policy}) {
    print('Pipeline depth: ${policy.hops + 1}/10');
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('⚠️ Pipeline depth exceeded (10)');
    return true;
  },
);
```

### Recursive Guard

```dart
final recursivePolicy = PulseEphemeralPolicy(
  hopLimit: 5,
  onEvent: (cell, {required policy}) {
    print('Recursive call depth: ${policy.hops + 1}');
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('🔄 Recursion depth exceeded');
    return true;
  },
);
```

---

## Combined Policies

### Token with Hop Limit

```dart
final secureTokenPolicy = PulseEphemeralPolicy(
  duration: Duration(seconds: 10),
  hopLimit: 3,
  onEvent: (cell, {required policy}) {
    print('Token validation: ${policy.hops + 1}/3 hops');
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('🔐 Token expired (10s or 3 hops)');
    return true;
  },
);
```

### Broadcast with TTL

```dart
final broadcastWithTTL = PulseEphemeralPolicy(
  duration: Duration(seconds: 5),
  hopLimit: 5,
  onEvent: (cell, {required policy}) {
    print('Broadcast: hop ${policy.hops + 1}/5');
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('📢 Broadcast expired (5s or 5 hops)');
    return true;
  },
);
```

### Circuit Breaker

```dart
final circuitBreakerPolicy = PulseEphemeralPolicy(
  hopLimit: 2,
  duration: Duration(seconds: 1),
  onEvent: (cell, {required policy}) {
    print('Circuit breaker check: ${policy.hops + 1}');
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('🔌 Circuit breaker tripped');
    return true;
  },
);
```

---

## Using with Pulses

### Basic Usage with Governed Pulse

```dart
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 10),
  onEvent: (cell, {required policy}) => (hops: 0),
  onInvalidate: (pulse) => true,
);

final pulse = Pulse.governed<String>(
  payload: 'Hello',
  policy: policy,
);
```

### With Context

```dart
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 30),
  hopLimit: 5,
  onEvent: (cell, {required policy}) => (hops: policy.hops + 1),
  onInvalidate: (pulse) => true,
);

final pulse = Pulse.governed<String>(
  payload: 'Sensitive Data',
  policy: policy,
  context: PulseContext(
    actor: 'admin_001',
    reason: 'Accessing user data',
    sensitivity: Sensitivity.confidential,
  ),
);
```

### With Callbacks

```dart
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 10),
  onEvent: (cell, {required policy}) {
    print('📊 Processing at: ${cell.runtimeType}');
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('✅ Pulse completed');
    return true;
  },
);

final pulse = Pulse.governed<String>(
  payload: 'Complete Task',
  policy: policy,
  onComplete: (pulse) {
    print('🎉 Task complete!');
  },
  onError: (pulse, error, {stackTrace}) {
    print('❌ Task failed: $error');
  },
);
```

### In a Receptor

```dart
final receptor = Receptor((cell, pulse, {user}) {
  // The framework automatically checks invalidation
  if (pulse.isInvalidated) {
    print('Skipping invalidated pulse');
    return null;
  }
  
  // Process the pulse
  print('Processing: ${pulse.payload}');
  return pulse;
});
```

### In a Pipeline

```dart
final pipeline = Instruction<Cell, Pulse, Pulse>(
  (pulse, {cell, user}) {
    // Check invalidation at each step
    if (pulse.isInvalidated) {
      print('Pulse invalidated, stopping pipeline');
      return null;
    }
    
    // Process...
    return pulse;
  },
);
```

---

## Testing PulseEphemeralPolicy

### Testing TTL

```dart
import 'package:test/test.dart';

test('Pulse expires after TTL', () async {
  var invalidated = false;
  
  final policy = PulseEphemeralPolicy(
    duration: Duration(milliseconds: 100),
    onEvent: (cell, {required policy}) => (hops: 0),
    onInvalidate: (pulse) {
      invalidated = true;
      return true;
    },
  );
  
  final pulse = Pulse.governed<String>(
    payload: 'test',
    policy: policy,
  );
  
  // First interaction starts timer
  final receptor = Receptor((cell, pulse, {user}) => pulse);
  receptor.call(pulse);
  
  expect(invalidated, false);
  
  await Future.delayed(Duration(milliseconds: 150));
  
  // Pulse should be invalidated
  expect(invalidated, true);
  expect(pulse.isInvalidated, true);
});
```

### Testing Hop Limit

```dart
test('Pulse expires after hop limit', () {
  var invalidated = false;
  var hops = 0;
  
  final policy = PulseEphemeralPolicy(
    hopLimit: 3,
    onEvent: (cell, {required policy}) {
      hops = policy.hops + 1;
      return (hops: hops);
    },
    onInvalidate: (pulse) {
      invalidated = true;
      return true;
    },
  );
  
  final pulse = Pulse.governed<String>(
    payload: 'test',
    policy: policy,
  );
  
  final receptor = Receptor((cell, pulse, {user}) => pulse);
  
  // Send through 3 cells
  for (int i = 0; i < 3; i++) {
    receptor.call(pulse);
    expect(invalidated, false);
  }
  
  // 4th hop should invalidate
  receptor.call(pulse);
  expect(invalidated, true);
  expect(pulse.isInvalidated, true);
});
```

### Testing Combined Conditions

```dart
test('Pulse expires when either condition is met', () async {
  var invalidated = false;
  
  final policy = PulseEphemeralPolicy(
    duration: Duration(milliseconds: 100),
    hopLimit: 10,
    onEvent: (cell, {required policy}) => (hops: policy.hops + 1),
    onInvalidate: (pulse) {
      invalidated = true;
      return true;
    },
  );
  
  final pulse = Pulse.governed<String>(
    payload: 'test',
    policy: policy,
  );
  
  final receptor = Receptor((cell, pulse, {user}) => pulse);
  
  // 5 hops (not enough for hop limit)
  for (int i = 0; i < 5; i++) {
    receptor.call(pulse);
  }
  
  expect(invalidated, false);
  
  // Wait for TTL
  await Future.delayed(Duration(milliseconds: 150));
  
  expect(invalidated, true);
  expect(pulse.isInvalidated, true);
});
```

### Testing Policy State

```dart
test('Policy tracks hops correctly', () {
  final policy = PulseEphemeralPolicy(
    hopLimit: 5,
    onEvent: (cell, {required policy}) => (hops: policy.hops + 1),
    onInvalidate: (pulse) => true,
  );
  
  final pulse = Pulse.governed<String>(
    payload: 'test',
    policy: policy,
  );
  
  expect(policy.hops, -1);  // Not yet tracked
  
  final receptor = Receptor((cell, pulse, {user}) => pulse);
  receptor.call(pulse);
  expect(policy.hops, 1);
  
  receptor.call(pulse);
  expect(policy.hops, 2);
});
```

---

## Best Practices

### 1. Set Appropriate TTL

```dart
// ✅ GOOD - Reasonable TTL for tokens
duration: Duration(seconds: 30)

// ❌ BAD - Too short (unusable)
duration: Duration(milliseconds: 1)

// ❌ BAD - Too long (wastes resources)
duration: Duration(hours: 24)
```

### 2. Set Appropriate Hop Limit

```dart
// ✅ GOOD - Reasonable hop limit
hopLimit: 5

// ❌ BAD - Too short (unreachable)
hopLimit: 1

// ❌ BAD - Too long (infinite loop risk)
hopLimit: 1000
```

### 3. Track Hops for Debugging

```dart
// ✅ GOOD - Log hop progression
onEvent: (cell, {required policy}) {
  print('Hop ${policy.hops + 1}: traversing ${cell.runtimeType}');
  return (hops: policy.hops + 1);
}

// ❌ BAD - No tracking
onEvent: (cell, {required policy}) => (hops: 0)
```

### 4. Clean Up Resources

```dart
// ✅ GOOD - Clean up on invalidation
onInvalidate: (pulse) {
  // Close connections, clear caches
  connection.close();
  return true;
}

// ❌ BAD - No cleanup
onInvalidate: (pulse) => true
```

### 5. Use Combined Policies for Security

```dart
// ✅ GOOD - TTL + hop limit
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 10),
  hopLimit: 3,
  onEvent: (cell, {required policy}) => (hops: policy.hops + 1),
  onInvalidate: (pulse) => true,
);

// ❌ BAD - Only one constraint
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 10),
  onEvent: (cell, {required policy}) => (hops: 0),
  onInvalidate: (pulse) => true,
);
```

### 6. Check Invalidation State

```dart
// ✅ GOOD - Check before processing
if (pulse.isInvalidated) {
  print('Pulse is invalid');
  return null;
}
process(pulse);

// ❌ BAD - No check
process(pulse);  // May process stale data
```

---

## Complete Example

Here's a complete distributed command processing system:

```dart
import 'dart:async';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// 1. Command Types
// ─────────────────────────────────────────────────────────────────────────

class Command {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  Command({
    required this.id,
    required this.type,
    this.data = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  String toString() => 'Command($type: $id)';
}

// ─────────────────────────────────────────────────────────────────────────
// 2. Create Command with Policy
// ─────────────────────────────────────────────────────────────────────────

Pulse<Command> createCommand(Command cmd, {Duration? ttl, int? hopLimit}) {
  final policy = PulseEphemeralPolicy(
    duration: ttl ?? Duration(seconds: 5),
    hopLimit: hopLimit ?? 3,
    onEvent: (cell, {required policy}) {
      print('📡 ${cmd.id}: hop ${policy.hops + 1} at ${cell.runtimeType}');
      return (hops: policy.hops + 1);
    },
    onInvalidate: (pulse) {
      print('⏰ ${cmd.id}: expired');
      return true;
    },
  );

  return Pulse.governed<Command>(
    payload: cmd,
    policy: policy,
    onComplete: (pulse) {
      print('✅ ${cmd.id}: completed');
    },
    onError: (pulse, error, {stackTrace}) {
      print('❌ ${cmd.id}: failed: $error');
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────
// 3. Command Processors (Cells)
// ─────────────────────────────────────────────────────────────────────────

// Validator - checks command validity
final validator = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    final cmd = pulse.payload as Command;
    if (cmd.data.isEmpty) {
      print('⚠️ ${cmd.id}: validation failed');
      return null;  // Stops propagation
    }
    print('✅ ${cmd.id}: validated');
    return pulse;
  }),
);

// Processor - processes the command
final processor = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    final cmd = pulse.payload as Command;
    print('⚙️ ${cmd.id}: processing ${cmd.type}');
    // Simulate processing
    return pulse;
  }),
);

// Logger - logs the result
final logger = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    final cmd = pulse.payload as Command;
    print('📝 ${cmd.id}: logged');
    return pulse;
  }),
);

// Notifier - sends notification
final notifier = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    final cmd = pulse.payload as Command;
    print('🔔 ${cmd.id}: notification sent');
    return pulse;
  }),
);

// ─────────────────────────────────────────────────────────────────────────
// 4. Build Pipeline
// ─────────────────────────────────────────────────────────────────────────

final pipelineCell = Cell(
  synapses: Synapses(
    downstreams: [validator, processor, logger, notifier],
  ),
  receptor: Receptor.passThrough,
);

// ─────────────────────────────────────────────────────────────────────────
// 5. Command Dispatcher
// ─────────────────────────────────────────────────────────────────────────

void dispatchCommand(Command cmd) {
  final pulse = createCommand(cmd);
  pipelineCell._nucleus.receptor.call(pulse);
}

// ─────────────────────────────────────────────────────────────────────────
// 6. Main Demo
// ─────────────────────────────────────────────────────────────────────────

void main() async {
  print('═══ Command Processing with PulseEphemeralPolicy ═══\n');

  // Valid command
  print('1. Dispatching valid command:');
  dispatchCommand(Command(
    id: 'CMD-001',
    type: 'update_user',
    data: {'userId': 123, 'name': 'Alice'},
  ));

  // Invalid command (empty data)
  print('\n2. Dispatching invalid command:');
  dispatchCommand(Command(
    id: 'CMD-002',
    type: 'invalid',
    data: {},
  ));

  // Command that will expire (long processing)
  print('\n3. Dispatching command with short TTL:');
  final shortLived = createCommand(
    Command(id: 'CMD-003', type: 'slow_operation'),
    ttl: Duration(milliseconds: 50),
    hopLimit: 1,
  );
  pipelineCell._nucleus.receptor.call(shortLived);

  // Wait for expiration
  await Future.delayed(Duration(milliseconds: 100));

  print('\n═══ Done ═══');
}
```

**Expected Output:**
```
═══ Command Processing with PulseEphemeralPolicy ═══

1. Dispatching valid command:
📡 CMD-001: hop 1 at _Cell
✅ CMD-001: validated
📡 CMD-001: hop 2 at _Cell
⚙️ CMD-001: processing update_user
📡 CMD-001: hop 3 at _Cell
📝 CMD-001: logged
✅ CMD-001: completed

2. Dispatching invalid command:
📡 CMD-002: hop 1 at _Cell
⚠️ CMD-002: validation failed
✅ CMD-002: completed

3. Dispatching command with short TTL:
📡 CMD-003: hop 1 at _Cell
⏰ CMD-003: expired

═══ Done ═══
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **PulseEphemeralPolicy** | Pulse lifecycle management |
| **Duration** | Time-To-Live (TTL) |
| **Hop Limit** | Maximum traversals |
| **onEvent** | Called on each hop |
| **onInvalidate** | Called when pulse expires |
| **Hops** | Current traversal count |
| **isInvalidated** | Check if pulse is expired |

### Key Rules

1. **Timer is lazy** - Starts on first interaction, not creation
2. **Hop limit counts traversals** - Through each cell
3. **Combined conditions** - TTL and hop limit can be used together
4. **Check invalidation** - Always check `pulse.isInvalidated`
5. **Clean up resources** - Use onInvalidate for cleanup
6. **Track hops for debugging** - Log progression

### Common Patterns

```dart
// Pattern: TTL only
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 5),
  onEvent: (cell, {required policy}) => (hops: 0),
  onInvalidate: (pulse) => true,
);

// Pattern: Hop limit only
final policy = PulseEphemeralPolicy(
  hopLimit: 3,
  onEvent: (cell, {required policy}) => (hops: policy.hops + 1),
  onInvalidate: (pulse) => true,
);

// Pattern: Combined TTL + hop limit
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 5),
  hopLimit: 3,
  onEvent: (cell, {required policy}) => (hops: policy.hops + 1),
  onInvalidate: (pulse) => true,
);

// Pattern: Token with TTL
final tokenPolicy = PulseEphemeralPolicy(
  duration: Duration(seconds: 10),
  onEvent: (cell, {required policy}) => (hops: 0),
  onInvalidate: (pulse) {
    print('Token expired');
    return true;
  },
);
```
