# How to Use PropagationPolicy in the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What is PropagationPolicy?](#what-is-propagationpolicy)
3. [Core Concepts](#core-concepts)
4. [Propagation Strategies](#propagation-strategies)
5. [Creating a PropagationPolicy](#creating-a-propagationpolicy)
6. [Strategy Reference](#strategy-reference)
7. [Using with Synapses](#using-with-synapses)
8. [Filtering with FilterRule](#filtering-with-filterrule)
9. [Testing PropagationPolicy](#testing-propagationpolicy)
10. [Best Practices](#best-practices)
11. [Complete Example](#complete-example)

---

## Introduction

**PropagationPolicy** controls how pulses are distributed from a cell to its observers. It defines the **tactical execution model**—the timing, batching, and delivery behavior of signals as they flow through the reactive graph.

### When to Use PropagationPolicy

| Scenario | Recommended Strategy |
|----------|---------------------|
| Critical state updates | `immediate` |
| UI responsiveness | `async` |
| Search-as-you-type | `debounced` |
| Rate limiting | `throttled` |
| Batch processing | `batched` |
| Audit trails | `buffered` |
| Telemetry sampling | `audit` or `sample` |
| Circuit breaker | `resilient` |
| Button debouncing | `debounceLeading` |
| Reliable delivery | `retry` |
| Late-binding UI | `persistent` |

---

## What is PropagationPolicy?

`PropagationPolicy` is a declarative blueprint that defines the **temporal dynamics** and **operational governance** of pulse propagation. It determines how the framework reconciles high-frequency stimuli, manages aggregation buffers, and ensures transactional integrity.

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Declarative** | Define behavior, not implementation |
| **Configurable** | Timing, batching, and retry settings |
| **Per-Synapse** | Different policies for different outputs |
| **Non-Blocking** | Async strategies for responsive UIs |
| **Resilient** | Circuit breaker and retry patterns |
| **Memory-Aware** | Buffering with configurable limits |

### Propagation Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PROPAGATION FLOW                                   │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                    │
│  │   SOURCE    │ -> │   FILTER    │ -> │   POLICY    │ -> │  OBSERVERS   │
│  │    CELL     │    │   RULE      │    │   STRATEGY  │    │              │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘ │
│                                                                             │
│  The PropagationPolicy sits between the filter and the observers,          │
│  controlling timing, batching, and delivery behavior.                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Core Concepts

### 1. Strategy Selection

The `strategy` determines the execution model:

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.debounced,
  debounceTime: Duration(milliseconds: 300),
);
```

### 2. Timing Parameters

Different strategies use different timing parameters:

| Parameter | Used By |
|-----------|---------|
| `debounceTime` | `debounced`, `debounceLeading` |
| `throttleTime` | `throttled`, `audit`, `sample`, `buffered` |
| `batchSize` | `batched`, `buffered`, `retry` |

### 3. Default Values

| Parameter | Default |
|-----------|---------|
| `debounceTime` | 150ms |
| `throttleTime` | 200ms |
| `batchSize` | 10 |
| `strategy` | `immediate` |

---

## Propagation Strategies

### Strategy Overview

| Strategy | Behavior | Use Case |
|----------|----------|----------|
| `immediate` | Synchronous delivery | Critical updates |
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

### Strategy Selection Guide

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     STRATEGY SELECTION GUIDE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  "Do I need immediate updates?"                                     │   │
│  │  ┌─────────────┐                                                    │   │
│  │  │  YES        │ -> Use `immediate` or `async`                     │   │
│  │  │  NO         │ ──────────────────────────────────────────────┐   │   │
│  │  └─────────────┘                                               │   │   │
│  └─────────────────────────────────────────────────────────────────┘   │   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  "Do I need to wait for silence?"                                  │   │
│  │  ┌─────────────┐                                                    │   │
│  │  │  YES        │ -> Use `debounced`                                │   │
│  │  │  NO         │ ──────────────────────────────────────────────┐   │   │
│  │  └─────────────┘                                               │   │   │
│  └─────────────────────────────────────────────────────────────────┘   │   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  "Do I need to rate-limit?"                                        │   │
│  │  ┌─────────────┐                                                    │   │
│  │  │  YES        │ -> Use `throttled`                                │   │
│  │  │  NO         │ ──────────────────────────────────────────────┐   │   │
│  │  └─────────────┘                                               │   │   │
│  └─────────────────────────────────────────────────────────────────┘   │   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  "Do I need to batch updates?"                                      │   │
│  │  ┌─────────────┐                                                    │   │
│  │  │  YES        │ -> Use `batched` or `buffered`                    │   │
│  │  │  NO         │ ──────────────────────────────────────────────┐   │   │
│  │  └─────────────┘                                               │   │   │
│  └─────────────────────────────────────────────────────────────────┘   │   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  "Do I need to handle failures?"                                    │   │
│  │  ┌─────────────┐                                                    │   │
│  │  │  YES        │ -> Use `resilient` or `retry`                     │   │
│  │  │  NO         │ ──────────────────────────────────────────────┐   │   │
│  │  └─────────────┘                                               │   │   │
│  └─────────────────────────────────────────────────────────────────┘   │   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  "Do I need to replay to new observers?"                            │   │
│  │  ┌─────────────┐                                                    │   │
│  │  │  YES        │ -> Use `persistent`                                │   │
│  │  │  NO         │ -> Choose another strategy                        │   │
│  │  └─────────────┘                                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Creating a PropagationPolicy

### Method 1: Immediate (Default)

```dart
// Synchronous, immediate delivery
final policy = PropagationPolicy(
  strategy: PropagationStrategy.immediate,
);
```

### Method 2: Debounced

```dart
// Wait for 300ms of silence before emitting
final policy = PropagationPolicy(
  strategy: PropagationStrategy.debounced,
  debounceTime: Duration(milliseconds: 300),
);
```

### Method 3: Throttled

```dart
// At most one emission per 100ms
final policy = PropagationPolicy(
  strategy: PropagationStrategy.throttled,
  throttleTime: Duration(milliseconds: 100),
);
```

### Method 4: Batched

```dart
// Accumulate 10 pulses, then deliver as a batch
final policy = PropagationPolicy(
  strategy: PropagationStrategy.batched,
  batchSize: 10,
);
```

### Method 5: Buffered

```dart
// Accumulate pulses for 200ms or until 50 items
final policy = PropagationPolicy(
  strategy: PropagationStrategy.buffered,
  throttleTime: Duration(milliseconds: 200),
  batchSize: 50,
);
```

### Method 6: Retry

```dart
// Retry failed deliveries up to 3 times
final policy = PropagationPolicy(
  strategy: PropagationStrategy.retry,
  batchSize: 3,  // Max retries
  throttleTime: Duration(milliseconds: 100), // Delay between retries
);
```

---

## Strategy Reference

### 1. immediate

Synchronous, immediate delivery.

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.immediate,
);

// Use when:
// - Critical state updates must be synchronous
// - Transactional integrity is required
// - Low latency is critical
```

### 2. async

Scheduled on the event loop.

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.async,
);

// Use when:
// - Breaking deep recursion chains
// - Avoiding UI jank
// - Non-critical updates
```

### 3. debounced

Waits for a period of silence.

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.debounced,
  debounceTime: Duration(milliseconds: 300),
);

// Use when:
// - Search-as-you-type
// - Form validation
// - Autosave
// - Window resize

// Example: Search input
// User types "h" -> wait
// User types "he" -> wait
// User types "hel" -> wait
// User stops typing for 300ms -> emit "hel"
```

### 4. throttled

Rate-limits to a fixed frequency.

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.throttled,
  throttleTime: Duration(milliseconds: 100),
);

// Use when:
// - UI scroll events (60fps)
// - Mouse move events
// - API rate limiting
// - Sensor data sampling

// Example: Scroll events
// Scroll #1 -> emit immediately
// Scroll #2 -> suppressed (within 100ms)
// Scroll #3 -> suppressed (within 100ms)
// (100ms passes) -> Scroll #4 -> emit immediately
```

### 5. batched

Accumulates pulses and delivers as a batch.

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.batched,
  batchSize: 10,
);

// Use when:
// - Logging
// - Bulk database writes
// - Multi-item UI updates
// - Analytics events

// Example: Logging
// log1, log2, log3, ... log10 -> batched delivery
```

### 6. buffered

Accumulates pulses with time and size limits.

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.buffered,
  throttleTime: Duration(milliseconds: 200),
  batchSize: 50,
);

// Use when:
// - Audit trails
// - High-density telemetry
// - I/O-heavy operations
// - Database persistence

// Example: Audit trail
// Each pulse buffered for 200ms or until 50 pulses
// Then delivered as a composite event
```

### 7. audit

Delivers the latest pulse at a fixed interval.

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.audit,
  throttleTime: Duration(milliseconds: 500),
);

// Use when:
// - Real-time dashboards
// - Telemetry sampling
// - Latest value monitoring

// Example: Dashboard updates
// Updates happen frequently, but UI refreshes every 500ms with the latest
```

### 8. exhaust

Ignores new pulses while busy processing.

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.exhaust,
);

// Use when:
// - Preventing overlapping async operations
// - Avoiding duplicate processing
// - Expensive operations

// Example: API call with loading state
// First click -> triggers API call
// Subsequent clicks during call -> ignored
```

### 9. sample

Periodic heartbeat of the current state.

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.sample,
  throttleTime: Duration(milliseconds: 1000),
);

// Use when:
// - Constant-rate telemetry
// - Physics engines
// - Monitoring systems

// Example: CPU monitoring
// Emits current CPU usage every second
```

### 10. resilient

Circuit breaker pattern.

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.resilient,
);

// Use when:
// - Unreliable network integrations
// - Experimental AI logic
// - Fault-tolerant systems

// Example: Circuit breaker
// On first few failures, continue
// After threshold, "open" circuit and stop propagation
// After cooldown, "half-open" and test again
```

### 11. debounceLeading

First pulse immediate, then wait for silence.

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.debounceLeading,
  debounceTime: Duration(milliseconds: 300),
);

// Use when:
// - Button clicks (immediate feedback)
// - UI actions with debounced backend

// Example: Submit button
// Click -> immediate feedback (loading state)
// Subsequent clicks ignored for 300ms
```

### 12. retry

Retries failed deliveries.

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.retry,
  batchSize: 3,  // Max retries
  throttleTime: Duration(milliseconds: 100), // Retry delay
);

// Use when:
// - Unreliable network observers
// - Distributed nodes
// - Temporary failures

// Example: WebSocket observer
// If delivery fails, retry up to 3 times
```

### 13. persistent

Replays last value to new observers.

```dart
final policy = PropagationPolicy(
  strategy: PropagationStrategy.persistent,
);

// Use when:
// - Late-binding UI components
// - Dynamic observers
// - State rehydration

// Example: UI late-binding
// New widget mounts -> receives current state
```

---

## Using with Synapses

### Basic Usage

```dart
final synapses = Synapses<String, Cell>(
  policy: PropagationPolicy(
    strategy: PropagationStrategy.debounced,
    debounceTime: Duration(milliseconds: 300),
  ),
  downstreams: [observer1, observer2],
);
```

### Full Example

```dart
// 1. Create policy
final policy = PropagationPolicy(
  strategy: PropagationStrategy.throttled,
  throttleTime: Duration(milliseconds: 100),
);

// 2. Create filter
final filter = FilterRule<String>((pulse, {user}) {
  return pulse.payload.isNotEmpty ? pulse : null;
});

// 3. Create synapses
final synapses = Synapses<String, Cell>(
  policy: policy,
  filter: filter,
  downstreams: [uiUpdater, logger, analytics],
);

// 4. Create cell with synapses
final cell = Cell(
  synapses: synapses,
  receptor: Receptor.passThrough,
);
```

### With Custom Relay

```dart
final synapses = Synapses<String, Cell>(
  policy: PropagationPolicy(
    strategy: PropagationStrategy.immediate,
  ),
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

---

## Filtering with FilterRule

### Basic Filter

```dart
final filter = FilterRule<String>((pulse, {user}) {
  return pulse.payload.isNotEmpty ? pulse : null;
});

final synapses = Synapses(
  filter: filter,
  policy: PropagationPolicy.immediate,
);
```

### Composing Filters

```dart
final redactFilter = FilterRule<String>((pulse, {user}) {
  return Pulse(pulse.payload.replaceAll('secret', '***'));
});

final validateFilter = FilterRule<String>((pulse, {user}) {
  return pulse.payload.isNotEmpty ? pulse : null;
});

final pipeline = redactFilter + validateFilter;

final synapses = Synapses(
  filter: pipeline,
);
```

### Filter with Policy

```dart
final synapses = Synapses<String, Cell>(
  filter: FilterRule((pulse, {user}) {
    // Filter before policy applies
    if (pulse.payload.isEmpty) return null;
    return pulse;
  }),
  policy: PropagationPolicy(
    strategy: PropagationStrategy.debounced,
    debounceTime: Duration(milliseconds: 300),
  ),
);
```

---

## Testing PropagationPolicy

### Unit Testing Strategies

```dart
import 'package:test/test.dart';

void main() {
  test('Immediate strategy delivers synchronously', () {
    final policy = PropagationPolicy(
      strategy: PropagationStrategy.immediate,
    );
    final synapses = Synapses<String, Cell>(
      policy: policy,
      downstreams: [observer],
    );
    
    var received = false;
    observer._nucleus.receptor = Receptor((cell, pulse, {user}) {
      received = true;
      return pulse;
    });
    
    synapses.call(Pulse('test'));
    expect(received, true);
  });

  test('Debounced strategy delays emission', () async {
    final policy = PropagationPolicy(
      strategy: PropagationStrategy.debounced,
      debounceTime: Duration(milliseconds: 50),
    );
    final synapses = Synapses<String, Cell>(
      policy: policy,
      downstreams: [observer],
    );
    
    var received = false;
    observer._nucleus.receptor = Receptor((cell, pulse, {user}) {
      received = true;
      return pulse;
    });
    
    synapses.call(Pulse('test'));
    expect(received, false);
    
    await Future.delayed(Duration(milliseconds: 60));
    expect(received, true);
  });

  test('Throttled strategy rate-limits', () async {
    final policy = PropagationPolicy(
      strategy: PropagationStrategy.throttled,
      throttleTime: Duration(milliseconds: 100),
    );
    final synapses = Synapses<String, Cell>(
      policy: policy,
      downstreams: [observer],
    );
    
    var count = 0;
    observer._nucleus.receptor = Receptor((cell, pulse, {user}) {
      count++;
      return pulse;
    });
    
    synapses.call(Pulse('1'));
    synapses.call(Pulse('2'));
    synapses.call(Pulse('3'));
    
    await Future.delayed(Duration(milliseconds: 150));
    
    expect(count, 2); // First + last after window
  });
}
```

### Testing Batched Strategy

```dart
test('Batched strategy accumulates pulses', () {
  final policy = PropagationPolicy(
    strategy: PropagationStrategy.batched,
    batchSize: 3,
  );
  final synapses = Synapses<String, Cell>(
    policy: policy,
    downstreams: [observer],
  );
  
  var received = false;
  observer._nucleus.receptor = Receptor((cell, pulse, {user}) {
    final batch = pulse.payload as List?;
    if (batch != null && batch.length == 3) {
      received = true;
    }
    return pulse;
  });
  
  synapses.call(Pulse('1'));
  synapses.call(Pulse('2'));
  expect(received, false);
  
  synapses.call(Pulse('3'));
  expect(received, true);
});
```

### Testing Filter

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

---

## Best Practices

### 1. Choose the Right Strategy

```dart
// ✅ GOOD - Debounce for search
final searchPolicy = PropagationPolicy(
  strategy: PropagationStrategy.debounced,
  debounceTime: Duration(milliseconds: 300),
);

// ✅ GOOD - Throttle for scroll
final scrollPolicy = PropagationPolicy(
  strategy: PropagationStrategy.throttled,
  throttleTime: Duration(milliseconds: 16), // ~60fps
);

// ✅ GOOD - Batch for logging
final logPolicy = PropagationPolicy(
  strategy: PropagationStrategy.batched,
  batchSize: 10,
);

// ❌ BAD - Immediate for search
final searchPolicy = PropagationPolicy.immediate; // Too many updates
```

### 2. Set Appropriate Timing

```dart
// ✅ GOOD - Reasonable debounce for typing
debounceTime: Duration(milliseconds: 300)

// ❌ BAD - Too short (flickers)
debounceTime: Duration(milliseconds: 10)

// ❌ BAD - Too long (slow response)
debounceTime: Duration(seconds: 5)
```

### 3. Use Filters for Security

```dart
// ✅ GOOD - Redact sensitive data
final filter = FilterRule<UserData>((pulse, {user}) {
  return Pulse(pulse.payload.copyWith(
    email: '***@***.com',
    phone: '***-***-****',
  ));
});

// ❌ BAD - No filtering
final filter = FilterRule.base(); // Passes everything
```

### 4. Use Persistent for Late-Binding

```dart
// ✅ GOOD - New observers get current state
final policy = PropagationPolicy(
  strategy: PropagationStrategy.persistent,
);

// ❌ BAD - New observers miss state
final policy = PropagationPolicy.immediate;
```

### 5. Handle Failures with Retry or Resilient

```dart
// ✅ GOOD - Retry on failure
final policy = PropagationPolicy(
  strategy: PropagationStrategy.retry,
  batchSize: 3,
);

// ✅ GOOD - Circuit breaker
final policy = PropagationPolicy(
  strategy: PropagationStrategy.resilient,
);

// ❌ BAD - Immediate (no error handling)
final policy = PropagationPolicy.immediate;
```

---

## Complete Example

Here's a complete e-commerce event processing system:

```dart
import 'dart:async';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// 1. Event Types
// ─────────────────────────────────────────────────────────────────────────

enum EventType { user_action, system_event, telemetry, audit }

class Event {
  final EventType type;
  final String name;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  Event({
    required this.type,
    required this.name,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'Event(${type.name}: $name)';
}

// ─────────────────────────────────────────────────────────────────────────
// 2. Event Handlers (Observers)
// ─────────────────────────────────────────────────────────────────────────

// UI Updater - high priority, immediate
final uiUpdater = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    final event = pulse.payload as Event;
    print('🖥️ UI: ${event.name} - ${event.data}');
    return null;
  }),
);

// Logger - batched
final logger = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    final events = pulse.payload as List<Event>;
    print('📝 Logging ${events.length} events:');
    for (final event in events) {
      print('   - ${event.name} at ${event.timestamp}');
    }
    return null;
  }),
);

// Analytics - debounced
final analytics = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    final event = pulse.payload as Event;
    print('📊 Analytics: ${event.name}');
    return null;
  }),
);

// Audit - buffered
final audit = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    final events = pulse.payload as List<Event>;
    print('🔒 Audit: ${events.length} events');
    for (final event in events) {
      print('   - ${event.name} by ${event.data['user'] ?? 'system'}');
    }
    return null;
  }),
);

// ─────────────────────────────────────────────────────────────────────────
// 3. Propagations Policies
// ─────────────────────────────────────────────────────────────────────────

// User actions: immediate
final userActionPolicy = PropagationPolicy.immediate;

// System events: async
final systemEventPolicy = PropagationPolicy(
  strategy: PropagationStrategy.async,
);

// Telemetry: throttled
final telemetryPolicy = PropagationPolicy(
  strategy: PropagationStrategy.throttled,
  throttleTime: Duration(milliseconds: 100),
);

// Audit: buffered
final auditPolicy = PropagationPolicy(
  strategy: PropagationStrategy.buffered,
  throttleTime: Duration(milliseconds: 500),
  batchSize: 10,
);

// Logs: batched
final logPolicy = PropagationPolicy(
  strategy: PropagationStrategy.batched,
  batchSize: 5,
);

// ─────────────────────────────────────────────────────────────────────────
// 4. Filters
// ─────────────────────────────────────────────────────────────────────────

// Only pass user actions
final userActionFilter = FilterRule<Event>((pulse, {user}) {
  return pulse.payload.type == EventType.user_action ? pulse : null;
});

// Only pass system events
final systemEventFilter = FilterRule<Event>((pulse, {user}) {
  return pulse.payload.type == EventType.system_event ? pulse : null;
});

// Only pass telemetry
final telemetryFilter = FilterRule<Event>((pulse, {user}) {
  return pulse.payload.type == EventType.telemetry ? pulse : null;
});

// Pass audit events (buffered)
final auditFilter = FilterRule<Event>((pulse, {user}) {
  return pulse.payload.type == EventType.audit ? pulse : null;
});

// ─────────────────────────────────────────────────────────────────────────
// 5. Synapses
// ─────────────────────────────────────────────────────────────────────────

final userSynapses = Synapses<Event, Cell>(
  filter: userActionFilter,
  policy: userActionPolicy,
  downstreams: [uiUpdater, analytics],
);

final systemSynapses = Synapses<Event, Cell>(
  filter: systemEventFilter,
  policy: systemEventPolicy,
  downstreams: [uiUpdater],
);

final telemetrySynapses = Synapses<Event, Cell>(
  filter: telemetryFilter,
  policy: telemetryPolicy,
  downstreams: [analytics],
);

final auditSynapses = Synapses<Event, Cell>(
  filter: auditFilter,
  policy: auditPolicy,
  downstreams: [audit],
);

final logSynapses = Synapses<Event, Cell>(
  policy: logPolicy,
  downstreams: [logger],
);

// ─────────────────────────────────────────────────────────────────────────
// 6. Event Source
// ─────────────────────────────────────────────────────────────────────────

// Create the main event source
final eventSource = Cell(
  synapses: Synapses(  // Combine all synapses
    downstreams: [
      ...userSynapses,
      ...systemSynapses,
      ...telemetrySynapses,
      ...auditSynapses,
      ...logSynapses,
    ],
  ),
  receptor: Receptor.passThrough,
);

// ─────────────────────────────────────────────────────────────────────────
// 7. Utility Function
// ─────────────────────────────────────────────────────────────────────────

void emitEvent(Event event) {
  eventSource._nucleus.receptor.call(Pulse(event));
}

// ─────────────────────────────────────────────────────────────────────────
// 8. Main Demo
// ─────────────────────────────────────────────────────────────────────────

void main() async {
  print('═══ Event Processing with PropagationPolicy ═══\n');

  // User actions (immediate)
  print('1. User Actions:');
  emitEvent(Event(
    type: EventType.user_action,
    name: 'Login',
    data: {'user': 'alice'},
  ));
  emitEvent(Event(
    type: EventType.user_action,
    name: 'Add to Cart',
    data: {'product': 'Laptop', 'quantity': 1},
  ));

  // System events (async)
  print('\n2. System Events:');
  emitEvent(Event(
    type: EventType.system_event,
    name: 'System Startup',
    data: {'version': '2.0.0'},
  ));
  emitEvent(Event(
    type: EventType.system_event,
    name: 'Config Updated',
    data: {'setting': 'theme=dark'},
  ));

  // Telemetry (throttled)
  print('\n3. Telemetry (throttled):');
  for (int i = 1; i <= 5; i++) {
    emitEvent(Event(
      type: EventType.telemetry,
      name: 'CPU Usage',
      data: {'core': '0', 'usage': 10 + i * 5},
    ));
    await Future.delayed(Duration(milliseconds: 30));
  }

  // Audit (buffered)
  print('\n4. Audit (buffered):');
  for (int i = 1; i <= 3; i++) {
    emitEvent(Event(
      type: EventType.audit,
      name: 'Access Check',
      data: {'user': 'admin', 'resource': 'secret.txt'},
    ));
  }

  // Logs (batched)
  print('\n5. Logs (batched):');
  for (int i = 1; i <= 6; i++) {
    emitEvent(Event(
      type: EventType.system_event,
      name: 'Log Entry',
      data: {'level': 'info', 'message': 'Operation ${i} completed'},
    ));
  }

  // Wait for async propagation
  await Future.delayed(Duration(seconds: 1));

  print('\n═══ Done ═══');
}
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **PropagationPolicy** | Controls timing and delivery of pulses |
| **Strategy** | Execution model (immediate, debounced, etc.) |
| **debounceTime** | Silence window for debounce |
| **throttleTime** | Minimum interval between emissions |
| **batchSize** | Accumulation threshold |
| **FilterRule** | Transform/redact pulses before delivery |

### Strategy Quick Reference

| Strategy | Best For | Key Parameter |
|----------|----------|---------------|
| `immediate` | Critical updates | None |
| `async` | Non-blocking | None |
| `debounced` | Search, validation | `debounceTime` |
| `throttled` | Scroll, rate limiting | `throttleTime` |
| `batched` | Logging, bulk writes | `batchSize` |
| `buffered` | Audit, telemetry | `throttleTime`, `batchSize` |
| `audit` | Dashboards | `throttleTime` |
| `exhaust` | Prevent overlapping | None |
| `sample` | Monitoring | `throttleTime` |
| `resilient` | Fault tolerance | None |
| `debounceLeading` | Buttons | `debounceTime` |
| `retry` | Unreliable observers | `batchSize`, `throttleTime` |
| `persistent` | Late-binding UI | None |