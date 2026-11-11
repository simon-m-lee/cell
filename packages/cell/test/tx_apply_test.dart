// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:test/test.dart';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// Fixtures

// Local builders for the forensic command model.
ApplyCommand cmd(
  Function function, [
  List<Object?>? positionalArguments,
  ApplyCompensation? compensation,
]) =>
    (
      function: function,
      arguments: (
        positionalArguments: positionalArguments,
        namedArguments: null
      ),
      compensation: compensation,
    );

ApplyCompensation undo(
  Function function, [
  List<Object?>? positionalArguments,
  Map<Symbol, Object?>? namedArguments,
  Cell? cell,
]) =>
    (
      function: function,
      arguments: (
        positionalArguments: positionalArguments,
        namedArguments: namedArguments
      ),
      cell: cell,
    );

//
// txApply only enqueues functions that appear in [Cell.modifiable].
// Tear-offs are stored on fields so `modifiable.contains` is identity-stable.
// ─────────────────────────────────────────────────────────────────────────

class AccountCell extends CellBase {
  int balance;

  late final void Function(int amount) credit;
  late final void Function(int amount) debit;
  late final void Function({required int amount}) creditNamed;
  late final dynamic Function() reject;
  late final void Function() fail;

  AccountCell({this.balance = 0, super.synapses}) {
    credit = _credit;
    debit = _debit;
    creditNamed = _creditNamed;
    reject = _reject;
    fail = _fail;
  }

  void _credit(int amount) {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    balance += amount;
  }

  void _debit(int amount) {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    if (amount > balance) throw StateError('insufficient funds');
    balance -= amount;
  }

  void _creditNamed({required int amount}) {
    _credit(amount);
  }

  dynamic _reject() => ApplyVeto.instance;

  void _fail() => throw StateError('forced failure');

  @override
  Iterable<Function> get modifiable =>
      {credit, debit, creditNamed, reject, fail, apply<dynamic>};
}

class LedgerCell extends CellBase {
  final List<String> ops = [];

  late final void Function(String name) record;
  late final void Function(String name) unrecord;
  late final void Function({required String name}) unrecordNamed;
  late final void Function() fail;
  late final void Function(String name) boomUndo;

  LedgerCell({super.synapses}) {
    record = _record;
    unrecord = _unrecord;
    unrecordNamed = _unrecordNamed;
    fail = _fail;
    boomUndo = _boomUndo;
  }

  void _record(String name) => ops.add(name);

  void _unrecord(String name) => ops.add('undo_$name');

  void _unrecordNamed({required String name}) => ops.add('undo_$name');

  void _fail() => throw StateError('forced failure');

  void _boomUndo(String name) => throw Exception('compensate boom: $name');

  @override
  Iterable<Function> get modifiable =>
      {record, unrecord, unrecordNamed, fail, boomUndo, apply<dynamic>};
}

class MutableModifiableCell extends CellBase {
  int value = 0;
  final Set<Function> allowed = {};

  late final void Function(int amount) add;
  late final void Function(int amount) sub;
  late final void Function() fail;

  MutableModifiableCell() {
    add = _add;
    sub = _sub;
    fail = _fail;
    allowed.addAll({add, sub, fail, apply<dynamic>});
  }

  void _add(int amount) => value += amount;
  void _sub(int amount) => value -= amount;
  void _fail() => throw StateError('forced failure');

  @override
  Iterable<Function> get modifiable => allowed;
}

class FlakyUndoCell extends CellBase {
  int value;
  int undoAttempts = 0;
  final int failTimes;

  late final void Function(int amount) add;
  late final void Function(int amount) flakySub;
  late final void Function() fail;

  FlakyUndoCell({this.value = 0, this.failTimes = 2, super.synapses}) {
    add = _add;
    flakySub = _flakySub;
    fail = _fail;
  }

  void _add(int amount) => value += amount;

  void _flakySub(int amount) {
    undoAttempts++;
    if (undoAttempts <= failTimes) {
      throw Exception('transient undo');
    }
    value -= amount;
  }

  void _fail() => throw StateError('forced failure');

