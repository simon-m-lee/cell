# How to Use Synapses in the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What are Synapses?](#what-are-synapses)
3. [Core Concepts](#core-concepts)
4. [Creating Synapses](#creating-synapses)
5. [Linking and Unlinking](#linking-and-unlinking)
6. [Filtering Pulses](#filtering-pulses)
7. [Propagation Strategies](#propagation-strategies)
8. [Asynchronous Propagation](#asynchronous-propagation)
9. [Testing Synapses](#testing-synapses)
10. [Best Practices](#best-practices)
11. [Complete Example](#complete-example)

---

## Introduction

**Synapses** are the distribution network of the Cell Framework. They manage how a `Cell` broadcasts its pulses to downstream observers. Think of synapses as the **nervous system** of your reactive graph—they determine who gets notified when something changes.

### When to Use Synapses

- **Broadcasting** - Notify multiple observers of state changes
- **Filtering** - Transform or redact pulses before delivery
- **Rate Limiting** - Debounce, throttle, or batch outgoing pulses
- **Dynamic Topology** - Add/remove observers at runtime
- **Asynchronous Delivery** - Non-blocking propagation
- **Persistent State** - Replay last value to new observers

---

## What are Synapses?

A `Synapses` instance is the **observer registry** for a cell. It controls:

- **Who** receives pulses (downstream cells)
- **What** they receive (filtering)
- **When** they receive it (propagation strategy)
- **How** they receive it (sync/async)

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Dynamic** | Observers can be added/removed at runtime |
| **Filterable** | Pulses can be transformed before delivery |
| **Strategies** | 12 propagation strategies (debounce, throttle, batch, etc.) |
| **Async Support** | Non-blocking delivery via `async` view |
| **Thread-Safe** | All operations are atomic |
| **Cycle Detection** | Prevents infinite propagation loops |

### Default States

```dart
// Enabled - broadcasts to all observers (default)
final synapses = Synapses.enabled;

// Disabled - no propagation (terminal node)
final synapses = Synapses.disabled;
```

---

## Core Concepts

### 1. Synapses are the Egress Point

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CELL PROPAGATION FLOW                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │   INGRESS   │ -> │  RECEPTOR   │ -> │   TESTCELL  │ -> │  SYNAPSES   │ │
│  │  (Input)    │    │ (Transform) │    │  (Validate) │    │  (Output)   │ │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘ │
│                                                                             │
│  The Synapses is the final stage - it distributes the pulse to observers   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2. Synapses are Iterable

```dart
final synapses = Synapses<String, Cell>(
  downstreams: [logger, analytics, uiUpdater],
);

for (final observer in synapses) {
  print('Observer: $observer');
}
```

### 3. Synapses Have an Async View

```dart
final synapses = Synapses<String, Cell>();

// Synchronous broadcast
synapses.call(pulse);

// Asynchronous broadcast
await synapses.async.call(pulse);
```

### 4. Synapses Support Cycle Detection

The framework automatically prevents infinite loops:

```dart
// If cell A's synapses eventually loop back to A,
// the pulse carries a visited-node record and the cycle is broken
```

---

## Creating Synapses

### Method 1: Default (Enabled)

```dart
// Default - enabled with no observers
final synapses = Synapses.enabled;
// Or
final synapses = Synapses<String, Cell>();
```

### Method 2: With Initial Observers

```dart
final synapses = Synapses<String, Cell>(
  downstreams: [logger, analytics, uiUpdater],
);
```

### Method 3: With Filter

```dart
final synapses = Synapses<String, Cell>(
  filter: FilterRule((pulse, {user}) {
    // Only forward pulses with non-empty payload
    return pulse.payload.isNotEmpty ? pulse : null;
  }),
);
```

### Method 4: With Propagation Policy

```dart
final synapses = Synapses<String, Cell>(
  policy: PropagationPolicy(
    strategy: PropagationStrategy.debounced,
    debounceTime: Duration(milliseconds: 300),
  ),
);
```

### Method 5: With Custom Relay

```dart
final synapses = Synapses<String, Cell>(
  relay: (pulse) {
    // Custom distribution logic
    if (pulse.priority > 50) {
      urgentHandler.call(pulse);
    } else {
      normalHandler.call(pulse);
    }
  },
);
```

### Method 6: Disabled (Terminal)

```dart
// No propagation - cell is a sink
final synapses = Synapses.disabled;
```

---

## Linking and Unlinking

### Adding Observers (Link)

```dart
final source = Cell();
final observer = Cell();

final synapses = Synapses<String, Cell>();

// Link observer to source
final linked = await synapses.link(source, downstreamCell: observer);
if (linked) {
  print('Observer linked successfully');
}
```

### Removing Observers (Unlink)

```dart
// Unlink observer
final unlinked = synapses.unlink(source, downstreamCell: observer);
if (unlinked) {
  print('Observer unlinked');
}
```

### Dynamic Topology Example

```dart
class DynamicHub {
  final Cell source;
  final Synapses synapses;
  final List<Cell> observers = [];

  DynamicHub(Cell source)
      : source = source,
        synapses = Synapses();

  Future<void> addObserver(Cell observer) async {
    final linked = await synapses.link(source, downstreamCell: observer);
    if (linked) {
      observers.add(observer);
    }
  }

  void removeObserver(Cell observer) {
    if (synapses.unlink(source, downstreamCell: observer)) {
      observers.remove(observer);
    }
  }

  void clearObservers() {
    for (final observer in observers) {
      synapses.unlink(source, downstreamCell: observer);
    }
    observers.clear();
  }
}
```

### Link with Unlinker

```dart
// In an OpenCell, link returns an unlinker function
final unlinker = await openCell.link(observer);
if (unlinker != null) {
  // Later...
  unlinker();  // Removes the link
}
```

---

## Filtering Pulses

### Creating a Filter

```dart
// Filter that redacts sensitive data
final redactFilter = FilterRule<UserData>((pulse, {user}) {
  final data = pulse.payload;
  return Pulse(data.copyWith(
    email: '***@***.com',
    phone: '***-***-****',
  ));
});

final synapses = Synapses<UserData, Cell>(
  filter: redactFilter,
);
```

### Composing Filters

```dart
// Multiple filters chained
final redactFilter = FilterRule<UserData>((pulse, {user}) {
  return Pulse(redactData(pulse.payload));
});

final positiveFilter = FilterRule<int>((pulse, {user}) {
  return pulse.payload > 0 ? pulse : null;
});

final formatFilter = FilterRule<String>((pulse, {user}) {
  return Pulse('Formatted: ${pulse.payload}');
});

// Chain filters
final pipeline = redactFilter + positiveFilter + formatFilter;

final synapses = Synapses(
  filter: pipeline,
);
```

### Filter with Configuration

```dart
final thresholdFilter = FilterRule<int>(
  (pulse, {user}) {
    final limit = user as int? ?? 100;
    return pulse.payload > limit ? pulse : null;
  },
  user: 50,  // Custom threshold
);
```

---

## Propagation Strategies

### Strategy Overview

| Strategy | Behavior | Use Case |
|----------|----------|----------|
| `immediate` | Synchronous delivery (default) | Critical updates |
| `async` | Event loop delivery | Breaking recursion |
| `debounced` | Wait for silence | Search input |
| `throttled` | Rate-limit frequency | Scroll events |
| `batched` | Accumulate then deliver | Logging |
| `buffered` | Temporal accumulation | Audit trails |
| `audit` | Latest at interval | Telemetry |
| `exhaust` | Ignore while busy | Prevent overlapping |
| `sample` | Periodic heartbeat | Monitoring |
| `resilient` | Circuit breaker | Fault tolerance |
| `debounceLeading` | First immediate, then wait | Button clicks |
| `retry` | Retry on failure | Unreliable observers |
| `persistent` | Replay to new observers | Late-binding UI |

### 1. Immediate (Default)

```dart
final synapses = Synapses(
  policy: PropagationPolicy(
    strategy: PropagationStrategy.immediate,
  ),
);
// Pulses delivered synchronously
```

### 2. Async

```dart
final synapses = Synapses(
  policy: PropagationPolicy(
    strategy: PropagationStrategy.async,
  ),
);
// Pulses scheduled on event loop
```

### 3. Debounced

```dart
final synapses = Synapses(
  policy: PropagationPolicy(
    strategy: PropagationStrategy.debounced,
    debounceTime: Duration(milliseconds: 300),
  ),
);
// Emits after 300ms of silence
```

### 4. Throttled

```dart
final synapses = Synapses(
  policy: PropagationPolicy(
    strategy: PropagationStrategy.throttled,
    throttleTime: Duration(milliseconds: 100),
  ),
);
// At most one per 100ms
```

### 5. Batched

```dart
final synapses = Synapses(
  policy: PropagationPolicy(
    strategy: PropagationStrategy.batched,
    batchSize: 10,  // Emit after 10 pulses
  ),
);
// Batches pulses into groups of 10
```

### 6. Buffered

```dart
final synapses = Synapses(
  policy: PropagationPolicy(
    strategy: PropagationStrategy.buffered,
    throttleTime: Duration(milliseconds: 200),
    batchSize: 50,
  ),
);
// Buffers pulses, emits when timer expires or batch size reached
```

### 7. Persistent

```dart
final synapses = Synapses(
  policy: PropagationPolicy(
    strategy: PropagationStrategy.persistent,
  ),
);
// New observers receive the last emitted pulse
```

---

## Asynchronous Propagation

### Using the Async View

```dart
final synapses = Synapses<String, Cell>();

// Fire and forget
synapses.async.call(pulse);

// Wait for completion
await synapses.async.call(pulse);
```

### With Serialized Completion

```dart
// Waits for all downstream effects to settle
await synapses.async.call(
  pulse,
  serializedCompletion: true,
);
```

### Testing with Async Hooks

```dart
await synapses.async.call(
  pulse,
  hook: ({result, input}) {
    print('Input: ${input.payload}');
    print('Result: ${result?.payload}');
  },
);
```

---

## Testing Synapses

### Unit Testing Link/Unlink

```dart
import 'package:test/test.dart';

void main() {
  test('Link adds observer', () async {
    final source = Cell();
    final observer = Cell();
    final synapses = Synapses<String, Cell>();
    
    final linked = await synapses.link(source, downstreamCell: observer);
    expect(linked, true);
    expect(synapses.length, 1);
  });
  
  test('Unlink removes observer', () {
    final source = Cell();
    final observer = Cell();
    final synapses = Synapses<String, Cell>(
      downstreams: [observer],
    );
    
    final unlinked = synapses.unlink(source, downstreamCell: observer);
    expect(unlinked, true);
    expect(synapses.isEmpty, true);
  });
}
```

### Testing Propagation

```dart
test('Synapses broadcasts pulses to observers', () {
  final source = Cell();
  final observer1 = Cell();
  final observer2 = Cell();
  
  final synapses = Synapses<String, Cell>(
    downstreams: [observer1, observer2],
  );
  
  var received1 = false;
  var received2 = false;
  
  observer1._nucleus.receptor = Receptor((cell, pulse, {user}) {
    received1 = true;
    return pulse;
  });
  
  observer2._nucleus.receptor = Receptor((cell, pulse, {user}) {
    received2 = true;
    return pulse;
  });
  
  synapses.call(Pulse('test'));
  
  expect(received1, true);
  expect(received2, true);
});
```

### Testing Filters

```dart
test('Filter transforms pulses', () {
  final filter = FilterRule<String>((pulse, {user}) {
    return Pulse(pulse.payload.toUpperCase());
  });
  
  final synapses = Synapses<String, Cell>(
    filter: filter,
    downstreams: [observer],
  );
  
  var received = '';
  observer._nucleus.receptor = Receptor((cell, pulse, {user}) {
    received = pulse.payload as String? ?? '';
    return pulse;
  });
  
  synapses.call(Pulse('hello'));
  
  expect(received, 'HELLO');
});
```

### Testing Propagation Strategies

```dart
test('Debounced strategy delays emission', () async {
  final synapses = Synapses<String, Cell>(
    policy: PropagationPolicy(
      strategy: PropagationStrategy.debounced,
      debounceTime: Duration(milliseconds: 50),
    ),
    downstreams: [observer],
  );
  
  var received = false;
  observer._nucleus.receptor = Receptor((cell, pulse, {user}) {
    received = true;
    return pulse;
  });
  
  synapses.call(Pulse('test'));
  expect(received, false);  // Not yet
  
  await Future.delayed(Duration(milliseconds: 60));
  expect(received, true);   // Now delivered
});
```

---

## Best Practices

### 1. Use Disabled Synapses for Terminal Nodes

```dart
// ✅ GOOD - Terminal observer
final observer = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    // Side effects only
    print(pulse.payload);
    return null;
  }),
);

// ❌ BAD - Observer with enabled synapses (wasteful)
final observer = Cell(
  synapses: Synapses.enabled,  // Never used
  receptor: Receptor(...),
);
```

### 2. Use Filters for Security

```dart
// ✅ GOOD - Redact sensitive data
final redactFilter = FilterRule<UserData>((pulse, {user}) {
  return Pulse(pulse.payload.copyWith(
    ssn: '***-**-****',
    creditCard: '****',
  ));
});

final synapses = Synapses(
  filter: redactFilter,
);

// ❌ BAD - Expose sensitive data
final synapses = Synapses();  // No filtering
```

### 3. Use Propagation Strategies for Performance

```dart
// ✅ GOOD - Debounce high-frequency events
final synapses = Synapses(
  policy: PropagationPolicy(
    strategy: PropagationStrategy.debounced,
    debounceTime: Duration(milliseconds: 300),
  ),
);

// ❌ BAD - No rate limiting
final synapses = Synapses();  // Every event propagates
```

### 4. Clean Up Observers

```dart
// ✅ GOOD - Unlink when done
final unlinker = await openCell.link(observer);
// Later...
unlinker?.call();

// ❌ BAD - Memory leak
await openCell.link(observer);
// Never unlinked
```

### 5. Use Persistent for Late-Binding UI

```dart
// ✅ GOOD - New observers get current state
final synapses = Synapses(
  policy: PropagationPolicy(
    strategy: PropagationStrategy.persistent,
  ),
);

// When a new UI widget mounts, it receives the current state
```

### 6. Use Async for Non-Critical Updates

```dart
// ✅ GOOD - Async for logging
synapses.async.call(pulse);  // Fire and forget

// ❌ BAD - Blocking for logging
synapses.call(pulse);  // Synchronous, may block
```

---

## Complete Example

Here's a complete logging and monitoring system using Synapses:

```dart
import 'dart:async';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────
// 1. Define Log Levels and Events
// ─────────────────────────────────────────────────────────────

enum LogLevel { debug, info, warning, error }

class LogEvent {
  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  LogEvent({
    required this.level,
    required this.message,
    this.metadata = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 
      '[${level.name.toUpperCase()}] $message (${timestamp})';
}

// ─────────────────────────────────────────────────────────────
// 2. Create Filter Rules
// ─────────────────────────────────────────────────────────────

// Filter that only passes events above a certain level
FilterRule<LogEvent> levelFilter(LogLevel minLevel) {
  return FilterRule<LogEvent>((pulse, {user}) {
    final event = pulse.payload;
    final levels = [LogLevel.debug, LogLevel.info, LogLevel.warning, LogLevel.error];
    return levels.indexOf(event.level) >= levels.indexOf(minLevel)
        ? pulse
        : null;
  });
}

// Filter that redacts sensitive data
final redactFilter = FilterRule<LogEvent>((pulse, {user}) {
  final event = pulse.payload;
  final redactedMetadata = Map<String, dynamic>.from(event.metadata);
  redactedMetadata.remove('password');
  redactedMetadata.remove('apiKey');
  
  return Pulse(LogEvent(
    level: event.level,
    message: event.message,
    metadata: redactedMetadata,
    timestamp: event.timestamp,
  ));
});

// ─────────────────────────────────────────────────────────────
// 3. Create Observers (Cells)
// ─────────────────────────────────────────────────────────────

// Console logger
final consoleLogger = Cell(
  synapses: Synapses.disabled,  // Terminal node
  receptor: Receptor((cell, pulse, {user}) {
    final event = pulse.payload as LogEvent?;
    if (event != null) {
      print('${event.timestamp} ${event.message}');
    }
    return null;
  }),
);

// File writer (simulated)
final fileWriter = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    final event = pulse.payload as LogEvent?;
    if (event != null) {
      // Write to file (simulated)
      print('   [File] Writing: $event');
    }
    return null;
  }),
);

// Metrics collector
final metricsCollector = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    final event = pulse.payload as LogEvent?;
    if (event != null) {
      // Record metrics (simulated)
      print('   [Metrics] Recording: ${event.level} - ${event.message}');
    }
    return null;
  }),
);

// Error alert
final errorAlert = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    final event = pulse.payload as LogEvent?;
    if (event != null && event.level == LogLevel.error) {
      print('   [Alert] 🚨 ERROR: ${event.message}');
    }
    return null;
  }),
);

// ─────────────────────────────────────────────────────────────
// 4. Create Synapses with Strategies
// ─────────────────────────────────────────────────────────────

// Main log hub - distributes to all observers
final logHub = Synapses<LogEvent, Cell>(
  filter: levelFilter(LogLevel.info) + redactFilter,
  downstreams: [consoleLogger, fileWriter, metricsCollector, errorAlert],
);

// ─────────────────────────────────────────────────────────────
// 5. Create Source Cell
// ─────────────────────────────────────────────────────────────

final logSource = Cell(
  synapses: logHub,
  receptor: Receptor((cell, pulse, {user}) {
    // Pass through
    return pulse;
  }),
);

// ─────────────────────────────────────────────────────────────
// 6. Utility Function
// ─────────────────────────────────────────────────────────────

void log(LogLevel level, String message, {Map<String, dynamic> metadata = const {}}) {
  final event = LogEvent(
    level: level,
    message: message,
    metadata: metadata,
  );
  logSource._nucleus.receptor.call(Pulse(event));
}

// ─────────────────────────────────────────────────────────────
// 7. Main Demo
// ─────────────────────────────────────────────────────────────

void main() {
  print('═══ Logging System with Synapses ═══\n');

  // Log messages at different levels
  log(LogLevel.info, 'User logged in', metadata: {'userId': 123});
  log(LogLevel.debug, 'Cache hit', metadata: {'key': 'user:123'});
  log(LogLevel.warning, 'High memory usage', metadata: {'usage': '85%'});
  log(LogLevel.error, 'Database connection failed', 
      metadata: {'error': 'timeout', 'password': 'secret123'});

  print('\n═══ Done ═══');
}
```

**Expected Output:**
```
═══ Logging System with Synapses ═══

2024-01-15 14:30:00.000 User logged in
   [File] Writing: [INFO] User logged in (2024-01-15 14:30:00.000)
   [Metrics] Recording: info - User logged in
2024-01-15 14:30:00.010 Cache hit
   [File] Writing: [DEBUG] Cache hit (2024-01-15 14:30:00.010)
   [Metrics] Recording: debug - Cache hit
2024-01-15 14:30:00.020 High memory usage
   [File] Writing: [WARNING] High memory usage (2024-01-15 14:30:00.020)
   [Metrics] Recording: warning - High memory usage
2024-01-15 14:30:00.030 Database connection failed
   [File] Writing: [ERROR] Database connection failed (2024-01-15 14:30:00.030)
   [Metrics] Recording: error - Database connection failed
   [Alert] 🚨 ERROR: Database connection failed

═══ Done ═══
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **Synapses** | Distribution network for cell pulses |
| **Link** | Add an observer |
| **Unlink** | Remove an observer |
| **Filter** | Transform/redact pulses before delivery |
| **Propagation Strategy** | Control timing of delivery |
| **Async** | Non-blocking propagation |

### Key Rules

1. **Use disabled synapses** for terminal nodes (observers)
2. **Use filters** for security and data transformation
3. **Use propagation strategies** for performance
4. **Clean up observers** with unlink or unlinker
5. **Use async** for non-critical updates
6. **Test** links, filters, and strategies

### Common Patterns

```dart
// Pattern: Distribution hub
final hub = Synapses(downstreams: [observer1, observer2, observer3]);

// Pattern: Filtering pipeline
final filter = redactFilter + validateFilter + formatFilter;

// Pattern: Rate limiting
final synapses = Synapses(
  policy: PropagationPolicy(
    strategy: PropagationStrategy.debounced,
    debounceTime: Duration(milliseconds: 300),
  ),
);

// Pattern: Dynamic topology
final unlinker = await openCell.link(observer);

// Pattern: Async propagation
await synapses.async.call(pulse);
```