# How to Use Receptors in the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What is a Receptor?](#what-is-a-receptor)
3. [Core Concepts](#core-concepts)
4. [Creating Receptors](#creating-receptors)
5. [Receptor Pipelines](#receptor-pipelines)
6. [Asynchronous Processing](#asynchronous-processing)
7. [Testing Receptors](#testing-receptors)
8. [Error Handling](#error-handling)
9. [Best Practices](#best-practices)
10. [Complete Example](#complete-example)

---

## Introduction

A **Receptor** is the transformation pipeline that defines how a `Cell` responds to incoming `Pulse` signals. It is the **brain** of a cell—determining what happens when data arrives.

### When to Use Receptors

- **Data Transformation** - Convert incoming data to a different format
- **Validation** - Validate data before it enters the cell
- **Filtering** - Drop unwanted signals
- **Enrichment** - Add additional data to the payload
- **Side Effects** - Logging, auditing, or triggering external systems
- **Type Conversion** - Bridge between different pulse types

---

## What is a Receptor?

A `Receptor` is a functional wrapper around one or more `Instruction` objects. It defines a **processing pipeline** that executes in a specific order.

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Stateless** | Receptors are blueprints, not state holders |
| **Composable** | Multiple instructions can be chained |
| **Type-Safe** | Strong typing with generic parameters |
| **Async Support** | Built-in asynchronous execution |
| **Resilient** | Safety boundaries at every stage |
| **Governed** | Can be subject to architectural policies |

### Type Parameters

```dart
Receptor<C extends Cell>
```

| Parameter | Description |
|-----------|-------------|
| `C` | The type of the host `Cell` |

---

## Core Concepts

### 1. Receptors are Stateless Templates

A receptor is a **blueprint** that becomes active only when bound to a cell.

```dart
// Receptor as a template
final receptor = Receptor((cell, pulse, {user}) => pulse);

// Activate by binding to a cell
final cell = Cell(receptor: receptor);
```

### 2. Receptors Execute in Stages

The `Receptor.pipeline` factory organizes logic into three stages:

```
Pre-Process → Core Logic → Post-Process
   ↓             ↓             ↓
Sanitization  Business    Commitment/
              Logic       Validation
```

### 3. Receptors Can Be Cloned

```dart
final original = Receptor((cell, pulse, {user}) => pulse);
final clone = original.clone;  // Independent copy
```

### 4. Receptors Support Async

```dart
await receptor.async.call(pulse, serializedCompletion: true);
```

---

## Creating Receptors

### Method 1: Using the Primary Constructor (Simple)

```dart
Receptor<Cell> createDoublerReceptor() {
  return Receptor(
    (cell, pulse, {user}) {
      final value = pulse.payload as int?;
      if (value == null) return null;
      return Pulse(value * 2);
    },
  );
}
```

### Method 2: Using Instructions (Reusable)

```dart
// Define an instruction
final sanitizeInstruction = Instruction<Cell, Pulse, Pulse>(
  (pulse, {cell, user}) {
    final data = pulse.payload as String?;
    return Pulse(data?.trim() ?? '');
  },
);

// Create a receptor from the instruction
final receptor = Receptor.instruction(sanitizeInstruction);
```

### Method 3: Multi-Stage Pipeline

```dart
final receptor = Receptor.pipeline(
  preProcess: Instruction((p, {cell, user}) => Pulse(p.payload.trim())),
  instruction: Instruction((p, {cell, user}) => Pulse(p.payload.toUpperCase())),
  postProcess: Instruction((p, {cell, user}) => p.payload.length > 0 ? p : null),
);
```

### Method 4: Type-Safe Receptor

```dart
final lengthReceptor = Receptor.typed<Cell, Pulse<String>, Pulse<int>>(
  Instruction<Cell, Pulse<String>, Pulse<int>>(
    (pulse, {cell, user}) => Pulse(pulse.payload.length),
  ),
);
```

### Method 5: Pass-Through (Default)

```dart
final receptor = Receptor.passThrough;
// Or simply omit the receptor parameter when creating a cell
final cell = Cell();  // Uses pass-through by default
```

---

## Receptor Pipelines

### Pipeline Structure

A `Receptor.pipeline` has three optional stages:

```dart
Receptor.pipeline(
  preProcess: instruction1,   // Sanitization
  instruction: instruction2,  // Core logic
  postProcess: instruction3,  // Commitment/validation
);
```

### Complete Pipeline Example

```dart
// 1. Define instructions
final sanitize = Instruction<Cell, Pulse, Pulse>(
  (p, {cell, user}) => Pulse(p.payload.trim()),
);

final validate = Instruction<Cell, Pulse, Pulse>(
  (p, {cell, user}) {
    final text = p.payload as String?;
    return text != null && text.isNotEmpty ? p : null;
  },
);

final format = Instruction<Cell, Pulse, Pulse>(
  (p, {cell, user}) => Pulse('Processed: ${p.payload}'),
);

// 2. Build pipeline
final pipeline = Receptor.pipeline(
  preProcess: sanitize,
  instruction: validate,
  postProcess: format,
);

// 3. Create cell with pipeline
final cell = Cell(receptor: pipeline);
```

### Chaining Instructions

Instructions can be chained using the `+` operator:

```dart
// These are equivalent:
final pipeline1 = sanitize + validate + format;
final pipeline2 = Instruction.chain([sanitize, validate, format]);

// Both create a single instruction that executes in order
```

### Pipeline Short-Circuiting

If any stage returns `null`, the pipeline stops immediately:

```dart
// If validate returns null, format is NEVER called
final pipeline = sanitize + validate + format;
//          ↑           ↑           ↑
//      runs        if passes    runs
```

---

## Asynchronous Processing

### Using ReceptorAsync

```dart
final receptor = Receptor((cell, pulse, {user}) {
  // Synchronous logic
  return Pulse(process(pulse.payload));
});

// Async execution
await receptor.async.call(pulse);
```

### Waiting for Full Propagation

```dart
// Waits for entire reactive graph to settle
await receptor.async.call(
  pulse,
  serializedCompletion: true,
);
```

### Fire-and-Forget

```dart
// Returns immediately after queueing
receptor.async.call(
  pulse,
  serializedCompletion: false,
);
```

### Testing Hook

```dart
await receptor.async.call(
  pulse,
  hook: ({result, input}) {
    print('Input: ${input.payload}');
    print('Result: ${result?.payload}');
  },
);
```

### Asynchronous Instruction

Instructions can be async using `Instruction.future`:

```dart
final fetchInstruction = Instruction<Cell, Pulse, Pulse>.future(
  (pulse, {cell, future, token, user}) {
    final id = pulse.payload as String?;
    if (id == null) return null;
    
    fetchFromDatabase(id).then((data) {
      future?.call(
        result: Pulse(data),
        token: token,
      );
    });
    
    return null;  // Return immediately, continue later
  },
);

final receptor = Receptor.instruction(fetchInstruction);
```

---

## Testing Receptors

### Unit Testing a Receptor

```dart
import 'package:test/test.dart';

void main() {
  test('Doubler receptor doubles integer payload', () {
    final receptor = Receptor((cell, pulse, {user}) {
      final value = pulse.payload as int;
      return Pulse(value * 2);
    });
    
    final input = Pulse(5);
    final result = receptor.call(input);
    
    expect(result, isNotNull);
    expect((result as Pulse).payload, 10);
  });
  
  test('Validator receptor filters invalid data', () {
    final receptor = Receptor((cell, pulse, {user}) {
      final text = pulse.payload as String?;
      return text != null && text.isNotEmpty ? pulse : null;
    });
    
    final valid = Pulse('hello');
    expect(receptor.call(valid), isNotNull);
    
    final invalid = Pulse('');
    expect(receptor.call(invalid), isNull);
  });
}
```

### Testing a Pipeline

```dart
test('Pipeline processes data correctly', () {
  final sanitize = Instruction((p, {cell, user}) => Pulse(p.payload.trim()));
  final validate = Instruction((p, {cell, user}) {
    final text = p.payload as String?;
    return text != null && text.isNotEmpty ? p : null;
  });
  final format = Instruction((p, {cell, user}) => Pulse('Result: ${p.payload}'));
  
  final pipeline = sanitize + validate + format;
  
  final result = pipeline.call(Pulse('  hello  '));
  
  expect(result, isNotNull);
  expect((result as Pulse).payload, 'Result: hello');
});
```

### Testing Async Receptors

```dart
test('Async receptor processes with delay', () async {
  final receptor = Receptor((cell, pulse, {user}) {
    final value = pulse.payload as int;
    return Pulse(value * 2);
  });
  
  final result = await receptor.async.call(Pulse(5));
  
  expect(result, isNotNull);
  expect((result as Pulse).payload, 10);
});

test('Async receptor waits for completion', () async {
  final receptor = Receptor((cell, pulse, {user}) {
    return Pulse(pulse.payload);
  });
  
  // Waits for full graph propagation
  await receptor.async.call(
    Pulse('test'),
    serializedCompletion: true,
  );
});
```

### Testing with Mock Cells

```dart
class MockCell extends CellBase {
  MockCell() : super(receptor: Receptor.passThrough);
}

test('Receptor with mock cell', () {
  final receptor = Receptor((cell, pulse, {user}) {
    // Access cell context
    print('Processing in ${cell.runtimeType}');
    return pulse;
  });
  
  final mockCell = MockCell();
  receptor.activate(mockCell);
  
  final result = receptor.call(Pulse('test'));
  expect(result, isNotNull);
});
```

---

## Error Handling

### 1. Returning null (Filtering)

```dart
final positiveFilter = Receptor((cell, pulse, {user}) {
  final value = pulse.payload as int?;
  if (value == null || value <= 0) {
    print('Filtered: $value');
    return null;  // Drop the signal
  }
  return pulse;
});
```

### 2. Throwing Exceptions

```dart
final strictValidator = Receptor((cell, pulse, {user}) {
  final data = pulse.payload as Map<String, dynamic>?;
  if (data == null) {
    throw ArgumentError('Payload cannot be null');
  }
  if (!data.containsKey('id')) {
    throw StateError('Missing required field: id');
  }
  return pulse;
});
```

### 3. Recovery Pattern

```dart
final recoveryReceptor = Receptor((cell, pulse, {user}) {
  try {
    final data = pulse.payload as Map<String, dynamic>?;
    if (data == null) return null;
    
    // Process data...
    return Pulse(processed);
  } catch (e) {
    print('Error: $e, returning original pulse');
    return pulse;  // Recovery: return original
  }
});
```

### 4. Error Metadata

```dart
final errorHandlingReceptor = Receptor((cell, pulse, {user}) {
  try {
    final data = pulse.payload as Map<String, dynamic>?;
    if (data == null) {
      throw ArgumentError('Invalid data');
    }
    return Pulse(process(data));
  } catch (e) {
    // Add error info to the pulse
    final errorData = {'error': e.toString(), 'original': pulse.payload};
    return Pulse(errorData);
  }
});
```

---

## Best Practices

### 1. Keep Receptors Focused

Each receptor should handle one specific transformation:

```dart
// ✅ GOOD - Single responsibility
final validateReceptor = Receptor((cell, pulse, {user}) => validate(pulse));
final enrichReceptor = Receptor((cell, pulse, {user}) => enrich(pulse));
final formatReceptor = Receptor((cell, pulse, {user}) => format(pulse));

// ❌ BAD - Multiple responsibilities
final allInOneReceptor = Receptor((cell, pulse, {user}) {
  validate(pulse);
  enrich(pulse);
  format(pulse);
  return pulse;
});
```

### 2. Use Instructions for Reusability

```dart
// ✅ GOOD - Reusable instructions
final sanitize = sanitizeInstruction();
final validate = validateInstruction();
final receptor = Receptor.instruction(sanitize + validate);

// ❌ BAD - Inline logic not reusable
final receptor = Receptor((cell, pulse, {user}) {
  // Duplicate this logic elsewhere
  final sanitized = sanitize(pulse);
  return validate(sanitized);
});
```

### 3. Document Your Receptors

```dart
/// Validates incoming document pulses.
/// 
/// Checks:
/// - Document ID is not empty
/// - Document size is within limits
/// - Document type is allowed
/// 
/// Returns null if validation fails.
Receptor<Cell> createDocumentValidatorReceptor() {
  return Receptor((cell, pulse, {user}) {
    // ...
  });
}
```

### 4. Use Type Safety

```dart
// ✅ GOOD - Type-safe
final lengthReceptor = Receptor.typed<Cell, Pulse<String>, Pulse<int>>(
  Instruction((p, {cell, user}) => Pulse(p.payload.length)),
);

// ❌ BAD - Loose typing
final lengthReceptor = Receptor((cell, pulse, {user}) {
  final text = pulse.payload as String;  // Runtime cast
  return Pulse(text.length);
});
```

### 5. Handle Null Payloads Gracefully

```dart
final safeReceptor = Receptor((cell, pulse, {user}) {
  if (pulse.payload == null) {
    print('Null payload received');
    return null;
  }
  // Process non-null payload
  return Pulse(process(pulse.payload));
});
```

### 6. Use Async for I/O Operations

```dart
// ✅ GOOD - Async for I/O
final dbReceptor = Receptor((cell, pulse, {user}) {
  // Use Instruction.future for database operations
  return Instruction.future(...);
});

// ❌ BAD - Blocking I/O
final dbReceptor = Receptor((cell, pulse, {user}) {
  final data = database.querySync(pulse.payload);  // Blocks
  return Pulse(data);
});
```

### 7. Log Transformation Steps

```dart
final loggingReceptor = Receptor((cell, pulse, {user}) {
  print('Input: ${pulse.payload}');
  final result = process(pulse.payload);
  print('Output: $result');
  return Pulse(result);
});
```

---

## Complete Example

Here's a complete document processing system using Receptors:

```dart
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────
// Domain Models
// ─────────────────────────────────────────────────────────────

class Document {
  final String id;
  final String title;
  final String type;
  final double size;
  final String status;
  final String? route;

  Document({
    required this.id,
    required this.title,
    required this.type,
    required this.size,
    this.status = 'pending',
    this.route,
  });

  Document copyWith({String? status, String? route, String? title}) {
    return Document(
      id: id,
      title: title ?? this.title,
      type: type,
      size: size,
      status: status ?? this.status,
      route: route ?? this.route,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Instructions
// ─────────────────────────────────────────────────────────────

Instruction<Cell, Pulse, Pulse> sanitizeDocument() {
  return Instruction((pulse, {cell, user}) {
    final doc = pulse.payload as Document?;
    if (doc == null) return null;
    
    final sanitized = doc.copyWith(
      title: doc.title.trim(),
    );
    
    return Pulse(sanitized);
  });
}

Instruction<Cell, Pulse, Pulse> validateDocument() {
  return Instruction((pulse, {cell, user}) {
    final doc = pulse.payload as Document?;
    if (doc == null) return null;
    
    if (doc.title.isEmpty) {
      print('Validation failed: Empty title');
      return null;
    }
    
    if (doc.size <= 0) {
      print('Validation failed: Invalid size');
      return null;
    }
    
    return pulse;
  });
}

Instruction<Cell, Pulse, Pulse> enrichDocument() {
  return Instruction((pulse, {cell, user}) {
    final doc = pulse.payload as Document?;
    if (doc == null) return null;
    
    String route;
    switch (doc.type) {
      case 'proposal':
        route = 'management-review';
        break;
      case 'invoice':
        route = 'finance-approval';
        break;
      default:
        route = 'general-queue';
    }
    
    final enriched = doc.copyWith(
      status: 'enriched',
      route: route,
    );
    
    print('Document routed to: $route');
    return Pulse(enriched);
  });
}

Instruction<Cell, Pulse, Pulse> logDocument() {
  return Instruction((pulse, {cell, user}) {
    final doc = pulse.payload as Document?;
    if (doc == null) return null;
    
    print('Document ${doc.id} processed');
    print('  Status: ${doc.status}');
    print('  Route: ${doc.route ?? 'none'}');
    
    return pulse;
  });
}

// ─────────────────────────────────────────────────────────────
// Receptors
// ─────────────────────────────────────────────────────────────

Receptor<Cell> createDocumentProcessingReceptor() {
  // Build pipeline with preProcess, instruction, and postProcess
  return Receptor.pipeline(
    preProcess: sanitizeDocument(),
    instruction: validateDocument(),
    postProcess: enrichDocument() + logDocument(),
  );
}

Receptor<Cell> createSimpleDocumentReceptor() {
  // Simple single-stage receptor
  return Receptor.instruction(sanitizeDocument() + validateDocument());
}

Receptor<Cell> createAsyncDocumentReceptor() {
  // Async receptor with future support
  final asyncInstruction = Instruction<Cell, Pulse, Pulse>.future(
    (pulse, {cell, future, token, user}) {
      final doc = pulse.payload as Document?;
      if (doc == null) return null;
      
      // Simulate async processing
      Timer(Duration(seconds: 1), () {
        final processed = doc.copyWith(status: 'async-processed');
        future?.call(result: Pulse(processed), token: token);
      });
      
      return null;
    },
  );
  
  return Receptor.instruction(asyncInstruction);
}

// ─────────────────────────────────────────────────────────────
// Usage
// ─────────────────────────────────────────────────────────────

void main() async {
  // 1. Create receptor
  final receptor = createDocumentProcessingReceptor();
  
  // 2. Create cell with receptor
  final cell = Cell(
    receptor: receptor,
    context: Context.module('document-processing'),
  );
  
  // 3. Process a document
  final doc = Document(
    id: 'DOC-001',
    title: '  Project Proposal  ',
    type: 'proposal',
    size: 2.5,
  );
  
  // Sync processing
  final result = cell._nucleus.receptor.call(Pulse(doc));
  if (result != null && result.payload is Document) {
    final processed = result.payload as Document;
    print('Result: ${processed.status}, ${processed.route}');
  }
  
  // Async processing
  final asyncResult = await cell.async.call(Pulse(doc));
  if (asyncResult != null && asyncResult.payload is Document) {
    final processed = asyncResult.payload as Document;
    print('Async result: ${processed.status}');
  }
}
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **Receptor** | Transformation pipeline for a cell |
| **Instruction** | Reusable logic unit |
| **Pipeline** | Chain of instructions using `+` |
| **preProcess** | Sanitization stage |
| **instruction** | Core logic stage |
| **postProcess** | Commitment/validation stage |
| **async** | Asynchronous execution adapter |
| **clone** | Creates independent copy |

### Key Rules

1. **Receptors are stateless** - They are blueprints, not state holders
2. **Use instructions for reusability** - Encapsulate logic in instructions
3. **Return null to filter** - Stops the pipeline
4. **Use async for I/O** - Non-blocking operations
5. **Test in isolation** - Unit test each receptor
6. **Document your receptors** - Explain what they do

### Common Patterns

```dart
// Pattern: Simple transformation
final receptor = Receptor((cell, pulse, {user}) => Pulse(transform(pulse.payload)));

// Pattern: Validation pipeline
final receptor = Receptor.instruction(validate + process);

// Pattern: Three-stage pipeline
final receptor = Receptor.pipeline(
  preProcess: sanitize,
  instruction: process,
  postProcess: validate,
);

// Pattern: Async processing
final receptor = Receptor.instruction(Instruction.future(...));
```