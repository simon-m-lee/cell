# HowTo-TransactionOnApply.md (Updated with Demo Example)

## Table of Contents

1. [Introduction](#introduction)
2. [What is txApply?](#what-is-txapply)
3. [Core Concepts](#core-concepts)
4. [Basic Usage](#basic-usage)
5. [Compensation Patterns](#compensation-patterns)
6. [Error Handling Policies](#error-handling-policies)
7. [Retry and Backoff](#retry-and-backoff)
8. [Savepoints](#savepoints)
9. [Events and Monitoring](#events-and-monitoring)
10. [Testing txApply](#testing-txapply)
11. [Best Practices](#best-practices)
12. [Complete Example](#complete-example)

---

## Introduction

**txApply** (Transaction on Apply) is an atomic evolution sequencer that executes multiple state mutations within a single coordinated transaction. It batches `apply()` calls into a single commit, ensuring all changes are applied atomically with built-in compensation support.

### When to Use txApply

| Scenario | Why txApply |
|----------|-------------|
| Bank transfers | Update multiple accounts atomically |
| Multi-cell consistency | Update related cells together |
| Performance optimization | Batch updates to reduce downstream churn |
| Compensation | Rollback partially applied operations |
| Cyclic dependency guards | Prevent race conditions |
| Complex workflows | Execute sequences with rollback |

---

## What is txApply?

`txApply` is an atomic transaction system specifically designed for `Cell.apply()` operations. It provides:

- **Atomicity** - All apply calls succeed or none
- **Compensation** - Rollback functions for each operation
- **Retry** - Automatic retry on failure
- **Error Policies** - Configurable error handling
- **Savepoints** - Partial rollback

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Atomic** | All or nothing |
| **Compensation** | Rollback support |
| **Retry** | Configurable retry attempts |
| **Events** | Lifecycle monitoring |
| **Error Policies** | bestEffort, failFast, collectThenThrow |
| **Savepoints** | Partial rollback |

---

## Core Concepts

### 1. Staged Execution

`apply()` calls are staged, not executed immediately:

```dart
tx.enqueue(cell1, updateFunction1);  // Staged, not executed
tx.enqueue(cell2, updateFunction2);  // Staged, not executed
await tx.commit();  // All executed atomically
```

### 2. Compensation

Each operation can have a compensation function:

```dart
tx.enqueue(
  cell,
  updateFunction,
  compensate: rollbackFunction,  // Called on rollback
);
```

### 3. Error Policies

| Policy | Behavior |
|--------|----------|
| `bestEffort` | Continue, collect failures |
| `failFast` | Stop immediately on first failure |
| `collectThenThrow` | Collect all, then throw |

### 4. Retry

Compensation functions can be retried:

```dart
TxApplyOptions(
  compensationMaxAttempts: 3,
  compensationBackoff: (attempt) => Duration(milliseconds: 100 * attempt),
)
```

---

## Basic Usage

### Simple txApply with execute()

```dart
final tx = Cell.txApply();

await tx.execute(
  participants: [alice, bob],
  body: (tx) {
    alice.apply(
      aliceAcc.debit,
      positionalArguments: [30],
      tx: tx,
      compensate: aliceAcc.credit,
      compensatePositional: [30],
    );
    bob.apply(
      bobAcc.credit,
      positionalArguments: [30],
      tx: tx,
      compensate: bobAcc.debit,
      compensatePositional: [30],
    );
  },
);
// Both apply calls executed atomically
```

### Manual Control with begin()/commit()

```dart
final tx = Cell.txApply();
await tx.begin([alice, bob]);

alice.apply(
  aliceAcc.debit,
  positionalArguments: [30],
  tx: tx,
  compensate: aliceAcc.credit,
  compensatePositional: [30],
);

bob.apply(
  bobAcc.credit,
  positionalArguments: [30],
  tx: tx,
  compensate: bobAcc.debit,
  compensatePositional: [30],
);

await tx.commit();  // Or rollback
```

### Immediate Apply (Without tx)

```dart
// Direct apply without transaction
alice.apply(aliceAcc.credit, positionalArguments: [1]);
// Changes applied immediately
```

---

## Compensation Patterns

### Basic Compensation

```dart
// Debit with compensation
alice.apply(
  aliceAcc.debit,
  positionalArguments: [30],
  tx: tx,
  compensate: aliceAcc.credit,
  compensatePositional: [30],
);

// Credit with compensation
bob.apply(
  bobAcc.credit,
  positionalArguments: [30],
  tx: tx,
  compensate: bobAcc.debit,
  compensatePositional: [30],
);
```

### Multi-Node Compensation

```dart
// Three-node transfer with fees
const amount = 10;
const fee = 1;

alice.apply(
  aliceAcc.debit,
  positionalArguments: [amount + fee],
  tx: tx,
  compensate: aliceAcc.credit,
  compensatePositional: [amount + fee],
);

bob.apply(
  bobAcc.credit,
  positionalArguments: [amount],
  tx: tx,
  compensate: bobAcc.debit,
  compensatePositional: [amount],
);

treasury.apply(
  treasuryAcc.credit,
  positionalArguments: [fee],
  tx: tx,
  compensate: treasuryAcc.debit,
  compensatePositional: [fee],
);
```

### Compensation with Retry

```dart
final tx = Cell.txApply(
  TxApplyOptions(
    compensationMaxAttempts: 3,
    compensationBackoff: (n) => Duration(milliseconds: 10 * n),
    compensationErrorPolicy: CompensationErrorPolicy.collectThenThrow,
  ),
);

await tx.execute(
  participants: [alice, bob],
  body: (tx) {
    alice.apply(
      aliceAcc.debit,
      positionalArguments: [5],
      tx: tx,
      compensate: aliceAcc.credit,
      compensatePositional: [5],
    );
    bob.apply(
      bobAcc.credit,
      positionalArguments: [5],
      tx: tx,
      compensate: bobAcc.debit,
      compensatePositional: [5],
    );
  },
);
```

---

## Error Handling Policies

### bestEffort (Default)

Continues executing all operations, collecting failures:

```dart
final tx = Cell.txApply(
  TxApplyOptions(
    compensationErrorPolicy: CompensationErrorPolicy.bestEffort,
    onEvent: (e) {
      if (e is TxApplyRolledBack) print('Rolled back');
    },
  ),
);

try {
  await tx.execute(
    participants: [alice, bob],
    body: (tx) {
      alice.apply(...);  // Succeeds
      bob.apply(...);    // Fails - but continues
    },
  );
} catch (e) {
  // All failures collected
}
```

### failFast

Stops immediately on first failure:

```dart
final tx = Cell.txApply(
  TxApplyOptions(
    compensationErrorPolicy: CompensationErrorPolicy.failFast,
  ),
);

try {
  await tx.execute(...);
} on TxApplyException catch (e) {
  print('Transaction failed: $e');
}
```

### collectThenThrow

Collects all failures, then throws:

```dart
final tx = Cell.txApply(
  TxApplyOptions(
    compensationErrorPolicy: CompensationErrorPolicy.collectThenThrow,
  ),
);

try {
  await tx.execute(...);
} on TxApplyCompensationException catch (e) {
  print('${e.failures.length} failures');
}
```

---

## Retry and Backoff

### Basic Retry

```dart
final tx = Cell.txApply(
  TxApplyOptions(
    compensationMaxAttempts: 3,
  ),
);

await tx.execute(
  participants: [alice, bob],
  body: (tx) {
    alice.apply(
      aliceAcc.debit,
      positionalArguments: [5],
      tx: tx,
      compensate: aliceAcc.credit,
      compensatePositional: [5],
    );
    bob.apply(
      bobAcc.credit,
      positionalArguments: [5],
      tx: tx,
      compensate: bobAcc.debit,
      compensatePositional: [5],
    );
  },
);
// If compensation fails, retry up to 3 times
```

### Custom Backoff

```dart
final tx = Cell.txApply(
  TxApplyOptions(
    compensationMaxAttempts: 3,
    compensationBackoff: (n) => Duration(milliseconds: 10 * n),
    compensationErrorPolicy: CompensationErrorPolicy.collectThenThrow,
  ),
);

await tx.execute(...);
```

### Exponential Backoff

```dart
final tx = Cell.txApply(
  TxApplyOptions(
    compensationMaxAttempts: 5,
    compensationBackoff: (attempt) {
      // Exponential backoff: 100ms, 200ms, 400ms, 800ms, 1600ms
      return Duration(milliseconds: 100 * (1 << attempt));
    },
  ),
);

await tx.execute(...);
```

---

## Savepoints

### Basic Savepoint

```dart
final tx = Cell.txApply();
await tx.begin([alice, bob]);

// Step 1: Always commit these
alice.apply(
  aliceAcc.debit,
  positionalArguments: [20],
  tx: tx,
  compensate: aliceAcc.credit,
  compensatePositional: [20],
);

final sp = tx.savepoint();  // Checkpoint

// Step 2: Speculative
bob.apply(
  bobAcc.credit,
  positionalArguments: [20],
  tx: tx,
  compensate: bobAcc.debit,
  compensatePositional: [20],
);

// Step 3: Extra speculative - will be rolled back
bob.apply(
  bobAcc.credit,
  positionalArguments: [5],
  tx: tx,
  compensate: bobAcc.debit,
  compensatePositional: [5],
);

// Rollback to savepoint (undoes bob's extra 5)
await tx.rollback(savepoint: sp);

await tx.commit();  // Only the first 20 is committed
```

### Multiple Savepoints

```dart
final tx = Cell.txApply();
await tx.begin([alice, bob, treasury]);

// Step 1
alice.apply(aliceAcc.debit, positionalArguments: [10], tx: tx);
final sp1 = tx.savepoint();

// Step 2
bob.apply(bobAcc.credit, positionalArguments: [10], tx: tx);
final sp2 = tx.savepoint();

// Step 3
treasury.apply(treasuryAcc.credit, positionalArguments: [1], tx: tx);

// Rollback to sp2 (undoes treasury)
await tx.rollback(savepoint: sp2);

// Rollback to sp1 (undoes bob and treasury)
await tx.rollback(savepoint: sp1);

// Only alice's debit is committed
await tx.commit();
```

---

## Events and Monitoring

### Event Types

| Event | Description |
|-------|-------------|
| `TxApplyBegun` | Transaction started |
| `TxApplyStaged` | Apply call staged |
| `TxApplyCommitted` | Transaction committed |
| `TxApplyRolledBack` | Transaction rolled back |
| `TxApplyRejected` | Apply call rejected |
| `TxApplyCompensationFailed` | Compensation failed |
| `TxApplyCompensationRetry` | Compensation retry |

### Listening to Events

```dart
final tx = Cell.txApply(
  TxApplyOptions(
    onEvent: (e) {
      if (e is TxApplyCommitted) {
        print('Committed calls: ${e.callCount}');
      } else if (e is TxApplyRolledBack) {
        print('Rolled back');
      } else if (e is TxApplyRejected) {
        print('Rejected: ${e.cell} - ${e.reason}');
      } else if (e is TxApplyCompensationRetry) {
        print('Retry ${e.attempt}/${e.maxAttempts}: ${e.cell}');
      }
    },
  ),
);
```

---

## Testing txApply

### Unit Testing

```dart
import 'package:test/test.dart';

void main() {
  test('txApply commits successfully', () async {
    final aliceAcc = Account('alice', 100);
    final bobAcc = Account('bob', 50);
    final alice = AccountCell(aliceAcc);
    final bob = AccountCell(bobAcc);

    await Cell.txApply().execute(
      participants: [alice, bob],
      body: (tx) {
        alice.apply(
          aliceAcc.debit,
          positionalArguments: [30],
          tx: tx,
          compensate: aliceAcc.credit,
          compensatePositional: [30],
        );
        bob.apply(
          bobAcc.credit,
          positionalArguments: [30],
          tx: tx,
          compensate: bobAcc.debit,
          compensatePositional: [30],
        );
      },
    );

    expect(aliceAcc.balance, 70);
    expect(bobAcc.balance, 80);
  });

  test('txApply rolls back on failure', () async {
    final aliceAcc = Account('alice', 100);
    final bobAcc = Account('bob', 50);
    final alice = AccountCell(aliceAcc);
    final bob = AccountCell(bobAcc);

    try {
      await Cell.txApply().execute(
        participants: [alice, bob],
        body: (tx) {
          alice.apply(
            aliceAcc.debit,
            positionalArguments: [1000],
            tx: tx,
            compensate: aliceAcc.credit,
            compensatePositional: [1000],
          );
          bob.apply(
            bobAcc.credit,
            positionalArguments: [1000],
            tx: tx,
            compensate: bobAcc.debit,
            compensatePositional: [1000],
          );
        },
      );
    } catch (_) {}

    expect(aliceAcc.balance, 100);  // Unchanged
    expect(bobAcc.balance, 50);     // Unchanged
  });

  test('txApply supports savepoints', () async {
    final aliceAcc = Account('alice', 100);
    final bobAcc = Account('bob', 50);
    final alice = AccountCell(aliceAcc);
    final bob = AccountCell(bobAcc);

    final tx = Cell.txApply();
    await tx.begin([alice, bob]);

    alice.apply(
      aliceAcc.debit,
      positionalArguments: [20],
      tx: tx,
      compensate: aliceAcc.credit,
      compensatePositional: [20],
    );

    final sp = tx.savepoint();

    bob.apply(
      bobAcc.credit,
      positionalArguments: [20],
      tx: tx,
      compensate: bobAcc.debit,
      compensatePositional: [20],
    );

    bob.apply(
      bobAcc.credit,
      positionalArguments: [5],
      tx: tx,
      compensate: bobAcc.debit,
      compensatePositional: [5],
    );

    await tx.rollback(savepoint: sp);
    await tx.commit();

    expect(aliceAcc.balance, 80);
    expect(bobAcc.balance, 50);  // Bob's credits rolled back
  });
}
```

---

## Best Practices

### 1. Always Provide Compensation

```dart
// ✅ GOOD - With compensation
alice.apply(
  aliceAcc.debit,
  positionalArguments: [30],
  tx: tx,
  compensate: aliceAcc.credit,
  compensatePositional: [30],
);

// ❌ BAD - No compensation
alice.apply(
  aliceAcc.debit,
  positionalArguments: [30],
  tx: tx,
);
```

### 2. Use Appropriate Error Policy

```dart
// ✅ GOOD - bestEffort for independent operations
final tx = Cell.txApply(
  TxApplyOptions(
    compensationErrorPolicy: CompensationErrorPolicy.bestEffort,
  ),
);

// ✅ GOOD - failFast for dependent operations
final tx = Cell.txApply(
  TxApplyOptions(
    compensationErrorPolicy: CompensationErrorPolicy.failFast,
  ),
);
```

### 3. Set Retry Limits

```dart
// ✅ GOOD - With retry limits
final tx = Cell.txApply(
  TxApplyOptions(
    compensationMaxAttempts: 3,
    compensationBackoff: (n) => Duration(milliseconds: 10 * n),
  ),
);

// ❌ BAD - No retry handling
final tx = Cell.txApply();
```

### 4. Use Savepoints for Complex Workflows

```dart
// ✅ GOOD - Savepoint for partial rollback
final sp = tx.savepoint();
// ... speculative operations ...
if (condition) {
  await tx.rollback(savepoint: sp);
}
// ... continue ...

// ❌ BAD - All or nothing
// No savepoint means full rollback on any failure
```

### 5. Monitor Events

```dart
// ✅ GOOD - Event monitoring
final tx = Cell.txApply(
  TxApplyOptions(
    onEvent: (e) {
      if (e is TxApplyCommitted) {
        print('Committed: ${e.callCount}');
      } else if (e is TxApplyRolledBack) {
        print('Rolled back');
      }
    },
  ),
);

// ❌ BAD - No monitoring
final tx = Cell.txApply();
```

---

## Complete Example

Here's a complete banking transfer system with all features:

```dart
// =============================================================================
// Practical executable walkthrough – Cell.txApply
// Bank transfer · Multi-node consistency · Compensations · Rollback
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

// ── Account domain ──────────────────────────────────────────────────────────

class Account {
  Account(this.id, int opening) : _balance = opening;

  final String id;
  int _balance;
  int get balance => _balance;

  void credit(int amount) {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    _balance += amount;
  }

  void debit(int amount) {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    if (amount > _balance) throw StateError('insufficient funds');
    _balance -= amount;
  }
}

/// Demo cell surface: modifiable + apply (matches Cell.apply named signature).
class AccountCell implements Cell {
  AccountCell(this.account);

  final Account account;

  @override
  Iterable<Function> get modifiable => [account.credit, account.debit];

  @override
  dynamic apply(
      Function function, {
        List? positionalArguments,
        Map<Symbol, dynamic>? namedArguments,
        ApplyTransactionScope? tx,
        Function? compensate,
        List? compensatePositional,
        Map<Symbol, dynamic>? compensateNamed,
        Cell? compensateCell,
      }) {
    if (tx != null) {
      tx.enqueue(
        this,
        function,
        positionalArguments,
        namedArguments,
        compensateCell: compensateCell,
        compensateFunction: compensate,
        compensatePositional: compensatePositional,
        compensateNamed: compensateNamed,
      );
      return null;
    }
    if (!modifiable.contains(function)) return null;
    return Function.apply(function, positionalArguments, namedArguments);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// ### Expected console output:
/// ```text
/// ── Cell.txApply – Bank Transfer & Multi-Node Consistency ─────
///
/// 1. Atomic transfer Alice → Bob ($30)
///    [before] alice=100 bob=50
///    [event] committed calls=2
///    [after] alice=70 bob=80
///
/// 2. Transfer too large – commit fails
///    [before] alice=70 bob=80
///    [catch] TxApplyException: commit failed
///    [after fail] alice=70 bob=80
///
/// 3. Savepoint: commit $20 only
///    [before] alice=70 bob=80
///    [after savepoint commit] alice=50 bob=80
///
/// 4. Three-node transfer + fee
///    [before] alice=50 bob=80
///    [before] treasury=0
///    [after] alice=39 bob=90
///    [after]  treasury=1
///
/// 5. With compensation retry options
///    [final] alice=34 bob=95
///
/// 6. Immediate apply without tx
///    [after direct credit] alice=35 bob=95
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.txApply – Bank Transfer & Multi-Node Consistency ─────\n');

  final aliceAcc = Account('alice', 100);
  final bobAcc = Account('bob', 50);
  final alice = AccountCell(aliceAcc);
  final bob = AccountCell(bobAcc);

  void balances(String label) {
    print('   [$label] alice=${aliceAcc.balance} bob=${bobAcc.balance}');
  }

  // -------------------------------------------------------------------------
  // 1. Successful transfer Alice → Bob ($30)
  // -------------------------------------------------------------------------
  print('1. Atomic transfer Alice → Bob (\$30)');
  balances('before');

  await Cell.txApply(
    TxApplyOptions(
      onEvent: (e) {
        if (e is TxApplyCommitted) {
          print('   [event] committed calls=${e.callCount}');
        }
      },
    ),
  ).execute(
    participants: [alice, bob],
    body: (tx) {
      alice.apply(
        aliceAcc.debit,
        positionalArguments: [30],
        tx: tx,
        compensate: aliceAcc.credit,
        compensatePositional: [30],
      );
      bob.apply(
        bobAcc.credit,
        positionalArguments: [30],
        tx: tx,
        compensate: bobAcc.debit,
        compensatePositional: [30],
      );
    },
  );

  balances('after'); // 70 / 80

  // -------------------------------------------------------------------------
  // 2. Oversized transfer – fails on commit
  // -------------------------------------------------------------------------
  print('\n2. Transfer too large – commit fails');
  balances('before');

  try {
    await Cell.txApply(
      TxApplyOptions(
        compensationErrorPolicy: CompensationErrorPolicy.bestEffort,
        onEvent: (e) {
          if (e is TxApplyRolledBack) print('   [event] rolled back');
        },
      ),
    ).execute(
      participants: [alice, bob],
      body: (tx) {
        alice.apply(
          aliceAcc.debit,
          positionalArguments: [1000],
          tx: tx,
          compensate: aliceAcc.credit,
          compensatePositional: [1000],
        );
        bob.apply(
          bobAcc.credit,
          positionalArguments: [1000],
          tx: tx,
          compensate: bobAcc.debit,
          compensatePositional: [1000],
        );
      },
    );
  } on TxApplyException catch (e) {
    print('   [catch] $e');
  }

  balances('after fail'); // still 70 / 80

  // -------------------------------------------------------------------------
  // 3. Savepoint – drop speculative tail
  // -------------------------------------------------------------------------
  print('\n3. Savepoint: commit \$20 only');
  balances('before');

  final tx = Cell.txApply();
  await tx.begin([alice, bob]);

  alice.apply(
    aliceAcc.debit,
    positionalArguments: [20],
    tx: tx,
    compensate: aliceAcc.credit,
    compensatePositional: [20],
  );
  final sp = tx.savepoint();

  bob.apply(
    bobAcc.credit,
    positionalArguments: [20],
    tx: tx,
    compensate: bobAcc.debit,
    compensatePositional: [20],
  );

  // Speculative extra – rolled back to savepoint
  bob.apply(
    bobAcc.credit,
    positionalArguments: [5],
    tx: tx,
    compensate: bobAcc.debit,
    compensatePositional: [5],
  );
  await tx.rollback(savepoint: sp);

  await tx.commit();
  balances('after savepoint commit');

  // -------------------------------------------------------------------------
  // 4. Three-node: Alice → Bob + fee to Treasury
  // -------------------------------------------------------------------------
  print('\n4. Three-node transfer + fee');

  final treasuryAcc = Account('treasury', 0);
  final treasury = AccountCell(treasuryAcc);

  balances('before');
  print('   [before] treasury=${treasuryAcc.balance}');

  await Cell.txApply().execute(
    participants: [alice, bob, treasury],
    body: (tx) {
      const amount = 10;
      const fee = 1;
      alice.apply(
        aliceAcc.debit,
        positionalArguments: [amount + fee],
        tx: tx,
        compensate: aliceAcc.credit,
        compensatePositional: [amount + fee],
      );
      bob.apply(
        bobAcc.credit,
        positionalArguments: [amount],
        tx: tx,
        compensate: bobAcc.debit,
        compensatePositional: [amount],
      );
      treasury.apply(
        treasuryAcc.credit,
        positionalArguments: [fee],
        tx: tx,
        compensate: treasuryAcc.debit,
        compensatePositional: [fee],
      );
    },
  );

  balances('after');
  print('   [after]  treasury=${treasuryAcc.balance}');

  // -------------------------------------------------------------------------
  // 5. Compensation retry options (happy path)
  // -------------------------------------------------------------------------
  print('\n5. With compensation retry options');

  await Cell.txApply(
    TxApplyOptions(
      compensationMaxAttempts: 3,
      compensationBackoff: (n) => Duration(milliseconds: 10 * n),
      compensationErrorPolicy: CompensationErrorPolicy.collectThenThrow,
    ),
  ).execute(
    participants: [alice, bob],
    body: (tx) {
      alice.apply(
        aliceAcc.debit,
        positionalArguments: [5],
        tx: tx,
        compensate: aliceAcc.credit,
        compensatePositional: [5],
      );
      bob.apply(
        bobAcc.credit,
        positionalArguments: [5],
        tx: tx,
        compensate: bobAcc.debit,
        compensatePositional: [5],
      );
    },
  );

  balances('final');

  // -------------------------------------------------------------------------
  // 6. Immediate apply (no tx) still works
  // -------------------------------------------------------------------------
  print('\n6. Immediate apply without tx');
  alice.apply(aliceAcc.credit, positionalArguments: [1]);
  balances('after direct credit');

  print('\n── finished ──────────────────────────────────────────────────');
}
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **txApply** | Atomic apply operations |
| **Compensation** | Rollback functions |
| **Error Policies** | bestEffort, failFast, collectThenThrow |
| **Retry** | Automatic retry on failure |
| **Savepoints** | Partial rollback |
| **Events** | Lifecycle visibility |

### Key Rules

1. **Use compensation for reversible operations** - Always provide compensation
2. **Choose appropriate error policy** - Match your business requirements
3. **Set retry limits** - Prevent infinite retry loops
4. **Use savepoints for complex workflows** - Partial rollback
5. **Monitor events** - Track transaction lifecycle
6. **Test compensation** - Ensure rollback works