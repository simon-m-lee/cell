# HowTo-Transaction.md

# How to Use Transaction in the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What is a Transaction?](#what-is-a-transaction)
3. [Core Concepts](#core-concepts)
4. [Isolation Levels](#isolation-levels)
5. [Lock Ordering](#lock-ordering)
6. [Basic Transaction](#basic-transaction)
7. [Transactions with Savepoints](#transactions-with-savepoints)
8. [Isolation Level Examples](#isolation-level-examples)
9. [txApply - Batch Apply Transactions](#txapply-batch-apply-transactions)
10. [Transaction Events](#transaction-events)
11. [Error Handling](#error-handling)
12. [Testing Transactions](#testing-transactions)
13. [Best Practices](#best-practices)
14. [Complete Example](#complete-example)

---

## Introduction

**Transactions** in the Cell Framework allow you to group multiple cell updates into a single atomic unit—either all changes are applied, or none are. This is essential for maintaining consistency across related cells when a logical operation spans multiple state atoms.

### When to Use Transactions

| Scenario | Recommended Approach |
|----------|---------------------|
| Financial transfers | Use `transaction` |
| Inventory adjustments | Use `transaction` |
| Multi-cell consistency | Use `transaction` |
| Batch operations | Use `txApply` |
| Complex form submissions | Use `transaction` |
| Operations with rollback | Use `transaction` with savepoints |
| High-frequency updates | Use `txApply` for batching |

---

## What is a Transaction?

A `Transaction` is an atomic unit of work that groups multiple cell updates together. It ensures that:

- **All updates succeed** or **none are applied**
- **State remains consistent** across related cells
- **Locks are held** only during commit
- **Validation happens** at commit time

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Atomicity** | All or nothing |
| **Isolation** | Read consistency levels |
| **Savepoints** | Partial rollback |
| **Lock Ordering** | Deadlock prevention |
| **Timeouts** | Auto-rollback on timeout |
| **Events** | Lifecycle visibility |

### Transaction Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TRANSACTION FLOW                                   │
│                                                                             │
│  1. BEGIN                                                                   │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │  await tx.begin([accountA, accountB]);                         │    │
│     │  // Register participants, take snapshot (if needed)           │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                          │                                                  │
│                          ▼                                                  │
│  2. UPDATE & READ                                                          │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │  final a = tx.read(accountA);                                  │    │
│     │  final b = tx.read(accountB);                                  │    │
│     │  tx.update(accountA, a - 50);                                  │    │
│     │  tx.update(accountB, b + 50);                                  │    │
│     │  // Changes are buffered, not applied yet                     │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                          │                                                  │
│                          ▼                                                  │
│  3. COMMIT                                                                  │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │  await tx.commit();                                             │    │
│     │  // 1. Acquire locks in deterministic order                    │    │
│     │  // 2. Check isolation conflicts                               │    │
│     │  // 3. Validate all buffered changes                           │    │
│     │  // 4. Apply all changes atomically                            │    │
│     │  // 5. Release locks                                            │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                          │                                                  │
│                          ▼                                                  │
│  4. ROLLBACK (optional)                                                    │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │  await tx.rollback();                                           │    │
│     │  // Discard all buffered changes                                │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Core Concepts

### 1. Locks are Held Only During Commit

Locks are **not** held across `begin → commit`. This means you can perform long-running logic between begin and commit without holding locks.

```dart
final tx = Cell.transaction();
await tx.begin([accountA, accountB]);

// Long-running logic - NO LOCKS HELD
final fromBalance = tx.read(accountA) as int;
final toBalance = tx.read(accountB) as int;

// More long-running logic - STILL NO LOCKS HELD
if (fromBalance < 50) {
  print('Insufficient funds');
  return;
}

// Locks are acquired ONLY during commit
await tx.commit();  // Locks held briefly here
```

### 2. Validation Happens During Commit

Validation runs during `commit()`, not during `update()`. This allows you to stage changes and validate them as a whole.

```dart
// You can stage invalid changes...
tx.update(accountA, -100);  // No validation yet

// ...and fix them before commit
tx.update(accountA, 100);

// Validation runs during commit
await tx.commit();  // Validates all changes together
```

### 3. Transactions are Not Reentrant

You must commit or rollback before starting another transaction.

```dart
final tx = Cell.transaction();
await tx.begin([cell1, cell2]);

// ... updates ...

await tx.commit();  // Must complete

// Start new transaction
await tx.begin([cell3, cell4]);
```

---

## Isolation Levels

### Overview

| Level | Description | Use Case |
|-------|-------------|----------|
| `readCommitted` | Current live values (default) | Simple independent updates |
| `repeatableRead` | Snapshot at begin, abort on conflict | Reads + updates based on them |
| `serializable` | Full isolation, global ordering | Strong consistency required |

### readCommitted (Default)

Reads return the current live value. No snapshot is taken. Fastest, least consistency.

```dart
final tx = Cell.transaction();
await tx.begin([accountA, accountB]);

final a = tx.read(accountA) as int;  // Current live value
// If another transaction changes accountA, tx.read will see the new value

tx.update(accountA, a + 100);
await tx.commit();
```

### repeatableRead

A snapshot is taken at `begin`. Reads return the snapshot value. If any participant changes during the transaction, commit aborts with conflict.

```dart
final tx = Cell.transaction(TransactionOptions(
  isolation: IsolationLevel.repeatableRead,
));

await tx.begin([accountA, accountB]);

final a = tx.read(accountA) as int;  // Snapshot from begin
// If another transaction changes accountA, commit will fail

tx.update(accountA, a + 100);
await tx.commit();  // May throw TransactionConflictException
```

### serializable

Like repeatable read, but also tracks read set. If any cell that was read has changed, commit aborts. Commits are globally serialized.

```dart
final tx = Cell.transaction(TransactionOptions(
  isolation: IsolationLevel.serializable,
));

await tx.begin([accountA, accountB]);

final a = tx.read(accountA) as int;  // Snapshot + read tracking
final b = tx.read(accountB) as int;  // Also tracked

// If accountB changes before commit, abort
tx.update(accountA, a + 100);
await tx.commit();  // May throw TransactionConflictException
```

---

## Lock Ordering

### Overview

| Ordering | Description | Use Case |
|----------|-------------|----------|
| `byHashCode` | Order by cell hash code (default) | Most cases |
| `insertion` | Order passed to `begin` | Natural domain order |
| `explicit` | Custom comparator | Special ordering requirements |

### byHashCode (Default)

Locks acquired in deterministic hash code order.

```dart
final tx = Cell.transaction(TransactionOptions(
  ordering: LockOrdering.byHashCode,
));
// Safe, prevents deadlocks
```

### insertion

Locks acquired in the order cells were passed to `begin`.

```dart
final tx = Cell.transaction(TransactionOptions(
  ordering: LockOrdering.insertion,
));

await tx.begin([accountA, accountB, accountC]);
// Locks acquired: accountA → accountB → accountC
```

### explicit

Use a custom comparator.

```dart
final tx = Cell.transaction(TransactionOptions(
  ordering: LockOrdering.explicit,
  comparator: (a, b) {
    // Custom ordering logic
    return a.hashCode.compareTo(b.hashCode);
  },
));
```

---

## Basic Transaction

### Simple Transfer

```dart
final tx = Cell.transaction();

// Begin with participants
await tx.begin([accountA, accountB]);

// Read current values
final fromBalance = tx.read(accountA) as int;
final toBalance = tx.read(accountB) as int;

// Stage updates
tx.update(accountA, fromBalance - 50);
tx.update(accountB, toBalance + 50);

// Commit atomically
await tx.commit();  // All or nothing
```

### With Validation

```dart
final tx = Cell.transaction(TransactionOptions(
  validate: (cell, value) {
    if (cell == accountA) {
      return value >= 0;  // Balance can't be negative
    }
    return true;
  },
));

await tx.begin([accountA, accountB]);

final a = tx.read(accountA) as int;
tx.update(accountA, a - 50);

await tx.commit();  // Validation runs during commit
```

### With Custom Apply

```dart
final tx = Cell.transaction(TransactionOptions(
  apply: (cell, value) async {
    // Custom application logic
    if (cell is ValueCell) {
      cell._emit(value);
    }
    // Add logging, auditing, etc.
    print('Applied ${cell.runtimeType} = $value');
  },
));

await tx.begin([cell1, cell2]);
tx.update(cell1, 100);
tx.update(cell2, 200);
await tx.commit();
```

---

## Transactions with Savepoints

### Basic Savepoint

```dart
final tx = Cell.transaction();
await tx.begin([cell1, cell2, cell3]);

tx.update(cell1, 10);
tx.update(cell2, 20);

// Create a checkpoint
final sp = tx.savepoint();

// Speculative updates
tx.update(cell2, 30);
tx.update(cell3, 40);

// Something went wrong - rollback to checkpoint
await tx.rollback(savepoint: sp);

// cell1 = 10, cell2 = 20, cell3 unchanged
await tx.commit();
```

### Multiple Savepoints

```dart
final tx = Cell.transaction();
await tx.begin([cell1, cell2, cell3]);

tx.update(cell1, 10);
final sp1 = tx.savepoint();

tx.update(cell2, 20);
final sp2 = tx.savepoint();

tx.update(cell3, 30);

// Rollback to sp2 (discards cell3 update)
await tx.rollback(savepoint: sp2);

// cell1 = 10, cell2 = 20, cell3 unchanged

// Rollback to sp1 (discards cell2 and cell3 updates)
await tx.rollback(savepoint: sp1);

// cell1 = 10, cell2 unchanged, cell3 unchanged
await tx.commit();
```

### Partial Rollback

```dart
final tx = Cell.transaction();
await tx.begin([cell1, cell2, cell3, cell4]);

tx.update(cell1, 10);
tx.update(cell2, 20);
final sp = tx.savepoint();

tx.update(cell2, 30);
tx.update(cell3, 40);
tx.update(cell4, 50);

// Something went wrong - rollback only speculative updates
await tx.rollback(savepoint: sp);

// cell1 = 10, cell2 = 20, cell3 unchanged, cell4 unchanged
await tx.commit();
```

---

## Isolation Level Examples

### readCommitted (Default)

```dart
final tx = Cell.transaction(TransactionOptions(
  isolation: IsolationLevel.readCommitted,
));

await tx.begin([accountA, accountB]);

// Reads current live value
final a = tx.read(accountA) as int;

// If another transaction changes accountA, this read returns the new value
final a2 = tx.read(accountA) as int;  // May be different!

tx.update(accountA, a2 + 100);
await tx.commit();
```

### repeatableRead

```dart
final tx = Cell.transaction(TransactionOptions(
  isolation: IsolationLevel.repeatableRead,
));

await tx.begin([accountA, accountB]);

// Snapshot taken at begin
final a = tx.read(accountA) as int;
final b = tx.read(accountB) as int;

// Both reads return the snapshot values
final a2 = tx.read(accountA) as int;  // Same as 'a'
final b2 = tx.read(accountB) as int;  // Same as 'b'

tx.update(accountA, a + 100);
await tx.commit();

// If another transaction changed accountA or accountB after begin,
// commit will throw TransactionConflictException
```

### serializable

```dart
final tx = Cell.transaction(TransactionOptions(
  isolation: IsolationLevel.serializable,
));

await tx.begin([accountA, accountB, accountC]);

// Snapshot + read tracking
final a = tx.read(accountA) as int;
final b = tx.read(accountB) as int;

// Only update accountA
tx.update(accountA, a + 100);

// If accountB changes before commit, commit fails
// even though accountB wasn't updated!
await tx.commit();  // May throw TransactionConflictException
```

---

## txApply - Batch Apply Transactions

### Basic txApply

```dart
final tx = Cell.txApply();

await tx.execute(
  participants: [cell1, cell2],
  body: (tx) {
    cell1.apply(updateFunction1);
    cell2.apply(updateFunction2);
  },
);
```

### With Compensation

```dart
final tx = Cell.txApply(TxApplyOptions(
  compensationErrorPolicy: CompensationErrorPolicy.bestEffort,
  compensationMaxAttempts: 3,
));

await tx.execute(
  participants: [cell1, cell2],
  body: (tx) {
    cell1.apply(
      updateFunction,
      compensate: rollbackFunction,
    );
  },
);
```

### With Error Handling

```dart
final tx = Cell.txApply(TxApplyOptions(
  stopOnFirstFailure: true,
  compensationErrorPolicy: CompensationErrorPolicy.failFast,
));

try {
  await tx.execute(
    participants: [cell1, cell2, cell3],
    body: (tx) {
      cell1.apply(updateFunction1);
      cell2.apply(updateFunction2);  // If this fails...
      cell3.apply(updateFunction3);  // ...this is not executed
    },
  );
} catch (e) {
  print('Transaction failed: $e');
}
```

### With Retry

```dart
final tx = Cell.txApply(TxApplyOptions(
  compensationMaxAttempts: 3,
  compensationBackoff: (attempt) => Duration(milliseconds: 100 * attempt),
  isRetryableCompensationError: (error) {
    // Only retry on certain errors
    return error is NetworkError;
  },
));

await tx.execute(...);
```

---

## Transaction Events

### Event Types

| Event | Description |
|-------|-------------|
| `TransactionBegun` | Transaction started |
| `TransactionUpdated` | Cell updated |
| `TransactionCommitted` | Transaction committed |
| `TransactionRolledBack` | Transaction rolled back |
| `TransactionTimedOut` | Transaction timed out |

### Listening to Events

```dart
final tx = Cell.transaction(TransactionOptions(
  onEvent: (event) {
    switch (event) {
      case TransactionBegun e:
        print('Transaction started with ${e.cells.length} cells');
        break;
      case TransactionUpdated e:
        print('Updated ${e.cell} to ${e.value}');
        break;
      case TransactionCommitted e:
        print('Transaction committed with ${e.changes.length} changes');
        break;
      case TransactionRolledBack e:
        print('Transaction rolled back${e.savepoint != null ? " to savepoint" : ""}');
        break;
      case TransactionTimedOut e:
        print('Transaction timed out after ${e.timeout}');
        break;
    }
  },
));
```

### Logging Transactions

```dart
final tx = Cell.transaction(TransactionOptions(
  onEvent: (event) {
    if (event is TransactionBegun) {
      print('🔵 BEGIN: ${event.cells.length} participants');
    } else if (event is TransactionUpdated) {
      print('🔄 UPDATE: ${event.cell} = ${event.value}');
    } else if (event is TransactionCommitted) {
      print('✅ COMMIT: ${event.changes.length} changes');
    } else if (event is TransactionRolledBack) {
      print('❌ ROLLBACK');
    } else if (event is TransactionTimedOut) {
      print('⏰ TIMEOUT: ${event.timeout}');
    }
  },
));
```

---

## Error Handling

### TransactionValidationException

Thrown when validation of buffered writes fails during commit.

```dart
try {
  await tx.commit();
} on TransactionValidationException catch (e) {
  print('Validation failed:');
  for (final failure in e.failures) {
    print('  ${failure.cell}: ${failure.reason}');
  }
}
```

### TransactionConflictException

Thrown when an isolation conflict is detected during commit.

```dart
try {
  await tx.commit();
} on TransactionConflictException catch (e) {
  print('Conflict detected:');
  for (final conflict in e.conflicts) {
    print('  ${conflict.cell}: ${conflict.reason}');
  }
  // Retry the transaction
  retry();
}
```

### TransactionTimeoutException

Thrown when a transaction exceeds its timeout.

```dart
try {
  await tx.commit();
} on TransactionTimeoutException catch (e) {
  print('Transaction timed out after ${e.timeout}');
  // The transaction was automatically rolled back
}
```

---

## Testing Transactions

### Unit Testing

```dart
import 'package:test/test.dart';

void main() {
  test('Transaction commits successfully', () async {
    final handle1 = Cell.state<int>(initial: 0);
    final handle2 = Cell.state<int>(initial: 0);
    final cell1 = handle1.cell;
    final cell2 = handle2.cell;
    
    final tx = Cell.transaction();
    await tx.begin([cell1, cell2]);
    
    tx.update(cell1, 100);
    tx.update(cell2, 200);
    
    await tx.commit();
    
    expect(cell1.value, 100);
    expect(cell2.value, 200);
  });

  test('Transaction rolls back on validation failure', () async {
    final handle = Cell.state<int>(
      initial: 0,
      testRule: TestCell((value, {host, ...}) => value > 0),
    );
    final cell = handle.cell;
    
    final tx = Cell.transaction();
    await tx.begin([cell]);
    tx.update(cell, -5);
    
    try {
      await tx.commit();
      fail('Should have thrown');
    } on TransactionValidationException catch (e) {
      expect(e.failures.length, 1);
      expect(cell.value, 0);  // Unchanged
    }
  });

  test('Savepoint rolls back to checkpoint', () async {
    final handle = Cell.state<int>(initial: 0);
    final cell = handle.cell;
    
    final tx = Cell.transaction();
    await tx.begin([cell]);
    
    tx.update(cell, 10);
    final sp = tx.savepoint();
    tx.update(cell, 20);
    
    await tx.rollback(savepoint: sp);
    await tx.commit();
    
    expect(cell.value, 10);
  });
}
```

---

## Best Practices

### 1. Keep Transactions Short

```dart
// ✅ GOOD - Short transaction
await tx.begin([cell1, cell2]);
tx.update(cell1, 100);
tx.update(cell2, 200);
await tx.commit();

// ❌ BAD - Long transaction with user input
await tx.begin([cell1, cell2]);
// Wait for user input (holds locks during commit)
final input = await getUserInput();  // Don't do this!
tx.update(cell1, input);
await tx.commit();
```

### 2. Use Appropriate Isolation Level

```dart
// ✅ GOOD - readCommitted for simple updates
final tx = Cell.transaction();

// ✅ GOOD - repeatableRead for consistent reads
final tx = Cell.transaction(TransactionOptions(
  isolation: IsolationLevel.repeatableRead,
));

// ✅ GOOD - serializable for full consistency
final tx = Cell.transaction(TransactionOptions(
  isolation: IsolationLevel.serializable,
));
```

### 3. Handle Conflicts Gracefully

```dart
async function transfer() {
  while (true) {
    try {
      await tx.begin([accountA, accountB]);
      // ... updates ...
      await tx.commit();
      break;  // Success
    } on TransactionConflictException {
      // Retry with fresh values
      print('Conflict, retrying...');
      await Future.delayed(Duration(milliseconds: 100));
    }
  }
}
```

### 4. Use Savepoints for Complex Operations

```dart
await tx.begin([cell1, cell2, cell3]);

// Step 1: Always commit these
tx.update(cell1, 10);
tx.update(cell2, 20);
final sp = tx.savepoint();

// Step 2: Speculative
tx.update(cell2, 30);
tx.update(cell3, 40);

if (condition) {
  await tx.commit();  // Commit all
} else {
  await tx.rollback(savepoint: sp);  // Only step 1
  await tx.commit();
}
```

### 5. Set Timeouts

```dart
final tx = Cell.transaction(TransactionOptions(
  timeout: Duration(seconds: 5),
));

try {
  await tx.begin([cell1, cell2]);
  // ... long-running logic ...
  await tx.commit();
} on TransactionTimeoutException {
  print('Transaction timed out');
}
```

---

## Complete Example

Here's a complete banking system using transactions:

```dart
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// 1. Bank Account Cells
// ─────────────────────────────────────────────────────────────────────────

class BankAccount {
  final String id;
  final String owner;
  int balance;

  BankAccount({required this.id, required this.owner, this.balance = 0});

  @override
  String toString() => 'Account($owner, balance: $balance)';
}

// Create accounts
final accountAHandle = Cell.state<int>(
  initial: 1000,
  evolve: (host, input) => Pulse(input.payload as int? ?? host.value),
);
final accountA = accountAHandle.cell;

final accountBHandle = Cell.state<int>(
  initial: 500,
  evolve: (host, input) => Pulse(input.payload as int? ?? host.value),
);
final accountB = accountBHandle.cell;

final accountCHandle = Cell.state<int>(
  initial: 2000,
  evolve: (host, input) => Pulse(input.payload as int? ?? host.value),
);
final accountC = accountCHandle.cell;

// ─────────────────────────────────────────────────────────────────────────
// 2. Transfer Function
// ─────────────────────────────────────────────────────────────────────────

class InsufficientFundsException implements Exception {
  final String message;
  InsufficientFundsException(this.message);
}

Future<void> transfer(
  Cell from,
  Cell to,
  int amount,
) async {
  if (amount <= 0) {
    throw ArgumentError('Amount must be positive');
  }

  final tx = Cell.transaction(TransactionOptions(
    isolation: IsolationLevel.repeatableRead,
    timeout: Duration(seconds: 5),
    onEvent: (event) {
      if (event is TransactionBegun) {
        print('🔵 Transfer started');
      } else if (event is TransactionCommitted) {
        print('✅ Transfer completed');
      } else if (event is TransactionRolledBack) {
        print('❌ Transfer rolled back');
      }
    },
    validate: (cell, value) {
      if (cell == from && value < 0) {
        return false;  // Balance can't be negative
      }
      return true;
    },
  ));

  await tx.begin([from, to]);

  final fromBalance = tx.read(from) as int;
  if (fromBalance < amount) {
    await tx.rollback();
    throw InsufficientFundsException(
      'Insufficient funds: $fromBalance < $amount',
    );
  }

  tx.update(from, fromBalance - amount);
  final toBalance = tx.read(to) as int;
  tx.update(to, toBalance + amount);

  await tx.commit();
}

// ─────────────────────────────────────────────────────────────────────────
// 3. Multi-Transfer Function
// ─────────────────────────────────────────────────────────────────────────

class Transfer {
  final Cell from;
  final Cell to;
  final int amount;

  Transfer({required this.from, required this.to, required this.amount});
}

Future<void> multiTransfer(List<Transfer> transfers) async {
  final participants = transfers.expand((t) => [t.from, t.to]).toSet().toList();

  final tx = Cell.transaction(TransactionOptions(
    isolation: IsolationLevel.repeatableRead,
    validate: (cell, value) {
      if (transfers.any((t) => t.from == cell) && value < 0) {
        return false;
      }
      return true;
    },
  ));

  await tx.begin(participants);

  // Read all balances first
  final balances = <Cell, int>{};
  for (final cell in participants) {
    balances[cell] = tx.read(cell) as int;
  }

  // Validate all transfers
  for (final transfer in transfers) {
    final fromBalance = balances[transfer.from]!;
    if (fromBalance < transfer.amount) {
      await tx.rollback();
      throw InsufficientFundsException(
        'Insufficient funds in ${transfer.from}',
      );
    }
  }

  // Apply all transfers
  for (final transfer in transfers) {
    final fromBalance = balances[transfer.from]!;
    final toBalance = balances[transfer.to]!;
    tx.update(transfer.from, fromBalance - transfer.amount);
    tx.update(transfer.to, toBalance + transfer.amount);
  }

  await tx.commit();
}

// ─────────────────────────────────────────────────────────────────────────
// 4. Main Demo
// ─────────────────────────────────────────────────────────────────────────

void main() async {
  print('═══ Banking System with Transactions ═══\n');

  print('1. Simple Transfer:');
  print('   Account A: ${accountA.value}');
  print('   Account B: ${accountB.value}');
  await transfer(accountA, accountB, 100);
  print('   After transfer:');
  print('   Account A: ${accountA.value}');
  print('   Account B: ${accountB.value}');

  print('\n2. Multi-Transfer:');
  print('   Account A: ${accountA.value}');
  print('   Account B: ${accountB.value}');
  print('   Account C: ${accountC.value}');

  await multiTransfer([
    Transfer(from: accountB, to: accountC, amount: 200),
    Transfer(from: accountC, to: accountA, amount: 100),
  ]);

  print('   After multi-transfer:');
  print('   Account A: ${accountA.value}');
  print('   Account B: ${accountB.value}');
  print('   Account C: ${accountC.value}');

  print('\n3. Invalid Transfer (Insufficient Funds):');
  print('   Account A: ${accountA.value}');
  print('   Account B: ${accountB.value}');

  try {
    await transfer(accountB, accountA, 2000);
  } catch (e) {
    print('   ❌ Transfer failed: $e');
  }

  print('   After failed transfer:');
  print('   Account A: ${accountA.value}');  // Unchanged
  print('   Account B: ${accountB.value}');  // Unchanged

  print('\n═══ Done ═══');
}
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **Transaction** | Atomic unit of work |
| **Isolation** | Consistency guarantees |
| **Savepoint** | Partial rollback point |
| **Lock Ordering** | Deadlock prevention |
| **Validation** | Integrity checks during commit |
| **txApply** | Batch apply operations |

### Key Rules

1. **Locks are held only during commit** - Keep logic between begin and commit short
2. **Validation happens during commit** - Stage changes, validate together
3. **Use savepoints for complex operations** - Partial rollback
4. **Handle conflicts gracefully** - Retry on conflict
5. **Set timeouts** - Prevent hung transactions
6. **Use appropriate isolation level** - Match your consistency needs

### Common Patterns

```dart
// Pattern: Simple transfer
final tx = Cell.transaction();
await tx.begin([from, to]);
tx.update(from, fromBalance - amount);
tx.update(to, toBalance + amount);
await tx.commit();

// Pattern: With savepoint
final sp = tx.savepoint();
// ... speculative updates ...
await tx.rollback(savepoint: sp);

// Pattern: Batch apply
final tx = Cell.txApply();
await tx.execute(participants: [cell1, cell2], body: (tx) {
  cell1.apply(updateFunction);
  cell2.apply(updateFunction);
});

// Pattern: With retry
while (true) {
  try {
    await tx.begin([cell1, cell2]);
    // ... updates ...
    await tx.commit();
    break;
  } on TransactionConflictException {
    await Future.delayed(Duration(milliseconds: 100));
  }
}
```