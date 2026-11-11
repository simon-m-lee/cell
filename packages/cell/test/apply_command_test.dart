// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:test/test.dart';

// ─────────────────────────────────────────────────────────────────────────
// Fixtures
//
// The forensic Apply Command model: ApplyCommand / ApplyOutcome / ApplyReceipt,
// the builder DSL, and the deprecated legacy gateway shim.
// ─────────────────────────────────────────────────────────────────────────

class AccountCell extends CellBase {
  int balance = 0;

  late final int Function(int amount) credit;
  late final void Function(int amount) debit;
  late final int Function({required int amount}) creditNamed;
  late final dynamic Function() veto;

  AccountCell({super.testRule}) {
    credit = _credit;
    debit = _debit;
    creditNamed = _creditNamed;
    veto = _veto;
  }

  int _credit(int amount) {
    balance += amount;
    return balance;
  }

  void _debit(int amount) {
    balance -= amount;
  }

  int _creditNamed({required int amount}) => _credit(amount);

  dynamic _veto() => ApplyVeto.instance;

  @override
  Iterable<Function> get modifiable => {credit, debit, creditNamed, veto, apply};
}

/// A gate that records the [ApplyCommand] it received.
class CommandAwareGate extends TestCell<Cell> {
  CommandAwareGate() : super.fromRecord(());

  ApplyCommand? seen;
  bool allow = true;

  @override
  FutureOr<bool> action(Function action,
      {required Cell host, Arguments? arguments, ApplyCommand? command}) {
    seen = command;
    return allow;
  }

  @override
  FutureOr<bool> call(object, {covariant Cell? host, arguments}) => true;

  @override
  FutureOr<bool> link(covariant Cell link, {required Cell host}) => true;

  @override
  FutureOr<bool> pulse(covariant Pulse pulse, {required Cell host}) => true;
}

