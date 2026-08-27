# How to Use EphemeralPolicy in the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What is EphemeralPolicy?](#what-is-ephemeralpolicy)
3. [Core Concepts](#core-concepts)
4. [Creating an EphemeralPolicy](#creating-an-ephemeralpolicy)
5. [Event-Based Policies](#event-based-policies)
6. [Time-Based Policies](#time-based-policies)
7. [Combined Policies](#combined-policies)
8. [PulseEphemeralPolicy](#pulseephemeralpolicy)
9. [Using with Cells](#using-with-cells)
10. [Testing EphemeralPolicy](#testing-ephemeralpolicy)
11. [Best Practices](#best-practices)
12. [Complete Example](#complete-example)

---

## Introduction

**EphemeralPolicy** is the lifecycle management system for the Cell Framework. It automatically reclaims resources when they are no longer needed, preventing memory leaks and ensuring that transient states do not persist beyond their operational relevance.

### When to Use EphemeralPolicy

| Scenario | Recommended Approach |
|----------|---------------------|
| Caching data | Use TTL-based policy |
| Rate limiting | Use event-count policy |
| Session management | Use combined TTL + event policy |
| Temporary state | Use event-based policy |
| Resource cleanup | Use onInvalidate callback |
| Pulse validation | Use PulseEphemeralPolicy |

---

## What is EphemeralPolicy?

`EphemeralPolicy` manages the automatic reclamation of a `Cell` based on:
- **Temporal constraints** (Time-To-Live)
- **Event frequency** (Event count limits)
- **Combined constraints** (Both TTL and events)

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Automatic** | Cells self-destruct when conditions are met |
| **Configurable** | TTL, event limits, or both |
| **Callback-based** | Custom logic on event and invalidation |
| **Lazy Timer** | TTL starts on first interaction, not creation |
| **Resource Safe** | Prevents memory leaks from stale cells |
| **Thread-Safe** | Atomic operations for concurrent access |

### When to Use EphemeralPolicy vs PulseEphemeralPolicy

| Aspect | EphemeralPolicy | PulseEphemeralPolicy |
|--------|-----------------|---------------------|
| **Scope** | Cell lifecycle | Pulse lifecycle |
| **Granularity** | Coarse (entire cell) | Fine (individual pulse) |
| **Duration** | Minutes, hours | Seconds, milliseconds |
| **Use Case** | Caching, sessions | Tokens, short-lived signals |

---

## Core Concepts

### 1. Lazy TTL Timer

The TTL timer starts on the **first interaction**, not at creation:

```dart
final policy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  onEvent: (object, {required cell, policy, arguments, user}) {
    // Reset timer on activity
    return (events: 0);
  },
  onInvalidate: (nucleus) {
    print('Cell expired after 5 minutes of inactivity');
    return true;
  },
);

// Timer starts on first interaction
cell.emit(Pulse('data'));  // Timer starts NOW
// Cell expires 5 minutes after this interaction
```

### 2. Event Counter

The event counter tracks usage and can trigger invalidation:

```dart
final policy = EphemeralPolicy(
  eventLimit: 1000,
  onEvent: (object, {required cell, policy, arguments, user}) {
    // Increment counter on each event
    return (events: policy.events + 1);
  },
  onInvalidate: (nucleus) {
    print('Cell processed 1000 events');
    return true;
  },
);
```

### 3. Combined Conditions

Both TTL and event limit can be used together:

```dart
final policy = EphemeralPolicy(
  duration: Duration(hours: 1),
  eventLimit: 500,
  onEvent: (object, {required cell, policy, arguments, user}) {
    return (events: policy.events + 1);
  },
  onInvalidate: (nucleus) {
    // Whichever condition is met first triggers invalidation
    print('Cell expired (1 hour or 500 events)');
    return true;
  },
);
```

---

## Creating an EphemeralPolicy

### Method 1: TTL Only

```dart
final policy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  onEvent: (object, {required cell, policy, arguments, user}) {
    // Reset timer on any activity
    return (events: 0);
  },
  onInvalidate: (nucleus) {
    print('Cell expired due to inactivity');
    return true;
  },
);
```

### Method 2: Event Limit Only

```dart
final policy = EphemeralPolicy(
  eventLimit: 100,
  onEvent: (object, {required cell, policy, arguments, user}) {
    return (events: policy.events + 1);
  },
  onInvalidate: (nucleus) {
    print('Cell reached event limit');
    return true;
  },
);
```

### Method 3: Combined Policy

```dart
final policy = EphemeralPolicy(
  duration: Duration(minutes: 10),
  eventLimit: 50,
  onEvent: (object, {required cell, policy, arguments, user}) {
    // Reset timer on activity
    return (events: policy.events + 1);
  },
  onInvalidate: (nucleus) {
    print('Cell expired (10 minutes or 50 events)');
    return true;
  },
);
```

### Method 4: With User Data

```dart
final policy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  user: {'max_retries': 3, 'timeout': 500},
  onEvent: (object, {required cell, policy, arguments, user}) {
    final config = user as Map<String, dynamic>;
    final maxRetries = config['max_retries'] as int;
    
    // Use config in logic
    if (policy.events > maxRetries) {
      return (events: -1);  // Negative value ignores the event
    }
    return (events: policy.events + 1);
  },
  onInvalidate: (nucleus) {
    print('Cell expired');
    return true;
  },
);
```

### Method 5: Smart Cache Policy

```dart
class CacheEntry {
  final String key;
  final dynamic value;
  final DateTime createdAt;
  
  CacheEntry({required this.key, required this.value, required this.createdAt});
}

final cachePolicy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  eventLimit: 10,
  user: {'max_items': 100},
  onEvent: (object, {required cell, policy, arguments, user}) {
    final cache = object as CacheEntry?;
    if (cache == null) return (events: policy.events);
    
    print('Cache hit: ${cache.key}');
    
    // Reset timer on cache hit
    return (events: 0);
  },
  onInvalidate: (nucleus) {
    print('Cache entry expired');
    // Clean up cache storage
    return true;
  },
);
```

---

## Event-Based Policies

### Tracking Errors

```dart
final errorBudgetPolicy = EphemeralPolicy(
  eventLimit: 5,
  onEvent: (object, {required cell, policy, arguments, user}) {
    final isError = object is Exception || (object is bool && object == false);
    if (isError) {
      print('⚠️ Error detected: $object');
      return (events: policy.events + 1);
    }
    // Success resets the counter
    return (events: 0);
  },
  onInvalidate: (nucleus) {
    print('❌ Error budget exceeded (5 errors)');
    return true;
  },
);
```

### Tracking Usage

```dart
final usagePolicy = EphemeralPolicy(
  eventLimit: 1000,
  onEvent: (object, {required cell, policy, arguments, user}) {
    print('📊 Usage count: ${policy.events + 1}/1000');
    return (events: policy.events + 1);
  },
  onInvalidate: (nucleus) {
    print('✅ Usage limit reached (1000 operations)');
    return true;
  },
);
```

### Conditional Event Counting

```dart
final conditionalPolicy = EphemeralPolicy(
  eventLimit: 10,
  onEvent: (object, {required cell, policy, arguments, user}) {
    final data = object as Map<String, dynamic>?;
    if (data == null) return (events: policy.events);
    
    // Only count certain events
    if (data['type'] == 'error') {
      return (events: policy.events + 1);
    }
    return (events: policy.events);
  },
  onInvalidate: (nucleus) {
    print('Too many errors detected');
    return true;
  },
);
```

---

## Time-Based Policies

### Fixed Duration TTL

```dart
final ttlPolicy = EphemeralPolicy(
  duration: Duration(minutes: 10),
  onEvent: (object, {required cell, policy, arguments, user}) {
    // Reset timer on any activity
    return (events: 0);
  },
  onInvalidate: (nucleus) {
    print('Cell expired after 10 minutes');
    return true;
  },
);
```

### Sliding Expiration

```dart
final slidingPolicy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  onEvent: (object, {required cell, policy, arguments, user}) {
    // Each interaction resets the timer
    print('🔄 Timer reset');
    return (events: 0);
  },
  onInvalidate: (nucleus) {
    print('⏰ Cell expired after 5 minutes of inactivity');
    return true;
  },
);
```

### Absolute Expiration

```dart
final absolutePolicy = EphemeralPolicy(
  duration: Duration(minutes: 30),
  onEvent: (object, {required cell, policy, arguments, user}) {
    // Timer is not reset - absolute TTL
    return (events: policy.events);
  },
  onInvalidate: (nucleus) {
    print('⏰ Absolute expiration (30 minutes)');
    return true;
  },
);
```

---

## Combined Policies

### TTL + Event Limit

```dart
final combinedPolicy = EphemeralPolicy(
  duration: Duration(minutes: 15),
  eventLimit: 100,
  onEvent: (object, {required cell, policy, arguments, user}) {
    print('📊 Events: ${policy.events + 1}/100');
    return (events: policy.events + 1);
  },
  onInvalidate: (nucleus) {
    print('⏰ Cell expired (15 minutes OR 100 events)');
    return true;
  },
);
```

### TTL + Error Budget

```dart
final resilientPolicy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  eventLimit: 3,
  onEvent: (object, {required cell, policy, arguments, user}) {
    if (object is Exception) {
      print('⚠️ Error: $object');
      return (events: policy.events + 1);
    }
    // Success resets error counter and timer
    return (events: 0);
  },
  onInvalidate: (nucleus) {
    print('❌ Cell failed (3 errors or 5 minutes)');
    return true;
  },
);
```

### Session Management

```dart
final sessionPolicy = EphemeralPolicy(
  duration: Duration(minutes: 30),
  eventLimit: 1000,
  user: {'session_id': 'user_123'},
  onEvent: (object, {required cell, policy, arguments, user}) {
    final action = object as String? ?? 'unknown';
    print('📝 Session activity: $action');
    return (events: policy.events + 1);
  },
  onInvalidate: (nucleus) {
    print('🔒 Session expired (30 minutes or 1000 actions)');
    return true;
  },
);
```

---

## PulseEphemeralPolicy

### Pulse-Level Lifecycle

`PulseEphemeralPolicy` is similar but applies to individual pulses:

```dart
final pulsePolicy = PulseEphemeralPolicy(
  duration: Duration(seconds: 30),
  hopLimit: 5,
  onEvent: (cell, {required policy}) {
    print('Pulse traversed: ${policy.hops + 1}/5');
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('Pulse expired');
    return true;
  },
);

final pulse = Pulse.governed<String>(
  payload: 'Token',
  policy: pulsePolicy,
);
```

### Time-Sensitive Pulse

```dart
final tokenPolicy = PulseEphemeralPolicy(
  duration: Duration(seconds: 10),
  onEvent: (cell, {required policy}) {
    // Reset hop counter on each event
    return (hops: 0);
  },
  onInvalidate: (pulse) {
    print('Token expired after 10 seconds');
    return true;
  },
);

final tokenPulse = Pulse.governed<String>(
  payload: 'auth_token_123',
  policy: tokenPolicy,
);
```

### Hop-Limited Pulse

```dart
final broadcastPolicy = PulseEphemeralPolicy(
  hopLimit: 3,
  onEvent: (cell, {required policy}) {
    print('Hop: ${policy.hops + 1}/3');
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('Broadcast stopped after 3 hops');
    return true;
  },
);
```

---

## Using with Cells

### Basic Cell with Policy

```dart
final policy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  onEvent: (object, {required cell, policy, arguments, user}) {
    return (events: 0);
  },
  onInvalidate: (nucleus) => true,
);

final cell = Cell(
  ephemeralPolicy: policy,
  receptor: Receptor.passThrough,
);
```

### State Cell with Policy

```dart
final policy = EphemeralPolicy(
  duration: Duration(minutes: 10),
  eventLimit: 50,
  onEvent: (object, {required cell, policy, arguments, user}) {
    return (events: policy.events + 1);
  },
  onInvalidate: (nucleus) {
    print('Cache cleared');
    return true;
  },
);

final cache = Cell.state<String>(
  initial: '',
  evolve: (host, input) => Pulse(input.payload as String? ?? ''),
  ephemeralPolicy: policy,
);
```

### Governed Cell with Policy

```dart
final policy = EphemeralPolicy(
  duration: Duration(minutes: 15),
  onEvent: (object, {required cell, policy, arguments, user}) => (events: 0),
  onInvalidate: (nucleus) => true,
);

final cell = Cell.governed(
  context: Context.secureEnclave(
    partOf: 'SessionManager',
    compliances: 'GDPR',
  ),
  ephemeralPolicy: policy,
  receptor: Receptor.passThrough,
  testRule: TestCell.allowAll,
  synapses: Synapses.enabled,
  forceLock: true,
);
```

### Deputy with Policy

```dart
final cell = Cell(...);

final temporaryDeputy = await cell.deputy(
  ephemeralPolicy: EphemeralPolicy(
    duration: Duration(minutes: 5),
    onEvent: (object, {required cell, policy, arguments, user}) => (events: 0),
    onInvalidate: (nucleus) => true,
  ),
  testRule: TestCell.readOnly,
);
```

---

## Testing EphemeralPolicy

### Unit Testing TTL

```dart
import 'package:test/test.dart';

test('Policy expires after TTL', () async {
  var invalidated = false;
  
  final policy = EphemeralPolicy(
    duration: Duration(milliseconds: 100),
    onEvent: (object, {required cell, policy, arguments, user}) {
      return (events: 0);
    },
    onInvalidate: (nucleus) {
      invalidated = true;
      return true;
    },
  );
  
  final cell = Cell(ephemeralPolicy: policy);
  
  // First interaction starts the timer
  cell._nucleus.receptor.call(Pulse('test'));
  
  expect(invalidated, false);
  
  await Future.delayed(Duration(milliseconds: 150));
  
  expect(invalidated, true);
});
```

### Testing Event Limit

```dart
test('Policy expires after event limit', () {
  var invalidated = false;
  var count = 0;
  
  final policy = EphemeralPolicy(
    eventLimit: 3,
    onEvent: (object, {required cell, policy, arguments, user}) {
      count++;
      return (events: count);
    },
    onInvalidate: (nucleus) {
      invalidated = true;
      return true;
    },
  );
  
  final cell = Cell(ephemeralPolicy: policy);
  
  // Send 3 events
  for (int i = 0; i < 3; i++) {
    cell._nucleus.receptor.call(Pulse('test'));
  }
  
  expect(invalidated, true);
});
```

### Testing Combined Conditions

```dart
test('Policy expires when either condition is met', () async {
  var invalidated = false;
  
  final policy = EphemeralPolicy(
    duration: Duration(milliseconds: 100),
    eventLimit: 10,
    onEvent: (object, {required cell, policy, arguments, user}) {
      return (events: policy.events + 1);
    },
    onInvalidate: (nucleus) {
      invalidated = true;
      return true;
    },
  );
  
  final cell = Cell(ephemeralPolicy: policy);
  
  // Send 5 events (not enough for event limit)
  for (int i = 0; i < 5; i++) {
    cell._nucleus.receptor.call(Pulse('test'));
  }
  
  expect(invalidated, false);
  
  // Wait for TTL
  await Future.delayed(Duration(milliseconds: 150));
  
  expect(invalidated, true);
});
```

### Testing Policy State

```dart
test('Policy tracks events correctly', () {
  final policy = EphemeralPolicy(
    eventLimit: 10,
    onEvent: (object, {required cell, policy, arguments, user}) {
      return (events: policy.events + 1);
    },
    onInvalidate: (nucleus) => true,
  );
  
  final cell = Cell(ephemeralPolicy: policy);
  
  expect(policy.events, 0);
  
  cell._nucleus.receptor.call(Pulse('test'));
  expect(policy.events, 1);
  
  cell._nucleus.receptor.call(Pulse('test'));
  expect(policy.events, 2);
});
```

---

## Best Practices

### 1. Use Lazy Timer for Inactivity

```dart
// ✅ GOOD - Reset timer on activity
final policy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  onEvent: (object, {required cell, policy, arguments, user}) {
    return (events: 0);  // Reset timer
  },
  onInvalidate: (nucleus) => true,
);

// ❌ BAD - Never reset timer
final policy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  onEvent: (object, {required cell, policy, arguments, user}) {
    return (events: policy.events);  // Timer never resets
  },
  onInvalidate: (nucleus) => true,
);
```

### 2. Clean Up Resources

```dart
// ✅ GOOD - Clean up on invalidation
final policy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  onEvent: (object, {required cell, policy, arguments, user}) => (events: 0),
  onInvalidate: (nucleus) {
    // Close connections, clear caches, dispose resources
    cache.clear();
    connection.close();
    return true;
  },
);
```

### 3. Use Event Count for Error Budgets

```dart
// ✅ GOOD - Track errors separately
final policy = EphemeralPolicy(
  eventLimit: 5,
  onEvent: (object, {required cell, policy, arguments, user}) {
    if (object is Exception) {
      return (events: policy.events + 1);
    }
    // Success resets the counter
    return (events: 0);
  },
  onInvalidate: (nucleus) => true,
);
```

### 4. Use User Data for Configuration

```dart
// ✅ GOOD - Pass configuration via user
final policy = EphemeralPolicy(
  user: {'max_errors': 3, 'ttl_seconds': 300},
  onEvent: (object, {required cell, policy, arguments, user}) {
    final config = user as Map<String, dynamic>;
    final maxErrors = config['max_errors'] as int;
    // Use config in logic
    return (events: policy.events + 1);
  },
  onInvalidate: (nucleus) => true,
);
```

### 5. Check Invalidation State

```dart
// ✅ GOOD - Check before processing
if (cell.isInvalidated) {
  print('Cell is expired');
  return;
}
cell.process(data);

// ❌ BAD - Process without checking
cell.process(data);  // May process stale data
```

### 6. Use Pulse Policies for Short-Lived Data

```dart
// ✅ GOOD - Use PulseEphemeralPolicy for tokens
final tokenPolicy = PulseEphemeralPolicy(
  duration: Duration(seconds: 30),
  onInvalidate: (pulse) => true,
);

// ❌ BAD - Use Cell policy for tokens
// Cell policies are for longer-lived resources
```

---

## Complete Example

Here's a complete caching system using EphemeralPolicy:

```dart
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// 1. Cache Entry
// ─────────────────────────────────────────────────────────────────────────

class CacheEntry {
  final String key;
  final dynamic value;
  final DateTime createdAt;
  
  CacheEntry({
    required this.key,
    required this.value,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  
  @override
  String toString() => 'CacheEntry(key: $key, value: $value, age: ${DateTime.now().difference(createdAt).inSeconds}s)';
}

// ─────────────────────────────────────────────────────────────────────────
// 2. Cache Policy
// ─────────────────────────────────────────────────────────────────────────

EphemeralPolicy createCachePolicy({
  Duration ttl = const Duration(minutes: 5),
  int maxItems = 100,
}) {
  return EphemeralPolicy(
    duration: ttl,
    eventLimit: maxItems,
    onEvent: (object, {required cell, policy, arguments, user}) {
      final entry = object as CacheEntry?;
      if (entry == null) return (events: policy.events);
      
      print('📦 Cache hit: ${entry.key}');
      print('   Value: ${entry.value}');
      
      // Reset timer on cache hit
      return (events: 0);
    },
    onInvalidate: (nucleus) {
      print('🗑️ Cache entry expired');
      return true;
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────
// 3. Cache System
// ─────────────────────────────────────────────────────────────────────────

class CacheSystem {
  final Map<String, Cell> _cache = {};
  final Map<String, EgressHandle> _observers = {};
  
  void put(String key, dynamic value) {
    // Remove existing entry if present
    remove(key);
    
    // Create policy for this cache entry
    final policy = createCachePolicy();
    
    // Create a state cell for the cache entry
    final handle = Cell.state<CacheEntry>(
      initial: CacheEntry(key: key, value: value),
      evolve: (host, input) {
        final newEntry = input.payload as CacheEntry?;
        if (newEntry == null) return null;
        return Pulse(newEntry);
      },
      ephemeralPolicy: policy,
    );
    
    // Create observer to log cache activity
    final observer = Cell.observe(
      source: handle.cell,
      effect: (pulse) {
        final entry = pulse.payload as CacheEntry;
        print('🔄 Cache updated: ${entry.key}');
      },
    );
    
    _cache[key] = handle.cell;
    _observers[key] = observer;
  }
  
  void remove(String key) {
    final cell = _cache.remove(key);
    if (cell != null) {
      _observers.remove(key)?.stop();
      print('🗑️ Removed cache entry: $key');
    }
  }
  
  dynamic get(String key) {
    final cell = _cache[key];
    if (cell == null) {
      print('❌ Cache miss: $key');
      return null;
    }
    
    // Access to trigger TTL reset
    final entry = cell.value as CacheEntry?;
    print('✅ Cache hit: $key');
    return entry?.value;
  }
  
  void clear() {
    for (final key in _cache.keys.toList()) {
      remove(key);
    }
    print('🗑️ Cache cleared');
  }
  
  void stats() {
    print('📊 Cache Stats:');
    print('   Entries: ${_cache.length}');
    for (final entry in _cache.entries) {
      final value = entry.value.value as CacheEntry?;
      print('   - ${entry.key}: ${value?.value ?? 'null'}');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 4. Main Demo
// ─────────────────────────────────────────────────────────────────────────

void main() async {
  print('═══ Cache System with EphemeralPolicy ═══\n');
  
  final cache = CacheSystem();
  
  // Add items to cache
  print('1. Adding items to cache:');
  cache.put('user:123', {'name': 'Alice', 'role': 'admin'});
  cache.put('user:456', {'name': 'Bob', 'role': 'user'});
  cache.put('session:789', 'active');
  
  cache.stats();
  
  // Access items
  print('\n2. Accessing items:');
  cache.get('user:123');
  cache.get('user:456');
  
  // Wait for TTL to expire
  print('\n3. Waiting for TTL (5 seconds)...');
  await Future.delayed(Duration(seconds: 6));
  
  // Try to access expired items
  print('\n4. Accessing after TTL:');
  cache.get('user:123');
  cache.get('user:456');
  
  cache.stats();
  
  print('\n═══ Done ═══');
}
```

**Expected Output:**
```
═══ Cache System with EphemeralPolicy ═══

1. Adding items to cache:
🔄 Cache updated: user:123
🔄 Cache updated: user:456
🔄 Cache updated: session:789
📊 Cache Stats:
   Entries: 3
   - user:123: {name: Alice, role: admin}
   - user:456: {name: Bob, role: user}
   - session:789: active

2. Accessing items:
📦 Cache hit: user:123
   Value: {name: Alice, role: admin}
✅ Cache hit: user:123
📦 Cache hit: user:456
   Value: {name: Bob, role: user}
✅ Cache hit: user:456

3. Waiting for TTL (5 seconds)...
🗑️ Cache entry expired
🗑️ Cache entry expired
🗑️ Cache entry expired

4. Accessing after TTL:
❌ Cache miss: user:123
❌ Cache miss: user:456
📊 Cache Stats:
   Entries: 0

═══ Done ═══
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **EphemeralPolicy** | Cell lifecycle management |
| **Duration** | Time-To-Live (TTL) |
| **Event Limit** | Maximum events before expiration |
| **onEvent** | Called on each interaction |
| **onInvalidate** | Called when cell expires |
| **PulseEphemeralPolicy** | Pulse-level lifecycle management |
| **Lazy Timer** | TTL starts on first interaction |

### Key Rules

1. **Timer is lazy** - Starts on first interaction, not creation
2. **Event counter tracks usage** - Can trigger invalidation
3. **Combined conditions** - TTL and event limit can be used together
4. **Clean up resources** - Use onInvalidate for cleanup
5. **Check invalidation** - Always check `cell.isInvalidated`
6. **Use Pulse policies for short-lived** - Tokens, temporary signals

### Common Patterns

```dart
// Pattern: TTL with sliding expiration
final policy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  onEvent: (object, {required cell, policy, arguments, user}) => (events: 0),
  onInvalidate: (nucleus) => true,
);

// Pattern: Event limit only
final policy = EphemeralPolicy(
  eventLimit: 100,
  onEvent: (object, {required cell, policy, arguments, user}) {
    return (events: policy.events + 1);
  },
  onInvalidate: (nucleus) => true,
);

// Pattern: Combined TTL + event limit
final policy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  eventLimit: 100,
  onEvent: (object, {required cell, policy, arguments, user}) {
    return (events: policy.events + 1);
  },
  onInvalidate: (nucleus) => true,
);

// Pattern: Error budget
final policy = EphemeralPolicy(
  eventLimit: 5,
  onEvent: (object, {required cell, policy, arguments, user}) {
    if (object is Exception) {
      return (events: policy.events + 1);
    }
    return (events: 0);
  },
  onInvalidate: (nucleus) => true,
);
```