// =============================================================================
// Practical executable walkthrough – Cell.txApply
// Bank transfer · Multi-node consistency · Compensations · Rollback
// cell.apply(command, { tx }) – the forensic ApplyCommand model
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

/// Local builders for the forensic command model.
ApplyCommand cmd(
  Function function,
  List<Object?>? positionalArguments, {
  ApplyCompensation? compensation,
}) =>
    (
      function: function,
      arguments:
          (positionalArguments: positionalArguments, namedArguments: null),
      compensation: compensation,
    );

ApplyCompensation undo(
  Function function,
  List<Object?>? positionalArguments, {
  Cell? cell,
}) =>
    (
      function: function,
      arguments:
          (positionalArguments: positionalArguments, namedArguments: null),
      cell: cell,
    );

/// Demo cell surface: modifiable + the forensic apply command gateway.
class AccountCell implements Cell {
  AccountCell(this.account);

  final Account account;

  @override
  Iterable<Function> get modifiable => [account.credit, account.debit];

  // The integrity gate every transaction consults (`validate.action`).
  // A raw `implements Cell` implementation must provide it.
  @override
  TestCell get validate => TestCell.allowAll;

  @override
  FutureOr<ApplyOutcome<R>> apply<R>(ApplyCommand command, {
    ApplyTransactionScope? tx,
  }) {
    final vetted = modifiable.contains(command.function);

    if (tx != null) {
      final sequence = tx.enqueueCommand(this, command);
      return ApplyStaged(ApplyLedger.receipt(
        cell: this,
        command: command,
        txSequence: sequence,
        vetted: vetted,
      ));
    }

    final receipt =
        ApplyLedger.receipt(cell: this, command: command, vetted: vetted);
    if (!vetted) return ApplyRejected<R>(receipt);

    return ApplyAccepted<R>(
        Function.apply(
          command.function,
          command.arguments.positionalArguments,
          command.arguments.namedArguments,
        ) as R,
        receipt);
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
///    [after fail] alice=1070 bob=80
///    (the attempted debit is compensated by its own undo step)
///
/// 3. Savepoint: commit $20 only
///    [before] alice=1070 bob=80
///    [after savepoint commit] alice=1050 bob=80
///
/// 4. Three-node transfer + fee
///    [before] alice=1050 bob=80
///    [before] treasury=0
///    [after] alice=1039 bob=90
///    [after]  treasury=1
///
/// 5. With compensation retry options
///    [final] alice=1034 bob=95
///
/// 6. Immediate apply without tx
///    [after direct credit] alice=1035 bob=95
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.txApply – Bank Transfer & Multi-Node Consistency ────\n');

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
      alice.apply<Object?>(
        cmd(aliceAcc.debit, [30], compensation: undo(aliceAcc.credit, [30])),
        tx: tx,
      );
      bob.apply<Object?>(
        cmd(bobAcc.credit, [30], compensation: undo(bobAcc.debit, [30])),
        tx: tx,
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
        alice.apply<Object?>(
          cmd(aliceAcc.debit, [1000],
              compensation: undo(aliceAcc.credit, [1000])),
          tx: tx,
        );
        bob.apply<Object?>(
          cmd(bobAcc.credit, [1000],
              compensation: undo(bobAcc.debit, [1000])),
          tx: tx,
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

  alice.apply<Object?>(
    cmd(aliceAcc.debit, [20], compensation: undo(aliceAcc.credit, [20])),
    tx: tx,
  );
  final sp = tx.savepoint();

  bob.apply<Object?>(
    cmd(bobAcc.credit, [20], compensation: undo(bobAcc.debit, [20])),
    tx: tx,
  );

  // Speculative extra – rolled back to savepoint
  bob.apply<Object?>(
    cmd(bobAcc.credit, [5], compensation: undo(bobAcc.debit, [5])),
    tx: tx,
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
      alice.apply<Object?>(
        cmd(aliceAcc.debit, [amount + fee],
            compensation: undo(aliceAcc.credit, [amount + fee])),
        tx: tx,
      );
      bob.apply<Object?>(
        cmd(bobAcc.credit, [amount],
            compensation: undo(bobAcc.debit, [amount])),
        tx: tx,
      );
      treasury.apply<Object?>(
        cmd(treasuryAcc.credit, [fee],
            compensation: undo(treasuryAcc.debit, [fee])),
        tx: tx,
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
      alice.apply<Object?>(
        cmd(aliceAcc.debit, [5], compensation: undo(aliceAcc.credit, [5])),
        tx: tx,
      );
      bob.apply<Object?>(
        cmd(bobAcc.credit, [5], compensation: undo(bobAcc.debit, [5])),
        tx: tx,
      );
    },
  );

  balances('final');

  // -------------------------------------------------------------------------
  // 6. Immediate apply (no tx) still works
  // -------------------------------------------------------------------------
  print('\n6. Immediate apply without tx');
  alice.apply<void>(cmd(aliceAcc.credit, [1]));
  balances('after direct credit');

  print('\n── finished ──────────────────────────────────────────────────');
}