void main() {
  group('Apply command model', () {
    test('execute accepts a command and returns its typed result', () async {
      final cell = AccountCell();
      final command = (
        function: cell.credit,
        arguments: (positionalArguments: [5], namedArguments: null),
        compensation: null,
      );

      final outcome = await cell.apply<int>(command);

      expect(outcome, isA<ApplyAccepted<int>>());
      final accepted = outcome as ApplyAccepted<int>;
      expect(accepted.result, 5);
      expect(cell.balance, 5);
    });

    test('receipt carries forensic provenance', () async {
      final cell = AccountCell();
      final command = (
        function: cell.credit,
        arguments: (positionalArguments: [3], namedArguments: null),
        compensation: null,
      );

      final outcome = await cell.apply<int>(command) as ApplyAccepted<int>;

      final receipt = outcome.receipt;
      expect(receipt.id, isNotEmpty);
      expect(receipt.cell, same(cell));
      expect(receipt.function, same(cell.credit));
      expect(receipt.arguments.positionalArguments, [3]);
      expect(receipt.timestamp, isA<DateTime>());
      expect(receipt.txSequence, isNull);
      expect(receipt.vetted, isTrue);
    });

    test('gate rejection returns ApplyRejected', () async {
      final gate = CommandAwareGate()..allow = false;
      final cell = AccountCell(testRule: gate);
      final command = (
        function: cell.credit,
        arguments: (positionalArguments: [5], namedArguments: null),
        compensation: null,
      );

      final outcome = await cell.apply<int>(command);

      expect(outcome, isA<ApplyRejected<int>>());
      expect(cell.balance, 0);
      expect(outcome.receipt.vetted, isTrue);
    });

    test('the gate receives the complete command including compensation',
        () async {
      final gate = CommandAwareGate();
      final cell = AccountCell(testRule: gate);
      final command = (
        function: cell.credit,
        arguments: (positionalArguments: [5], namedArguments: null),
        compensation: (
          function: cell.debit,
          arguments: (positionalArguments: [5], namedArguments: null),
          cell: null,
        ),
      );

      await cell.apply<int>(command);

      expect(gate.seen, isNotNull);
      expect(gate.seen!.function, same(cell.credit));
      expect(gate.seen!.compensation!.function, same(cell.debit));
    });

    test('unvetted functions execute but the receipt records it', () async {
      final cell = AccountCell();
      int called = 0;
      void outsider() => called++;

      final outcome = await cell.apply<void>((
        function: outsider,
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      ));

      expect(outcome, isA<ApplyAccepted<void>>());
      expect(called, 1);
      expect(outcome.receipt.vetted, isFalse);
    });

    test('tx staging returns ApplyStaged with a sequence and commits',
        () async {
      final cell = AccountCell();
      final tx = Cell.txApply();

      late ApplyOutcome<int> staged;
      await tx.execute(participants: [cell], body: (scope) async {
        staged = await cell.apply<int>(
          (
            function: cell.credit,
            arguments: (positionalArguments: [5], namedArguments: null),
            compensation: null,
          ),
          tx: scope,
        );
      });

      expect(staged, isA<ApplyStaged>());
      expect(staged.receipt.txSequence, 0);
      expect(cell.balance, 5);
    });

    test('async gate returns a Future outcome', () async {
      final cell = AccountCell(
        testRule: TestCell<Cell>((object, {host, arguments, user}) async {
          await Future<void>.delayed(Duration.zero);
          return true;
        }),
      );

      final outcome = await cell.apply<int>((
        function: cell.credit,
        arguments: (positionalArguments: [2], namedArguments: null),
        compensation: null,
      ));

      expect(outcome, isA<ApplyAccepted<int>>());
      expect((outcome as ApplyAccepted<int>).result, 2);
    });

    test('builder DSL assembles and runs a command', () async {
      final cell = AccountCell();

      final outcome = await cell
          .command(cell.creditNamed)
          .named({#amount: 9})
          .run<int>();

      expect(outcome, isA<ApplyAccepted<int>>());
      expect((outcome as ApplyAccepted<int>).result, 9);
      expect(cell.balance, 9);
    });

    test('builder DSL attaches a compensation blueprint', () async {
      final cell = AccountCell();
      final tx = Cell.txApply();

      await tx.execute(participants: [cell], body: (scope) async {
        await cell
            .command(cell.credit)
            .arg(5)
            .undo(cell.debit, args: [5])
            .run(tx: scope);
      });

      expect(cell.balance, 5);
    });

    test('deputy execute forwards to the principal', () async {
      final cell = AccountCell(testRule: TestCell.readOnly);
      final deputy = await cell.deputy(testRule: TestCell.readOnly);

      // The deputy has an empty whitelist; the principal's gate governs.
      final outcome = await deputy.apply<int>((
        function: cell.credit,
        arguments: (positionalArguments: [4], namedArguments: null),
        compensation: null,
      ));

      // readOnly gate rejects the action
      expect(outcome, isA<ApplyRejected<int>>());
      expect(cell.balance, 0);
    });

    test('async execute returns a Future outcome', () async {
      final cell = AccountCell();

      final outcome = await cell.async.apply<int>((
        function: cell.credit,
        arguments: (positionalArguments: [7], namedArguments: null),
        compensation: null,
      ));

      expect(outcome, isA<ApplyAccepted<int>>());
      expect((outcome as ApplyAccepted<int>).result, 7);
    });

    test('ApplyVeto soft-reject is honored at commit', () async {
      final cell = AccountCell();
      final tx = Cell.txApply();

      await expectLater(
        tx.execute(participants: [cell], body: (scope) {
          cell.apply<dynamic>(
            (
              function: cell.veto,
              arguments: (positionalArguments: null, namedArguments: null),
              compensation: null,
            ),
            tx: scope,
          );
        }),
        throwsA(isA<TxApplyException>()),
      );
      expect(cell.balance, 0);
    });
  });
}