  @override
  Iterable<Function> get modifiable => {add, flakySub, fail, apply};
}

({AccountCell a, AccountCell b}) pair({int a = 100, int b = 50}) =>
    (a: AccountCell(balance: a), b: AccountCell(balance: b));

void stage(
  ApplyTransactionScope tx,
  AccountCell cell,
  void Function(int) fn,
  int amount, {
  void Function(int)? compensate,
  AccountCell? compensateCell,
}) {
  cell.apply<Object?>(
    (
      function: fn,
      arguments: (positionalArguments: [amount], namedArguments: null),
      compensation: compensate == null
          ? null
          : (
              function: compensate,
              arguments: (positionalArguments: [amount], namedArguments: null),
              cell: compensateCell,
            ),
    ),
    tx: tx,
  );
}

TypeMatcher<TxApplyException> isTxApplyException({String? containing}) {
  var matcher = isA<TxApplyException>();
  if (containing != null) {
    matcher = matcher.having((e) => e.message, 'message', contains(containing));
  }
  return matcher;
}

void main() {
  group('Cell.txApply', () {
    group('Basic Operations', () {
      test('executes a single apply with txApply', () async {
        final cell = AccountCell(balance: 0);
        final tx = Cell.txApply();

        await tx.execute(
          participants: [cell],
          body: (scope) {
            stage(scope, cell, cell.credit, 5, compensate: cell.debit);
          },
        );

        expect(cell.balance, 5);
      });

      test('executes multiple applies with txApply', () async {
        final cell = AccountCell(balance: 0);
        final tx = Cell.txApply();

        await tx.execute(
          participants: [cell],
          body: (scope) {
            stage(scope, cell, cell.credit, 10, compensate: cell.debit);
            stage(scope, cell, cell.credit, 20, compensate: cell.debit);
          },
        );

        expect(cell.balance, 30);
      });

      test('txApply with multiple participants', () async {
        final accounts = pair();
        final tx = Cell.txApply();

        await tx.execute(
          participants: [accounts.a, accounts.b],
          body: (scope) {
            stage(scope, accounts.a, accounts.a.debit, 50,
                compensate: accounts.a.credit);
            stage(scope, accounts.b, accounts.b.credit, 50,
                compensate: accounts.b.debit);
          },
        );

        expect(accounts.a.balance, 50);
        expect(accounts.b.balance, 100);
      });

      test('txApply with custom apply options', () async {
        final events = <TxApplyEvent>[];
        final cell = AccountCell(balance: 0);

        final tx = Cell.txApply(TxApplyOptions(onEvent: events.add));

        await tx.execute(
          participants: [cell],
          body: (scope) {
            stage(scope, cell, cell.credit, 5, compensate: cell.debit);
          },
        );

        expect(events.whereType<TxApplyBegun>(), isNotEmpty);
        expect(events.whereType<TxApplyStaged>(), isNotEmpty);
        expect(events.whereType<TxApplyCommitted>(), isNotEmpty);
        expect(cell.balance, 5);
      });

      test('apply without tx runs immediately', () {
        final cell = AccountCell(balance: 10);
        cell.apply<void>(cmd(cell.credit, [3]));
        expect(cell.balance, 13);
      });
    });

    group('Compensation', () {
      test('compensation is called when a later apply fails', () async {
        final a = AccountCell(balance: 100);
        final b = AccountCell(balance: 50);
        final tx = Cell.txApply();

        await expectLater(
          tx.execute(
            participants: [a, b],
            body: (scope) {
              stage(scope, a, a.debit, 30, compensate: a.credit);
              stage(scope, b, b.debit, 1000, compensate: b.credit);
            },
          ),
          throwsA(isTxApplyException(containing: 'commit failed')),
        );

        expect(a.balance, 100, reason: 'debit 30 was compensated');
        expect(b.balance, 1050,
            reason: 'throwing debit is compensated as attempted');
      });

      test('compensation with custom cell', () async {
        final a = LedgerCell();
        final b = LedgerCell();
        final tx = Cell.txApply();

        await expectLater(
          tx.execute(
            participants: [a, b],
            body: (scope) {
              a.apply<Object?>(
                  cmd(a.record, ['op1'], undo(b.unrecord, ['op1'], null, b)),
                  tx: scope);
              b.apply<Object?>(cmd(b.fail), tx: scope);
            },
          ),
          throwsA(isA<TxApplyException>()),
        );

        expect(a.ops, ['op1']);
        expect(b.ops, ['undo_op1']);
      });

      test('compensation with multiple retries', () async {
        final cell = FlakyUndoCell(value: 0, failTimes: 2);
        final blocker = AccountCell(balance: 0);
        final retries = <TxApplyCompensationRetry>[];

        final tx = Cell.txApply(
          TxApplyOptions(
            compensationMaxAttempts: 3,
            compensationBackoff: (_) => Duration.zero,
            isRetryableCompensationError: (_) => true,
            onEvent: (e) {
              if (e is TxApplyCompensationRetry) retries.add(e);
            },
          ),
        );

        await expectLater(
          tx.execute(
            participants: [cell, blocker],
            body: (scope) {
              cell.apply<Object?>(
                  cmd(cell.add, [10], undo(cell.flakySub, [10])),
                  tx: scope);
              blocker.apply<Object?>(cmd(blocker.fail), tx: scope);
            },
          ),
          throwsA(isA<TxApplyException>()),
        );

        expect(cell.undoAttempts, 3);
        expect(cell.value, 0);
        expect(retries, hasLength(2));
      });

      test('rollback before commit skips compensation by default', () async {
        final cell = LedgerCell();
        final tx = Cell.txApply();

        await tx.begin([cell]);
        cell.apply<Object?>(
            cmd(cell.record, ['op1'], undo(cell.unrecord, ['op1'])),
            tx: tx);
        await tx.rollback();

        expect(cell.ops, isEmpty);
        expect(cell.ops, isNot(contains('undo_op1')));
      });

      test('compensateIfNotExecuted runs undo on rollback of staged calls',
          () async {
        final cell = LedgerCell();
        final tx = Cell.txApply(
          const TxApplyOptions(compensateIfNotExecuted: true),
        );

        await tx.begin([cell]);
        cell.apply<Object?>(
            cmd(cell.record, ['op1'], undo(cell.unrecord, ['op1'])),
            tx: tx);
        await tx.rollback();

        expect(cell.ops, ['undo_op1']);
      });
    });

    group('Error Handling', () {
      test('txApply throws when participant not included', () async {
        final cell1 = AccountCell();
        final cell2 = AccountCell();
        final tx = Cell.txApply();

        await expectLater(
          tx.execute(
            participants: [cell1],
            body: (scope) {
              cell2.apply<Object?>(cmd(cell2.credit, [1]), tx: scope);
            },
          ),
          throwsA(isTxApplyException(containing: 'not a participant')),
        );
      });

      test('enqueue accepts functions outside the modifiable manifest', () async {
        final cell = AccountCell();
        final tx = Cell.txApply();

        // One capability model: the integrity gate — not whitelist
        // membership — authorizes a command. AccountCell carries the
        // default allowAll gate, so this caller-supplied closure commits.
        await tx.execute(
          participants: [cell],
          body: (scope) {
            scope.enqueueCommand(cell, cmd(() => cell.balance = 7));
          },
        );
        expect(cell.balance, 7);
      });

      test('txApply with compensation error policy', () async {
        final cell = LedgerCell();
        final tx = Cell.txApply(
          const TxApplyOptions(
            compensationErrorPolicy: CompensationErrorPolicy.bestEffort,
          ),
        );

        await expectLater(
          tx.execute(
            participants: [cell],
            body: (scope) {
              cell.apply<Object?>(
                  cmd(cell.record, ['op1'], undo(cell.boomUndo, ['op1'])),
                  tx: scope);
              cell.apply<Object?>(cmd(cell.fail), tx: scope);
            },
          ),
          throwsA(isTxApplyException(containing: 'commit failed')),
        );

        expect(cell.ops, ['op1']);
      });

      test('txApply with failFast compensation policy', () async {
        final cell = LedgerCell();
        final tx = Cell.txApply(
          const TxApplyOptions(
            compensationErrorPolicy: CompensationErrorPolicy.failFast,
          ),
        );

        await expectLater(
          tx.execute(
            participants: [cell],
            body: (scope) {
              cell.apply<Object?>(
                  cmd(cell.record, ['op1'], undo(cell.boomUndo, ['op1'])),
                  tx: scope);
              cell.apply<Object?>(cmd(cell.fail), tx: scope);
            },
          ),
          throwsA(isTxApplyException(containing: 'compensation also failed')),
        );
        expect(cell.ops, ['op1']);
      });

      test('txApply with collectThenThrow compensation policy', () async {
        final cell = LedgerCell();
        final tx = Cell.txApply(
          const TxApplyOptions(
            compensationErrorPolicy: CompensationErrorPolicy.collectThenThrow,
          ),
        );

        await expectLater(
          tx.execute(
            participants: [cell],
            body: (scope) {
              cell.apply<Object?>(
                  cmd(cell.record, ['op1'], undo(cell.boomUndo, ['op1'])),
                  tx: scope);
              cell.apply<Object?>(
                  cmd(cell.record, ['op2'], undo(cell.boomUndo, ['op2'])),
                  tx: scope);
              cell.apply<Object?>(cmd(cell.fail), tx: scope);
            },
          ),
          throwsA(isTxApplyException(containing: 'compensation also failed')),
        );
        expect(cell.ops, ['op1', 'op2']);
      });
    });

    group('Stop On First Failure', () {
      test('stopOnFirstFailure stops execution on first failure', () async {
        final cell = AccountCell(balance: 0);
        final rejected = <TxApplyRejected>[];
        final tx = Cell.txApply(
          TxApplyOptions(
            stopOnFirstFailure: true,
            onEvent: (e) {
              if (e is TxApplyRejected) rejected.add(e);
            },
          ),
        );

        await expectLater(
          tx.execute(
            participants: [cell],
            body: (scope) {
              cell.apply<Object?>(cmd(cell.reject), tx: scope);
              stage(scope, cell, cell.credit, 5, compensate: cell.debit);
            },
          ),
          throwsA(
            isTxApplyException(containing: 'commit failed').having(
              (e) => e.cause,
              'cause',
              isTxApplyException(containing: 'integrity gate'),
            ),
          ),
        );
        expect(cell.balance, 0, reason: 'later credit must not run');
        expect(rejected, isNotEmpty);
        expect(rejected.first.reason, 'ApplyRejected');
      });

      test('stopOnFirstFailure false continues execution', () async {
        final cell = AccountCell(balance: 0);
        final tx = Cell.txApply(
          const TxApplyOptions(stopOnFirstFailure: false),
        );

        await tx.execute(
          participants: [cell],
          body: (scope) {
            cell.apply<Object?>(cmd(cell.reject), tx: scope);
            stage(scope, cell, cell.credit, 10, compensate: cell.debit);
          },
        );

        expect(cell.balance, 10);
      });

      test(
          'a rejected command is not compensated when a later command '
          'throws (stopOnFirstFailure: false)', () async {
        final cell = AccountCell(balance: 0);
        final tx = Cell.txApply(
          const TxApplyOptions(stopOnFirstFailure: false),
        );

        await expectLater(
          tx.execute(
            participants: [cell],
            body: (scope) {
              // Gate-rejected: never executed, so its compensation (`fail`
              // as a sentinel) must not run during the rollback below — a
              // wrongful compensation would surface as a compensation
              // failure, not a plain commit failure.
              cell.apply<Object?>(
                cmd(cell.reject, [], undo(cell.fail, [], null, cell)),
                tx: scope,
              );
              stage(scope, cell, cell.credit, 10, compensate: cell.debit);
              cell.apply<Object?>(cmd(cell.fail), tx: scope);
            },
          ),
          throwsA(
            isTxApplyException(containing: 'commit failed').having(
              (e) => e.message,
              'message',
              isNot(contains('compensation')),
            ),
          ),
        );
        // Only the executed credit was compensated; the rejected command's
        // compensation never ran.
        expect(cell.balance, 0);
      });
    });

    group('Savepoint', () {
      test('txApply savepoint captures state', () async {
        final cell = AccountCell(balance: 0);
        final tx = Cell.txApply();

        await tx.begin([cell]);
        stage(tx, cell, cell.credit, 10, compensate: cell.debit);
        final sp = tx.savepoint();
        stage(tx, cell, cell.credit, 20, compensate: cell.debit);
        expect(sp, isNotNull);

        await tx.rollback(savepoint: sp);
        await tx.commit();

        expect(cell.balance, 10);
      });

      test('txApply rollback to savepoint', () async {
        final cell = AccountCell(balance: 0);
        final tx = Cell.txApply();

        await tx.begin([cell]);
        stage(tx, cell, cell.credit, 10, compensate: cell.debit);
        final sp = tx.savepoint();
        stage(tx, cell, cell.credit, 20, compensate: cell.debit);
        await tx.rollback(savepoint: sp);
        await tx.commit();

        expect(cell.balance, 10);
      });

      test('txApply rollback all', () async {
        final cell = AccountCell(balance: 0);
        final tx = Cell.txApply();

        await tx.begin([cell]);
        stage(tx, cell, cell.credit, 10, compensate: cell.debit);
        stage(tx, cell, cell.credit, 20, compensate: cell.debit);
        await tx.rollback();

        expect(cell.balance, 0);
        await expectLater(
          tx.commit(),
          throwsA(isTxApplyException(containing: 'already finished')),
        );
      });

      test('txApply rollback with unknown savepoint throws', () async {
        final events = <TxApplyEvent>[];
        final cell = AccountCell(balance: 0);
        final tx = Cell.txApply(TxApplyOptions(onEvent: events.add));

        await tx.begin([cell]);
        stage(tx, cell, cell.credit, 10, compensate: cell.debit);

        await expectLater(
          tx.rollback(savepoint: 999),
          throwsA(isA<ArgumentError>()),
        );

        // Fail closed: no rollback may have happened, silently or otherwise.
        expect(events.whereType<TxApplyRolledBack>(), isEmpty);
        expect(cell.balance, 0);

        await tx.commit();
        expect(cell.balance, 10);
      });

      test('txApply rollback rejects a savepoint from another scope', () async {
        final cell = AccountCell(balance: 0);
        final tx = Cell.txApply();
        final other = Cell.txApply();

        await tx.begin([cell]);
        await other.begin([cell]);
        final foreign = other.savepoint();
        stage(tx, cell, cell.credit, 10, compensate: cell.debit);

        await expectLater(
          tx.rollback(savepoint: foreign),
          throwsA(isA<ArgumentError>()),
        );

        // The foreign savepoint must not roll back this scope, even partially.
        expect(cell.balance, 0);

        await tx.commit();
        expect(cell.balance, 10);
        await other.rollback();
      });
    });

    group('Real-World Scenarios', () {
      test('txApply for bank transfer with compensation', () async {
        final from = AccountCell(balance: 100);
        final to = AccountCell(balance: 50);
        final tx = Cell.txApply();

        await tx.execute(
          participants: [from, to],
          body: (scope) {
            stage(scope, from, from.debit, 30, compensate: from.credit);
            stage(scope, to, to.credit, 30, compensate: to.debit);
          },
        );

        expect(from.balance, 70);
        expect(to.balance, 80);
      });

      test('oversized transfer rolls back via compensation', () async {
        final from = AccountCell(balance: 100);
        final to = AccountCell(balance: 50);
        final tx = Cell.txApply();

        await expectLater(
          tx.execute(
            participants: [from, to],
            body: (scope) {
              stage(scope, from, from.debit, 30, compensate: from.credit);
              stage(scope, to, to.credit, 30, compensate: to.debit);
              stage(scope, from, from.debit, 1000, compensate: from.credit);
            },
          ),
          throwsA(isA<TxApplyException>()),
        );

        expect(from.balance, 1100,
            reason: 'both debits compensated (throwing debit credited back)');
        expect(to.balance, 50);
      });

      test('txApply for multi-step data migration', () async {
        final source = AccountCell(balance: 100);
        final target = AccountCell(balance: 0);
        final backup = AccountCell(balance: 0);
        final tx = Cell.txApply();

        await tx.execute(
          participants: [source, target, backup],
          body: (scope) {
            stage(scope, backup, backup.credit, 0, compensate: backup.debit);
            stage(scope, target, target.credit, 100, compensate: target.debit);
            stage(scope, source, source.debit, 100, compensate: source.credit);
          },
        );

        expect(source.balance, 0);
        expect(target.balance, 100);
        expect(backup.balance, 0);
      });

      test('txApply for inventory adjustment', () async {
        final inventory = AccountCell(balance: 50);
        final order = AccountCell(balance: 10);
        final tx = Cell.txApply();

        await tx.execute(
          participants: [inventory, order],
          body: (scope) {
            stage(scope, inventory, inventory.debit, 10,
                compensate: inventory.credit);
            stage(scope, order, order.debit, 10, compensate: order.credit);
          },
        );

        expect(inventory.balance, 40);
        expect(order.balance, 0);
      });
    });

    group('Events', () {
      test('TxApplyBegun event emitted', () async {
        TxApplyBegun? begunEvent;
        final cell = AccountCell();

        final tx = Cell.txApply(
          TxApplyOptions(onEvent: (event) {
            if (event is TxApplyBegun) begunEvent = event;
          }),
        );

        await tx.begin([cell]);

        expect(begunEvent, isNotNull);
        expect(begunEvent!.participants, [cell]);

        await tx.commit();
      });

      test('TxApplyStaged event emitted', () async {
        TxApplyStaged? stagedEvent;
        final cell = AccountCell();

        final tx = Cell.txApply(
          TxApplyOptions(onEvent: (event) {
            if (event is TxApplyStaged) stagedEvent = event;
          }),
        );

        await tx.begin([cell]);
        stage(tx, cell, cell.credit, 5, compensate: cell.debit);

        expect(stagedEvent, isNotNull);
        expect(stagedEvent!.cell, same(cell));
        expect(stagedEvent!.function, same(cell.credit));

        await tx.commit();
        expect(cell.balance, 5);
      });

      test('TxApplyCommitted event emitted', () async {
        TxApplyCommitted? committedEvent;
        final cell = AccountCell();

        final tx = Cell.txApply(
          TxApplyOptions(onEvent: (event) {
            if (event is TxApplyCommitted) committedEvent = event;
          }),
        );

        await tx.execute(
          participants: [cell],
          body: (scope) {
            stage(scope, cell, cell.credit, 5, compensate: cell.debit);
          },
        );

        expect(committedEvent, isNotNull);
        expect(committedEvent!.callCount, 1);
        expect(cell.balance, 5);
      });

      test('TxApplyRolledBack event emitted', () async {
        TxApplyRolledBack? rolledBackEvent;
        final cell = AccountCell();

        final tx = Cell.txApply(
          TxApplyOptions(onEvent: (event) {
            if (event is TxApplyRolledBack) rolledBackEvent = event;
          }),
        );

        await tx.begin([cell]);
        stage(tx, cell, cell.credit, 5, compensate: cell.debit);
        await tx.rollback();

        expect(rolledBackEvent, isNotNull);
        expect(rolledBackEvent!.savepoint, isNull);
        expect(cell.balance, 0);
      });

      test('TxApplyRejected event emitted on gate rejection', () async {
        final rejected = <TxApplyRejected>[];
        final cell = AccountCell();
        void block(int amount) => cell.balance -= amount;
        final gate = TestCell((object, {host, arguments, user}) {
          // Reject the debit action itself.
          return object is! Function;
        });
        final gated = await cell.deputy(testRule: gate);

        final tx = Cell.txApply(
          TxApplyOptions(onEvent: (event) {
            if (event is TxApplyRejected) rejected.add(event);
          }),
        );

        await expectLater(
          tx.execute(
            participants: [gated],
            body: (scope) {
              scope.enqueueCommand(gated, cmd(block, [5]));
            },
          ),
          throwsA(isA<TxApplyException>()),
        );

        expect(rejected, isNotEmpty);
        expect(rejected.first.reason, 'integrity gate');
        expect(cell.balance, 0);
      });
    });

    group('Edge Cases & Error Handling', () {
      test('txApply with empty participants throws', () async {
        final tx = Cell.txApply();
        await expectLater(tx.begin([]), throwsA(isA<ArgumentError>()));
      });

      test('txApply commit without begin throws', () async {
        final tx = Cell.txApply();
        await expectLater(
          tx.commit(),
          throwsA(isTxApplyException(containing: 'not begun')),
        );
      });

      test('txApply with null compensation', () async {
        final cell = AccountCell(balance: 0);
        final tx = Cell.txApply();

        await tx.execute(
          participants: [cell],
          body: (scope) {
            cell.apply<Object?>(cmd(cell.credit, [5]), tx: scope);
          },
        );

        expect(cell.balance, 5);
      });

      test('txApply with compensation cell different from operation cell',
          () async {
        final a = AccountCell(balance: 10);
        final b = AccountCell(balance: 10);
        final tx = Cell.txApply();

        await expectLater(
          tx.execute(
            participants: [a, b],
            body: (scope) {
              a.apply<Object?>(cmd(a.credit, [5], undo(b.debit, [5], null, b)),
                  tx: scope);
              b.apply<Object?>(cmd(b.fail), tx: scope);
            },
          ),
          throwsA(isA<TxApplyException>()),
        );

        expect(a.balance, 15);
        expect(b.balance, 5);
      });

      test('txApply with compensation named arguments', () async {
        final cell = LedgerCell();
        final tx = Cell.txApply();

        await expectLater(
          tx.execute(
            participants: [cell],
            body: (scope) {
              cell.apply<Object?>(
                  cmd(cell.record, ['op1'],
                      undo(cell.unrecordNamed, null, {#name: 'op1'})),
                  tx: scope);
              cell.apply<Object?>(cmd(cell.fail), tx: scope);
            },
          ),
          throwsA(isA<TxApplyException>()),
        );

        expect(cell.ops, ['op1', 'undo_op1']);
      });

      test('begin while already begun throws', () async {
        final cell = AccountCell();
        final tx = Cell.txApply();
        await tx.begin([cell]);
        await expectLater(
          tx.begin([cell]),
          throwsA(isTxApplyException(containing: 'already begun')),
        );
        await tx.rollback();
      });
    });

    group('Custom Comparator', () {
      test('txApply with custom comparator', () async {
        final cell1 = AccountCell(balance: 1);
        final cell2 = AccountCell(balance: 2);
        final cell3 = AccountCell(balance: 3);
        final applied = <int>[];

        final tx = Cell.txApply(
          TxApplyOptions(
            comparator: (a, b) => b.hashCode.compareTo(a.hashCode),
          ),
        );

        await tx.execute(
          participants: [cell1, cell2, cell3],
          body: (scope) {
            cell1.apply<Object?>(cmd(cell1.credit, [9]), tx: scope);
            cell2.apply<Object?>(cmd(cell2.credit, [18]), tx: scope);
            cell3.apply<Object?>(cmd(cell3.credit, [27]), tx: scope);
          },
        );

        // comparator is accepted; applies still run in enqueue order.
        applied.addAll([cell1.balance, cell2.balance, cell3.balance]);
        expect(applied, [10, 20, 30]);
      });
    });

    group('Exception toString', () {
      test('TxApplyException toString', () {
        final exception = TxApplyException('Test error');
        final str = exception.toString();
        expect(str, contains('TxApplyException'));
        expect(str, contains('Test error'));
      });

      test('TxApplyCompensationException toString', () {
        final failures = [
          CompensationFailure(
            cell: AccountCell(),
            error: Exception('Compensation failed'),
          ),
        ];
        final exception =
            TxApplyCompensationException('Compensation error', failures);
        final str = exception.toString();
        expect(str, contains('TxApplyCompensationException'));
        expect(str, contains('Compensation error'));
        expect(str, contains('1 failure'));
      });

      test('enqueue rejects a compensate cell that is not a participant',
          () async {
        final a = AccountCell(balance: 10);
        final b = AccountCell(balance: 10);
        final tx = Cell.txApply();
        await tx.begin([a]);
        expect(
          () => a.apply<Object?>(
              cmd(a.credit, [1], undo(b.debit, [1], null, b)),
              tx: tx),
          throwsA(isTxApplyException(containing: 'compensate cell')),
        );
        await tx.rollback();
      });

      test('enqueue accepts a compensate function outside the manifest',
          () async {
        final cell = AccountCell(balance: 10);
        void outsider() {}
        final tx = Cell.txApply();
        await tx.begin([cell]);
        // One capability model: compensation authorization comes from the
        // integrity gate, not whitelist membership.
        final outcome = cell.apply<Object?>(
            cmd(cell.credit, [1], undo(outsider)), tx: tx);
        expect(outcome, isA<ApplyStaged>());
        await tx.rollback();
      });

      test('commit ignores manifest removal; the gate decides', () async {
        final cell = MutableModifiableCell();
        final tx = Cell.txApply();
        await tx.begin([cell]);
        cell.apply<Object?>(cmd(cell.add, [3]), tx: tx);
        cell.allowed.remove(cell.add);
        await tx.commit();
        expect(cell.value, 3);
      });

      test('commit ignores compensate manifest removal; the gate decides',
          () async {
        final cell = MutableModifiableCell();
        final tx = Cell.txApply();
        await tx.begin([cell]);
        cell.apply<Object?>(cmd(cell.add, [3], undo(cell.sub, [3])), tx: tx);
        cell.allowed.remove(cell.sub);
        await tx.commit();
        expect(cell.value, 3);
      });

      test('default compensation backoff retries a transient undo', () async {
        final cell = FlakyUndoCell(value: 0, failTimes: 1);
        final blocker = AccountCell(balance: 0);
        final tx = Cell.txApply(
          const TxApplyOptions(compensationMaxAttempts: 2),
        );

        await expectLater(
          tx.execute(
            participants: [cell, blocker],
            body: (scope) {
              cell.apply<Object?>(
                  cmd(cell.add, [10], undo(cell.flakySub, [10])),
                  tx: scope);
              blocker.apply<Object?>(cmd(blocker.fail), tx: scope);
            },
          ),
          throwsA(isA<TxApplyException>()),
        );
        expect(cell.undoAttempts, 2);
        expect(cell.value, 0);
      });

      test('compensation ApplyRejected is not retryable by default', () async {
        final cell = AccountCell(balance: 10);
        final blocker = AccountCell(balance: 0);
        final tx = Cell.txApply(
          const TxApplyOptions(compensationMaxAttempts: 3),
        );

        await expectLater(
          tx.execute(
            participants: [cell, blocker],
            body: (scope) {
              cell.apply<Object?>(
                cmd(cell.credit, [5], undo(cell.reject)),
                tx: scope,
              );
              blocker.apply<Object?>(cmd(blocker.fail), tx: scope);
            },
          ),
          throwsA(isA<TxApplyException>()),
        );
        expect(cell.balance, 15);
      });

      test('ApplyRejected during commit rethrows failFast compensation',
          () async {
        final ledger = LedgerCell();
        final cell = AccountCell(balance: 0);
        final tx = Cell.txApply(
          const TxApplyOptions(
            compensationErrorPolicy: CompensationErrorPolicy.failFast,
          ),
        );

        await expectLater(
          tx.execute(
            participants: [ledger, cell],
            body: (scope) {
              ledger.apply<Object?>(
                  cmd(ledger.record, ['op1'], undo(ledger.boomUndo, ['op1'])),
                  tx: scope);
              cell.apply<Object?>(cmd(cell.reject), tx: scope);
            },
          ),
          throwsA(isA<TxApplyCompensationException>()),
        );
      });

      test('CompensationFailure toString', () {
        final failure = CompensationFailure(
          cell: AccountCell(),
          error: Exception('Failed'),
        );
        final str = failure.toString();
        expect(str, contains('CompensationFailure'));
        expect(str, contains('Failed'));
      });
    });
  });
}
