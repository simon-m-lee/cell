# How to Use Instructions in the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What is an Instruction?](#what-is-an-instruction)
3. [Core Concepts](#core-concepts)
4. [Creating Instructions](#creating-instructions)
5. [Composing Pipelines](#composing-pipelines)
6. [Using Instructions with Receptors](#using-instructions-with-receptors)
7. [Asynchronous Instructions](#asynchronous-instructions)
8. [Testing Instructions](#testing-instructions)
9. [Error Handling](#error-handling)
10. [Best Practices](#best-practices)
11. [Complete Example](#complete-example)

---

## Introduction

Instructions are the fundamental building blocks for data transformation in the Cell Framework. They represent **reusable, composable units of logic** that process pulses through a reactive graph. Think of them as **pipeline stages** that transform data as it flows from one cell to another.

### When to Use Instructions

- **Data Validation** - Validate incoming data before processing
- **Data Transformation** - Convert data from one format to another
- **Data Enrichment** - Add additional data to existing payloads
- **Filtering** - Drop unwanted pulses
- **Logging** - Audit trail for debugging
- **Sanitization** - Clean and normalize data

---

## What is an Instruction?

An `Instruction` is a **stateless transformation unit** that takes a `Pulse` as input and returns either:
- A **new Pulse** (for successful transformation)
- `null` (to terminate/filter the signal)

### Type Parameters

```dart
Instruction<C extends Cell, I extends Pulse, O extends Pulse>
```

| Parameter | Description |
|-----------|-------------|
| `C` | The type of the host `Cell` (usually `Cell`) |
| `I` | The type of the input `Pulse` (usually `Pulse`) |
| `O` | The type of the output `Pulse` (usually `Pulse`) |

For most cases, you'll use `Instruction<Cell, Pulse, Pulse>`.

---

## Core Concepts

### 1. Pulses are Immutable

Instructions **never modify** the input pulse. They always create and return a **new pulse** with the transformed data.

```dart
// ❌ WRONG - Modifies input
static Pulse? _process(Pulse pulse) {
  pulse.payload = newData;  // NO - Pulse is immutable!
  return pulse;
}

// ✅ CORRECT - Returns new pulse
static Pulse? _process(Pulse pulse) {
  final newData = transform(pulse.payload);
  return Pulse(newData);  // Returns a NEW pulse
}
```

### 2. Instructions are Stateless

Instructions should not hold internal state. All state should be managed by the surrounding `Cell` or passed through the pulse.

```dart
// ❌ WRONG - Holds state
class CounterInstruction extends InstructionBase {
  int _count = 0;  // NO - Instructions should be stateless!
  // ...
}

// ✅ CORRECT - Stateless
Instruction<Cell, Pulse, Pulse> counterInstruction() {
  return Instruction((pulse, {cell, user}) {
    // All state is in the pulse
    final count = pulse.payload as int? ?? 0;
    return Pulse(count + 1);
  });
}
```

### 3. Instructions are Composable

Instructions can be chained together using the `+` operator to create complex pipelines.

```dart
final pipeline = sanitize + validate + enrich + format;
```

---

## Creating Instructions

### Method 1: Using the Primary Constructor (Recommended)

This is the simplest way to create an instruction.

```dart
Instruction<Cell, Pulse, Pulse> sanitizeInstruction() {
  return Instruction<Cell, Pulse, Pulse>(
    (pulse, {cell, user}) {
      final data = pulse.payload as Map<String, dynamic>?;
      if (data == null) {
        print('No data to sanitize');
        return null;  // Terminate the signal
      }
      
      // Transform the data
      final sanitized = _sanitizeData(data);
      
      // Return a new pulse
      return Pulse(sanitized);
    },
  );
}
```

### Method 2: Using a Static Function

```dart
class SanitizeInstruction {
  static Pulse? process(Pulse pulse, {Cell? cell, dynamic user}) {
    final data = pulse.payload as Map<String, dynamic>?;
    if (data == null) return null;
    
    final sanitized = _sanitizeData(data);
    return Pulse(sanitized);
  }
  
  static Instruction<Cell, Pulse, Pulse> create() {
    return Instruction<Cell, Pulse, Pulse>(process);
  }
}
```

### Method 3: With User Data

```dart
Instruction<Cell, Pulse, Pulse> thresholdInstruction({required int limit}) {
  return Instruction<Cell, Pulse, Pulse>(
    (pulse, {cell, user}) {
      final value = pulse.payload as int? ?? 0;
      if (value > limit) {
        return Pulse(value);  // Pass through
      }
      return null;  // Filter out
    },
    user: limit,  // Pass configuration
  );
}
```

---

## Composing Pipelines

### Using the `+` Operator

The `+` operator chains instructions sequentially:

```dart
final sanitize = sanitizeInstruction();
final validate = validateInstruction();
final enrich = enrichInstruction();

// Pipeline: sanitize → validate → enrich
final pipeline = sanitize + validate + enrich;
```

### Execution Order

Instructions are executed **left to right**:

```dart
// Step 1: sanitize runs first
// Step 2: validate runs with sanitize's output
// Step 3: enrich runs with validate's output
final pipeline = sanitize + validate + enrich;
```

### Short-Circuiting

If any instruction returns `null`, the pipeline stops immediately:

```dart
// If validate returns null, enrich is NEVER called
final pipeline = sanitize + validate + enrich;
//          ↑           ↑           ↑
//      runs        if passes    runs
```

### Complex Pipelines

```dart
// Multi-stage pipeline with grouping
final validationPipeline = validateEmail + validatePhone + validateAddress;
final enrichmentPipeline = enrichCustomer + enrichPricing + enrichShipping;
final fullPipeline = sanitize + validationPipeline + enrichmentPipeline + format + log;
```

---

## Using Instructions with Receptors

### Creating a Receptor from an Instruction

```dart
final instruction = sanitizeInstruction();
final receptor = Receptor.instruction(instruction);
```

### Creating a Multi-Stage Receptor

```dart
final receptor = Receptor.pipeline(
  preProcess: sanitizeInstruction(),
  instruction: validateInstruction() + processInstruction(),
  postProcess: enrichInstruction(),
);
```

### Using a Receptor in a Cell

```dart
final receptor = Receptor.instruction(sanitizeInstruction());
final cell = Cell(
  receptor: receptor,
  context: Context.module('data-processing'),
);
```

### Complete Example

```dart
// 1. Create instructions
final sanitize = sanitizeInstruction();
final validate = validateInstruction();
final process = processInstruction();
final log = logInstruction();

// 2. Build pipeline
final pipeline = sanitize + validate + process + log;

// 3. Create receptor
final receptor = Receptor.instruction(pipeline);

// 4. Create cell
final cell = Cell(
  receptor: receptor,
  context: Context.module('order-processing'),
);

// 5. Process data
final result = cell._nucleus.receptor.call(Pulse(rawData));
```

---

## Asynchronous Instructions

### Creating Async Instructions

Use `Instruction.future()` for async operations:

```dart
Instruction<Cell, Pulse, Pulse> fetchCustomerData() {
  return Instruction<Cell, Pulse, Pulse>.future(
    (pulse, {cell, future, token, user}) {
      final customerId = pulse.payload as String?;
      if (customerId == null) return null;
      
      // Async operation
      fetchFromDatabase(customerId).then((data) {
        // Continue the pipeline with the result
        future?.call(
          result: Pulse(data),
          token: token,
        );
      });
      
      return null;  // Return immediately, continue later
    },
  );
}
```

### Async Pipeline Example

```dart
final pipeline = validate + fetchCustomerData + enrich + format;
```

### Waiting for Completion

```dart
final result = await pipeline.call(Pulse(customerId));
```

### Combining Sync and Async

Sync and async instructions can be freely mixed:

```dart
// Sync → Async → Sync
final pipeline = validate + fetchData + format + log;
//        ↑          ↑          ↑        ↑
//     sync      async      sync     sync
```

---

## Testing Instructions

### Unit Testing Individual Instructions

```dart
import 'package:test/test.dart';

void main() {
  test('SanitizeInstruction handles valid data', () {
    final instruction = sanitizeInstruction();
    final input = Pulse({
      'id': 'ORD-123',
      'customer': '  John Doe  ',
      'email': 'JOHN@EXAMPLE.COM',
      'items': '2',
      'total': '99.99',
    });
    
    final result = instruction.call(input);
    
    expect(result, isNotNull);
    final data = result!.payload as Map<String, dynamic>;
    expect(data['customer'], 'John Doe');
    expect(data['email'], 'john@example.com');
    expect(data['items'], 2);
    expect(data['total'], 99.99);
  });
  
  test('SanitizeInstruction handles invalid data', () {
    final instruction = sanitizeInstruction();
    final input = Pulse({
      'id': '',
      'customer': '  John Doe  ',
      'email': 'john@example.com',
    });
    
    final result = instruction.call(input);
    expect(result, isNull);  // Invalid data should return null
  });
}
```

### Testing Pipelines

```dart
test('Full pipeline processes order correctly', () {
  final pipeline = sanitize + validate + enrich + format + log;
  final input = Pulse(rawOrderData);
  
  final result = pipeline.call(input);
  
  expect(result, isNotNull);
  expect(result!.payload, isA<Order>());
  final order = result.payload as Order;
  expect(order.status, 'ready');
  expect(order.customer.isVip, true);
});
```

### Testing with Mock Data

```dart
test('Async instruction handles network errors', () async {
  final instruction = fetchCustomerData();
  final completer = Completer<Pulse?>();
  
  instruction.call(
    Pulse('invalid-id'),
    future: ({result, token}) {
      completer.complete(result);
    },
  );
  
  final result = await completer.future;
  expect(result, isNull);  // Error should return null
});
```

---

## Error Handling

### 1. Returning null (Filtering)

```dart
Instruction<Cell, Pulse, Pulse> positiveNumberFilter() {
  return Instruction((pulse, {cell, user}) {
    final value = pulse.payload as int?;
    if (value == null || value <= 0) {
      print('Negative/zero value filtered: $value');
      return null;  // Drop the pulse
    }
    return pulse;
  });
}
```

### 2. Throwing Exceptions

```dart
Instruction<Cell, Pulse, Pulse> strictValidation() {
  return Instruction((pulse, {cell, user}) {
    final data = pulse.payload as Map<String, dynamic>?;
    if (data == null) {
      throw ArgumentError('Data cannot be null');
    }
    if (!data.containsKey('id')) {
      throw StateError('Missing required field: id');
    }
    return pulse;
  });
}
```

### 3. Recovery Instructions

```dart
Instruction<Cell, Pulse, Pulse> recoveryInstruction() {
  return Instruction((pulse, {cell, user}) {
    final data = pulse.payload as Map<String, dynamic>?;
    if (data == null) return null;
    
    // Recover from invalid data
    final recovered = Map<String, dynamic>.from(data);
    if ((recovered['name']?.toString().trim() ?? '').isEmpty) {
      recovered['name'] = 'Unknown';
    }
    if ((recovered['email']?.toString().trim() ?? '').isEmpty) {
      recovered['email'] = 'unknown@example.com';
    }
    
    return Pulse(recovered);
  });
}
```

---

## Best Practices

### 1. Keep Instructions Focused

Each instruction should do **one thing** and do it well:

```dart
// ✅ GOOD - Single responsibility
final validateEmail = validateEmailInstruction();
final validatePhone = validatePhoneInstruction();
final validateAddress = validateAddressInstruction();
final validationPipeline = validateEmail + validatePhone + validateAddress;

// ❌ BAD - Multiple responsibilities
final validateAll = Instruction((pulse, {cell, user}) {
  // Validates email, phone, AND address
  // Too much logic in one instruction
});
```

### 2. Use Descriptive Names

```dart
// ✅ GOOD
final sanitizeCustomerData = sanitizeCustomerInstruction();
final validateOrderTotal = validateTotalInstruction();

// ❌ BAD
final step1 = step1Instruction();
final step2 = step2Instruction();
```

### 3. Document Your Instructions

```dart
/// Sanitizes customer data by:
/// - Trimming whitespace from all string fields
/// - Converting email to lowercase
/// - Removing null values from metadata
/// - Returns null if customer ID is missing
Instruction<Cell, Pulse, Pulse> sanitizeCustomerInstruction() {
  return Instruction((pulse, {cell, user}) {
    // ...
  });
}
```

### 4. Return New Pulses, Don't Modify Input

```dart
// ✅ GOOD
return Pulse(newData);

// ❌ BAD
final data = pulse.payload as Map<String, dynamic>;
data['key'] = 'value';  // Modifies input!
return pulse;
```

### 5. Handle Null Payloads Gracefully

```dart
Instruction<Cell, Pulse, Pulse> safeTransformer() {
  return Instruction((pulse, {cell, user}) {
    final data = pulse.payload as Map<String, dynamic>?;
    if (data == null) {
      print('Null payload received, filtering');
      return null;  // Filter out null payloads
    }
    // Process data...
    return Pulse(transformed);
  });
}
```

### 6. Use Type Safety

```dart
// ✅ GOOD - Type-safe
Instruction<Cell, Pulse<String>, Pulse<int>> lengthTransformer() {
  return Instruction<Cell, Pulse<String>, Pulse<int>>(
    (pulse, {cell, user}) {
      final text = pulse.payload;
      return Pulse(text.length);
    },
  );
}
```

### 7. Log Transformation Steps (for Debugging)

```dart
Instruction<Cell, Pulse, Pulse> loggingInstruction(String name) {
  return Instruction((pulse, {cell, user}) {
    print('[$name] Input: ${pulse.payload}');
    // Process...
    print('[$name] Output: $result');
    return Pulse(result);
  });
}
```

---

## Complete Example

Here's a complete e-commerce order processing pipeline:

```dart
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────
// Instructions
// ─────────────────────────────────────────────────────────────

/// Sanitize raw order data
Instruction<Cell, Pulse, Pulse> sanitizeOrder() {
  return Instruction((pulse, {cell, user}) {
    final raw = pulse.payload as Map<String, dynamic>?;
    if (raw == null) return null;
    
    final sanitized = <String, dynamic>{}
      ..['id'] = raw['id']?.toString().trim()
      ..['customer'] = raw['customer']?.toString().trim() ?? ''
      ..['email'] = raw['email']?.toString().trim().toLowerCase() ?? ''
      ..['items'] = int.tryParse(raw['items']?.toString() ?? '0') ?? 0
      ..['total'] = double.tryParse(raw['total']?.toString() ?? '0.0') ?? 0.0
      ..['status'] = raw['status']?.toString() ?? 'pending';
    
    if ((sanitized['id'] as String?)?.isEmpty ?? true) {
      return null;  // Invalid ID
    }
    
    return Pulse(sanitized);
  });
}

/// Validate order data
Instruction<Cell, Pulse, Pulse> validateOrder() {
  return Instruction((pulse, {cell, user}) {
    final data = pulse.payload as Map<String, dynamic>?;
    if (data == null) return null;
    
    final errors = <String>[];
    if ((data['customer'] as String?)?.isEmpty ?? true) {
      errors.add('Customer name is required');
    }
    final email = data['email'] as String? ?? '';
    if (!email.contains('@') || !email.contains('.')) {
      errors.add('Invalid email format');
    }
    if ((data['items'] as int? ?? 0) < 0) {
      errors.add('Items cannot be negative');
    }
    if ((data['total'] as double? ?? 0.0) < 0) {
      errors.add('Total cannot be negative');
    }
    
    if (errors.isNotEmpty) {
      print('Validation failed: ${errors.join('; ')}');
      return null;
    }
    
    return pulse;
  });
}

/// Apply discount based on customer tier
Instruction<Cell, Pulse, Pulse> applyDiscount() {
  return Instruction((pulse, {cell, user}) {
    final data = pulse.payload as Map<String, dynamic>?;
    if (data == null) return null;
    
    final email = data['email'] as String? ?? '';
    final total = data['total'] as double? ?? 0.0;
    
    double discount = 0.0;
    if (email == 'vip@example.com') {
      discount = total * 0.10;
      print('Applied 10% VIP discount');
    }
    
    final enriched = Map<String, dynamic>.from(data)
      ..['discount'] = discount
      ..['finalTotal'] = total - discount;
    
    return Pulse(enriched);
  });
}

/// Format order as Order object
Instruction<Cell, Pulse, Pulse> formatOrder() {
  return Instruction((pulse, {cell, user}) {
    final data = pulse.payload as Map<String, dynamic>?;
    if (data == null) return null;
    
    final order = Order(
      id: data['id'] as String? ?? 'UNKNOWN',
      customer: data['customer'] as String? ?? 'Unknown',
      email: data['email'] as String? ?? '',
      items: data['items'] as int? ?? 0,
      total: data['finalTotal'] as double? ?? 0.0,
      discount: data['discount'] as double? ?? 0.0,
      status: 'ready',
      processedAt: DateTime.now(),
    );
    
    return Pulse(order);
  });
}

// ─────────────────────────────────────────────────────────────
// Usage
// ─────────────────────────────────────────────────────────────

void main() {
  // 1. Create pipeline
  final pipeline = sanitizeOrder() + validateOrder() + applyDiscount() + formatOrder();
  
  // 2. Create receptor
  final receptor = Receptor.instruction(pipeline);
  
  // 3. Create cell
  final cell = Cell(
    receptor: receptor,
    context: Context.module('order-processing'),
  );
  
  // 4. Process order
  final rawOrder = {
    'id': 'ORD-123',
    'customer': '  John Doe  ',
    'email': 'vip@example.com',
    'items': '2',
    'total': '99.99',
    'status': 'pending',
  };
  
  final result = cell._nucleus.receptor.call(Pulse(rawOrder));
  
  if (result != null && result.payload is Order) {
    final order = result.payload as Order;
    print('Order processed: ${order.id}');
    print('Final total: \$${order.total}');
    print('Discount: \$${order.discount}');
  }
}
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **Instruction** | Reusable unit of logic that transforms pulses |
| **Pipeline** | Chain of instructions using `+` operator |
| **Receptor** | Container that executes instructions |
| **Cell** | Reactive node that uses receptors |
| **Pulse** | Immutable signal carrying data |

### Key Rules

1. **Always return a new pulse** - never modify input
2. **Return null to filter** - stops the pipeline
3. **Keep instructions focused** - one responsibility per instruction
4. **Test instructions in isolation** - unit test each one
5. **Use async for I/O** - use `Instruction.future()` for async operations
6. **Document your instructions** - explain what they do

### Common Patterns

```dart
// Pattern: Filter + Transform + Filter
final pipeline = filterEmpty + transform + filterNegative;

// Pattern: Validate + Enrich + Format
final pipeline = validate + enrich + format;

// Pattern: PreProcess + Core + PostProcess (Receptor)
final receptor = Receptor.pipeline(
  preProcess: sanitize,
  instruction: validate + process,
  postProcess: enrich,
);

// Pattern: Async + Sync
final pipeline = fetchData + validate + format + log;
```