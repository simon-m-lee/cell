// Integration test: the live audit demo's ledger mechanics, rendered by
// AuditTrailView.
//
// The audit demo (demo/audit_trail) proves three mechanisms with a counter:
// `Cell.apply` mints a receipt for the add, a `TestCell` integrity gate
// rejects the negative mutation, and a `Cell.txApply` transaction executes
// the recorded compensation as `subtract`. This test replays exactly that
// ledger — same cell shape, same gate seam, same transaction — and asserts
// that `cell_flutter_audit` renders the same receipts the demo renders by
// hand.
library;

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:cell_flutter_audit/cell_flutter_audit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The demo's counter: commands only, no value setter.
class AuditCounterCell extends CellBase {
  AuditCounterCell() : super(testRule: AuditGate()) {
    add = _add;
    subtract = _subtract;
    negative = _negative;
  }

  int value = 10;

  late final void Function(int delta) add;
  late final void Function(int delta) subtract;
  late final void Function(int delta) negative;

  void _add(int delta) => value += delta;

  void _subtract(int delta) => value -= delta;

  /// Would move the value below zero — rejected by the integrity gate.
  void _negative(int delta) => value = -value;

  @override
  Iterable<Function> get modifiable => {add, subtract, negative, apply};
}

/// The demo's gate: rejects only the `negative` command.
class AuditGate extends TestCell<Cell> {
  AuditGate() : super.fromRecord(());

  @override
  FutureOr<bool> action(
    Function action, {
    required Cell host,
    Arguments? arguments,
    ApplyCommand? command,
  }) =>
      !identical(action, (host as AuditCounterCell).negative);
}

ApplyCommand _command(Function function, List<Object?> args) => (
      function: function,
      arguments: (positionalArguments: args, namedArguments: null),
      compensation: null,
    );

void main() {
  testWidgets('renders the demo ledger: add, rejection, txApply undo',
      (tester) async {
    final counter = AuditCounterCell();
    final controller = AuditTrailController();

    // ── 1. The accepted mutation: add (+5) ──────────────────────────────
    final accepted =
        await counter.apply<void>(_command(counter.add, [5]));
    expect(accepted, isA<ApplyAccepted<void>>());
    controller.addOutcome(accepted);

    // ── 2. The governed rejection: negative (−20) ───────────────────────
    final beforeRejection = counter.value;
    final rejected =
        await counter.apply<void>(_command(counter.negative, [20]));
    expect(rejected, isA<ApplyRejected<void>>());
    expect(counter.value, beforeRejection, reason: 'the gate blocks it');
    // The demo's UI copy — the gate itself returns no reason string, so
    // the demo (and this harness) attach it when recording the denial.
    controller.addRejection(RejectionEvent(
      receipt: (rejected as ApplyRejected<void>).receipt,
      reason: 'negative mutations are not allowed',
    ));

    // ── 3. The recorded compensation inside a real txApply ──────────────
    // The undo executes `subtract` (the compensation of `add`) in a
    // transaction, minting its own staged receipt — the same flow the
    // demo's undo button runs.
    final undoCommand = _command(counter.subtract, [5]);
    final tx = Cell.txApply();
    ApplyStaged? staged;
    await tx.execute(participants: [counter], body: (scope) {
      staged = counter.apply<Never>(undoCommand, tx: scope) as ApplyStaged;
    });
    expect(staged, isNotNull);
    expect(staged!.receipt.txSequence, isNotNull);
    controller.addOutcome(staged!);
    expect(counter.value, 10, reason: 'the undo reverted the add');

    // ── Render the package's view over the demo's ledger ────────────────
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AuditTrailView(controller: controller)),
    ));

    // The accepted add and its txApply undo, with their receipts.
    expect(find.text('add'), findsOneWidget);
    expect(find.text('subtract'), findsOneWidget);
    expect(find.textContaining('tx #'), findsOneWidget);
    // The gate's denial, with the demo's exact copy.
    expect(
      find.textContaining(
          'Rejected by the integrity gate: negative mutations are not allowed'),
      findsOneWidget,
    );
    // Accepted commands are vetted; the denial is separate.
    expect(find.byIcon(Icons.verified), findsNWidgets(2));
    expect(controller.entries, hasLength(2));
    expect(controller.rejections, hasLength(1));

    // Filtering works on the demo's data.
    controller.filterBy(commandName: 'add');
    await tester.pumpAndSettle();
    expect(find.text('add'), findsOneWidget);
    expect(find.text('subtract'), findsNothing);
  });
}
