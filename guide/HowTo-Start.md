# Getting Started with the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What is the Cell Framework?](#what-is-the-cell-framework)
3. [Core Concepts](#core-concepts)
4. [Installation](#installation)
5. [Your First Cell](#your-first-cell)
6. [The Learning Path](#the-learning-path)
7. [The "Core 16" Essential Operators](#the-core-16-essential-operators)
8. [Common Patterns](#common-patterns)
9. [Next Steps](#next-steps)

---

## Introduction

Welcome to the **Cell Framework**! This guide will help you get started with building reactive applications using Cells. Whether you're building a Flutter app, a backend service, or a CLI tool, the Cell Framework provides a powerful, type-safe, and thread-safe way to manage state and data flow.

### What Problem Does Cell Solve?

| Problem | Cell Solution |
|---------|---------------|
| Complex state management | Reactive cells that automatically notify observers |
| Race conditions | Thread-safe, atomic operations with locks |
| Security and permissions | TestCell validation gates and deputy contexts |
| Debugging and auditing | Causal tracing with Pulse lineage |
| Data transformation | Composable pipelines with Instructions |
| Async operations | Built-in asyncMap, fromFuture, fromStream |

---

## What is the Cell Framework?

The Cell Framework is a **high‑performance, thread‑safe reactive framework** built around a few powerful ideas:

- **Cells** hold state
- **Pulses** carry changes
- **Receptors** transform data
- **Synapses** distribute updates
- **TestCell** governs validation
- **Context** defines security

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Reactive** | Cells automatically notify observers when state changes |
| **Thread-Safe** | All operations are atomic and synchronized |
| **Type-Safe** | Full Dart generics support |
| **Zero-Copy** | Deputies share state without duplication |
| **Auditable** | Every pulse carries a causal trace |
| **Composable** | Build complex systems from simple building blocks |

---

## Core Concepts

### 1. Cell — The Reactive Node

A `Cell` is the fundamental building block. It holds state (or relays signals), validates every incoming change against a policy, and broadcasts accepted changes to whatever else is listening.

```dart
// A simple counter cell
final counter = Cell.state<int>(
  initial: 0,
  evolve: (host, input) {
    final delta = input.payload as int? ?? 1;
    return Pulse(host.value + delta);
  },
);
```

### 2. Pulse — The Signal

A `Pulse` is an immutable message that carries data, provenance, and governance metadata through the reactive graph.

```dart
// Create a pulse
final pulse = Pulse('Hello, World!', type: 'message');

// Evolve a pulse (adds causal trace)
final evolved = pulse.withStep('validation');
print(evolved.trace); // ['validation']
```

### 3. Receptor — The Transformer

A `Receptor` is the transformation pipeline that decides how a cell responds to an incoming pulse.

```dart
final receptor = Receptor((cell, pulse, {user}) {
  final text = pulse.payload as String?;
  return Pulse(text?.toUpperCase());
});
```

### 4. TestCell — The Validator

A `TestCell` is the validation gate that decides what's allowed.

```dart
final isPositive = TestCell<int>((value, {host, ...}) => value > 0);
final cell = Cell(testRule: isPositive);
```

### 5. Context — The Security Tier

A `Context` defines the security tier, domain, and operational boundaries of a cell.

```dart
final context = Context.secureEnclave(
  partOf: 'CryptoModule',
  compliances: 'FIPS-140-2',
);
```

---

## Installation

### Add to `pubspec.yaml`

```yaml
dependencies:
  cell: ^1.0.0
```

### Import in Your Code

```dart
import 'package:cell/cell.dart';
```

---

## Your First Cell

### Step 1: Create a State Cell

```dart
import 'package:cell/cell.dart';

void main() {
  // Create a counter cell
  final counter = Cell.state<int>(
    initial: 0,
    evolve: (host, input) {
      final delta = input.payload as int? ?? 1;
      return Pulse(host.value + delta);
    },
  );

  // Update the counter
  counter.update(1);  // value becomes 1
  counter.update(5);  // value becomes 6

  // Read the value
  print(counter.cell.value); // 6
}
```

### Step 2: Observe Changes

```dart
import 'package:cell/cell.dart';

void main() {
  final counter = Cell.state<int>(
    initial: 0,
    evolve: (host, input) {
      final delta = input.payload as int? ?? 1;
      return Pulse(host.value + delta);
    },
  );

  // Observe changes
  final observer = Cell.observe<int>(
    bind: counter.cell,
    effect: (pulse) {
      print('Counter changed to: ${pulse.payload}');
    },
  );

  counter.update(1);  // Prints: "Counter changed to: 1"
  counter.update(5);  // Prints: "Counter changed to: 6"
}
```

### Step 3: Add Validation

```dart
import 'package:cell/cell.dart';

void main() {
  // Only allow positive numbers
  final isPositive = TestCell<int>((value, {host, ...}) => value > 0);

  final counter = Cell.state<int>(
    initial: 0,
    evolve: (host, input) {
      final delta = input.payload as int? ?? 1;
      return Pulse(host.value + delta);
    },
    testRule: isPositive,
  );

  counter.update(5);   // ✓ Allowed
  counter.update(-1);  // ✗ Blocked (value stays 5)

  print(counter.cell.value); // 5
}
```

---

## The Learning Path

The framework's **Core 16** operators are ordered for a learning path:

```
get data in → hold state → react in UI → shape streams → go async → combine sources
```

### Learning Path Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CELL FRAMEWORK LEARNING PATH                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                    │
│  │ GET DATA IN │ -> │ HOLD STATE  │ -> │ REACT IN UI │                    │
│  │             │    │             │    │             │                    │
│  │  • ingress  │    │  • state    │    │  • observe  │                    │
│  │  • open     │    │             │    │             │                    │
│  └─────────────┘    └─────────────┘    └─────────────┘                    │
│         │                  │                  │                           │
│         ▼                  ▼                  ▼                           │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                    │
│  │ SHAPE       │    │ GO ASYNC    │    │ COMBINE     │                    │
│  │ STREAMS     │    │             │    │ SOURCES     │                    │
│  │             │    │  • asyncMap │    │  • synthesis│                    │
│  │  • debounce │    │  • fromFut. │    │  • switchMap│                    │
│  │  • distinct │    │  • fromStr. │    │  • hub      │                    │
│  │             │    │             │    │             │                    │
│  └─────────────┘    └─────────────┘    └─────────────┘                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## The "Core 16" Essential Operators

### Quick Reference Card

| # | Operator | Category | Purpose |
|---|----------|----------|---------|
| 1 | `Cell.state` | Entry Point | Retained app state with `evolve` logic |
| 2 | `Cell.ingress` | Entry Point | Manual event entry for external signals |
| 3 | `Cell.open` | Entry Point | Manual control via explicit Receptor |
| 4 | `Cell.derive` | Transformation | Pure projections and view-models |
| 5 | `Cell.synthesis` | Transformation | Multi-source aggregation (Replaces `combineLatest`) |
| 6 | `Cell.sanitized` | Transformation | Data redaction and compliance masking |
| 7 | `Cell.asyncMap` | Transformation | Background tasks (HTTP/DB) with concurrency control |
| 8 | `Cell.switchMap` | Transformation | Dynamic source switching based on selection |
| 9 | `Cell.debounce` | Flow Control | Stability-based rate limiting (Search, Autosave) |
| 10 | `Cell.distinct` | Flow Control | Suppression of redundant consecutive updates |
| 11 | `Cell.observe` | Observation | Terminal side-effects (UI, Logging, Persistence) |
| 12 | `Cell.hub` | Routing | Semantic signal routing and event bus patterns |
| 13 | `Cell.fromFuture` | Bridge | Integration of one-time asynchronous results |
| 14 | `Cell.fromStream` | Bridge | Integration of continuous asynchronous streams |
| 15 | `Cell.transaction` | Orchestration | Atomic multi-participant updates |
| 16 | `Cell.txApply` | Orchestration | Batching multiple `apply()` calls into one commit |

---

## Common Patterns

### 1. Counter (Basic State)

```dart
final counter = Cell.state<int>(
  initial: 0,
  evolve: (host, input) {
    final delta = input.payload as int? ?? 1;
    return Pulse(host.value + delta);
  },
);

counter.update(1);  // Increment
counter.update(-1); // Decrement
```

### 2. Form Validation

```dart
// Individual form fields
final email = Cell.state<String>(
  initial: '',
  evolve: (host, input) => Pulse(input.payload as String? ?? ''),
);

final password = Cell.state<String>(
  initial: '',
  evolve: (host, input) => Pulse(input.payload as String? ?? ''),
);

// Validation logic
final isEmailValid = Cell.derive<String, bool>(
  bind: email.cell,
  project: (pulse) => Pulse(pulse.payload.contains('@')),
);

final isPasswordValid = Cell.derive<String, bool>(
  bind: password.cell,
  project: (pulse) => Pulse(pulse.payload.length >= 8),
);

// Combined validation
final formValid = Cell.synthesis<bool>(
  [isEmailValid, isPasswordValid],
  aggregator: (sources, pulse) {
    final emailOk = sources.elementAt(0).value as bool? ?? false;
    final passwordOk = sources.elementAt(1).value as bool? ?? false;
    return Pulse(emailOk && passwordOk);
  },
);
```

### 3. Search with Debounce

```dart
final searchInput = Cell.ingress<String>();

final debouncedSearch = Cell.debounce(
  searchInput.cell,
  Duration(milliseconds: 300),
);

final searchResults = Cell.asyncMap<String, List<Result>>(
  debouncedSearch,
  (query) => api.search(query),
  latestOnly: true,
);

Cell.observe(
  bind: searchResults,
  effect: (pulse) => updateUI(pulse.payload),
);
```

### 4. Command Router (Hub)

```dart
final commandHub = Cell.hub(
  routing: HubRouting.pattern,
  registrations: [
    (key: 'user.*', priority: 10, handler: userHandler),
    (key: 'user.login', priority: 20, handler: loginHandler),
    (key: 'admin.*', priority: 30, handler: adminHandler),
  ],
  fallback: 'unknown',
);

commandHub.emit(Pulse('data', type: 'user.login'));  // Goes to loginHandler
commandHub.emit(Pulse('data', type: 'user.logout')); // Goes to userHandler
commandHub.emit(Pulse('data', type: 'unknown'));     // Goes to fallback
```

### 5. Multi-Cell Transaction

```dart
final tx = Cell.transaction();

// Begin with participants
await tx.begin([accountA, accountB]);

// Read values
final a = tx.read(accountA) as int;
final b = tx.read(accountB) as int;

// Stage updates
tx.update(accountA, a - 50);
tx.update(accountB, b + 50);

// Commit atomically
await tx.commit();  // All or nothing
```

---

## Next Steps

### 1. Explore the How-To Guides

| Guide | Description |
|-------|-------------|
| [HowTo_Instruction.md](./HowTo_Instruction.md) | Using Instructions for data transformation |
| [HowTo_Receptor.md](./HowTo_Receptor.md) | Building transformation pipelines |
| [HowTo_TestCell.md](./HowTo_TestCell.md) | Validation and security |
| [HowTo_16_Essential_Operators.md](./HowTo_16_Essential_Operators.md) | 16 Essential Operators Reference |

### 2. Run the Examples

```bash
# Clone the repository
git clone https://github.com/your-repo/cell.git

# Run the examples
dart run example/instruction_pipeline_walkthrough.dart
dart run example/receptor_pipeline_walkthrough.dart
dart run example/hub_demo.dart
dart run example/throttle_demo.dart
```

### 3. Build Your First App

```dart
import 'package:cell/cell.dart';

class AppState {
  final counter = Cell.state<int>(
    initial: 0,
    evolve: (host, input) {
      final delta = input.payload as int? ?? 1;
      return Pulse(host.value + delta);
    },
  );

  final observer = Cell.observe<int>(
    bind: counter.cell,
    effect: (pulse) {
      print('Counter: ${pulse.payload}');
    },
  );

  void increment() => counter.update(1);
  void decrement() => counter.update(-1);
  void dispose() => observer.stop();
}

void main() {
  final app = AppState();
  app.increment();  // Counter: 1
  app.increment();  // Counter: 2
  app.decrement();  // Counter: 1
  app.dispose();
}
```

### 4. Understand the Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CELL FRAMEWORK ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         CELL                                        │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐ │   │
│  │  │  RECEPTOR   │  │  TESTCELL   │  │  CONTEXT    │  │ SYNAPSES  │ │   │
│  │  │             │  │             │  │             │  │           │ │   │
│  │  │ Transform   │  │ Validate    │  │ Security    │  │ Notify    │ │   │
│  │  │ Input       │  │ Input       │  │ Tier        │  │ Observers │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘ │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         PULSE                                       │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │   │
│  │  │  PAYLOAD    │  │  PROVENANCE │  │    TRACE    │                 │   │
│  │  │  Data       │  │  Who/Why    │  │  History    │                 │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Summary

### Key Takeaways

1. **Cells are reactive nodes** that hold state and notify observers
2. **Pulses are immutable signals** with causal tracing
3. **Receptors transform data** through pipelines
4. **TestCell validates** all operations
5. **Context defines** security and authority
6. **Synapses distribute** updates to observers
7. **Deputies are zero-copy proxies** with restricted permissions

### Quick Start Checklist

* Add `cell` to `pubspec.yaml`
* Import `package:cell/cell.dart`
* Create your first state cell
* Add an observer
* Add validation
* Create a derivative cell
* Add async operations
* Use transactions for atomic updates
* Create deputies for security

---

## Additional Resources

| Resource | Link |
|----------|------|
| API Documentation | https://pub.dev/documentation/cell |
| GitHub Repository | https://github.com/your-repo/cell |
| Examples | `/examples/` directory |
| Issue Tracker | https://github.com/your-repo/cell/issues |

---

## Support

If you have questions or need help:

1. Check the [How-To guides](./HowTo_Start.md)
2. Browse the [example/](./example/) directory
3. Open an issue on GitHub
4. Join the community discussion

---

**Happy coding with the Cell Framework!** 🚀