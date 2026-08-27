// =============================================================================
// Practical executable walkthrough – Cell.transaction
// Atomic multi-cell updates · Isolation · Savepoints · Rollback
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

/// Helper: create a simple int state cell.
StateHandle<int> intCell(int initial) {
  return Cell.state<int>(
    initial: initial,
    evolve: (host, pulse) {
      final v = pulse.payload;
      return v is int ? Pulse(v) : null;
    },
  );
}

/// ### Expected console output:
/// ```text
/// ── Cell.transaction – Atomic Multi-Cell Updates ──────────────
///
/// 1. Basic atomic transfer (Alice → Bob, $30)
///    [tx1 event] …
///    read inside tx: alice=100  bob=50
///    before commit  alice=100  bob=50  inventory=10
///    after commit   alice=70   bob=80  inventory=10
///
/// 2. Full rollback (no changes applied)
///    staged alice=0, bob=0 (buffered only)
///    after rollback alice=70  bob=80  inventory=10
///
/// 3. Savepoint (partial rollback)
///    savepoint created after alice=60, bob=90
///    staged speculative bob=999, inventory=0
///    rolled back to savepoint
///    after savepoint commit  alice=60  bob=90  inventory=10
///
/// 4. Validation failure (transaction aborted)
///    [validate] rejected value -940 …
///    commit failed as expected: …
///    after failed commit  alice=60  bob=90  inventory=10
///
/// 5. Repeatable-read isolation
///    snapshot alice=60  bob=90
///    after repeatable-read commit  alice=65  bob=85  inventory=10
///
/// 6. Business operation – purchase (stock + payment)
///    purchase OK
///    after purchase  alice=35  bob=85  inventory=8
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.transaction – Atomic Multi-Cell Updates ──────────────\n');

  // -------------------------------------------------------------------------
  // Shared accounts
  // -------------------------------------------------------------------------
  final alice = intCell(100);
  final bob = intCell(50);
  final inventory = intCell(10);

  void printBalances(String label) {
    print('   $label  alice=${alice.cell.value}  bob=${bob.cell.value}  '
        'inventory=${inventory.cell.value}');
  }

  // -------------------------------------------------------------------------
  // 1. Basic atomic transfer (begin → read → update → commit)
  // -------------------------------------------------------------------------
  print('1. Basic atomic transfer (Alice → Bob, \$30)');

  final tx1 = Cell.transaction(
    TransactionOptions(
      onEvent: (e) => print('   [tx1 event] $e'),
    ),
  );

  await tx1.begin([alice.cell, bob.cell]);

  final fromBal = tx1.read(alice.cell) as int;
  final toBal = tx1.read(bob.cell) as int;
  print('   read inside tx: alice=$fromBal  bob=$toBal');

  // Values are only buffered – not applied yet
  tx1.update(alice.cell, fromBal - 30);
  tx1.update(bob.cell, toBal + 30);
  printBalances('before commit'); // still 100 / 50

  await tx1.commit();
  printBalances('after commit '); // 70 / 80
  await Future.delayed(const Duration(milliseconds: 20));

  // -------------------------------------------------------------------------
  // 2. Full rollback – discard all buffered changes
  // -------------------------------------------------------------------------
  print('\n2. Full rollback (no changes applied)');

  final tx2 = Cell.transaction();
  await tx2.begin([alice.cell, bob.cell]);

  tx2.update(alice.cell, 0);
  tx2.update(bob.cell, 0);
  print('   staged alice=0, bob=0 (buffered only)');

  await tx2.rollback();
  printBalances('after rollback'); // still 70 / 80

  // -------------------------------------------------------------------------
  // 3. Savepoint – partial rollback
  // -------------------------------------------------------------------------
  print('\n3. Savepoint (partial rollback)');

  final tx3 = Cell.transaction();
  await tx3.begin([alice.cell, bob.cell, inventory.cell]);

  // First batch of changes
  tx3.update(alice.cell, 60);
  tx3.update(bob.cell, 90);
  final sp = tx3.savepoint();
  print('   savepoint created after alice=60, bob=90');

  // Speculative second batch
  tx3.update(bob.cell, 999);
  tx3.update(inventory.cell, 0);
  print('   staged speculative bob=999, inventory=0');

  // Roll back only the speculative part
  await tx3.rollback(savepoint: sp);
  print('   rolled back to savepoint');

  await tx3.commit();
  printBalances('after savepoint commit');
  // Expected: alice=60, bob=90, inventory=10 (speculative changes dropped)

  // -------------------------------------------------------------------------
  // 4. Validation failure → automatic rollback
  // -------------------------------------------------------------------------
  print('\n4. Validation failure (transaction aborted)');

  final tx4 = Cell.transaction(
    TransactionOptions(
      validate: (cell, value) {
        // Reject negative balances
        if (value is int && value < 0) {
          print('   [validate] rejected value $value for $cell');
          return false;
        }
        return true;
      },
      onEvent: (e) => print('   [tx4 event] $e'),
    ),
  );

  await tx4.begin([alice.cell, bob.cell]);
  final a = tx4.read(alice.cell) as int;
  tx4.update(alice.cell, a - 1000); // would go negative
  tx4.update(bob.cell, 500);

  try {
    await tx4.commit();
    print('   commit succeeded (unexpected)');
  } catch (e) {
    print('   commit failed as expected: $e');
  }
  printBalances('after failed commit'); // unchanged

  // -------------------------------------------------------------------------
  // 5. Repeatable-read isolation + timeout
  // -------------------------------------------------------------------------
  print('\n5. Repeatable-read isolation');

  final tx5 = Cell.transaction(
    TransactionOptions(
      isolation: IsolationLevel.repeatableRead,
      timeout: const Duration(seconds: 5),
      onEvent: (e) => print('   [tx5 event] $e'),
    ),
  );

  await tx5.begin([alice.cell, bob.cell]);

  // Snapshot reads – stable for the life of the transaction
  final snapA = tx5.read(alice.cell) as int;
  final snapB = tx5.read(bob.cell) as int;
  print('   snapshot alice=$snapA  bob=$snapB');

  tx5.update(alice.cell, snapA + 5);
  tx5.update(bob.cell, snapB - 5);

  await tx5.commit();
  printBalances('after repeatable-read commit');

  // -------------------------------------------------------------------------
  // 6. Multi-step business operation (purchase)
  // -------------------------------------------------------------------------
  print('\n6. Business operation – purchase (stock + payment)');

  final tx6 = Cell.transaction(
    TransactionOptions(
      validate: (cell, value) {
        if (identical(cell, inventory.cell) && value is int && value < 0) {
          return false; // cannot oversell
        }
        if (identical(cell, alice.cell) && value is int && value < 0) {
          return false; // cannot overdraw
        }
        return true;
      },
    ),
  );

  await tx6.begin([alice.cell, inventory.cell]);

  final balance = tx6.read(alice.cell) as int;
  final stock = tx6.read(inventory.cell) as int;
  const price = 15;
  const qty = 2;

  if (balance >= price * qty && stock >= qty) {
    tx6.update(alice.cell, balance - price * qty);
    tx6.update(inventory.cell, stock - qty);
    await tx6.commit();
    print('   purchase OK');
  } else {
    await tx6.rollback();
    print('   purchase rejected (insufficient funds or stock)');
  }
  printBalances('after purchase');

  print('\n── finished ──────────────────────────────────────────────────');
}