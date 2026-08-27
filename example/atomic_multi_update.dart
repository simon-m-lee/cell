// =============================================================================
// Practical executable walkthrough – Cell.txApply
// Bank transfer · Multi-node consistency · Compensations · Rollback
// apply(function, { positionalArguments, tx, compensate, ... })
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