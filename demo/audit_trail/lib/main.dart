// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Live "Audit Trail" demo for the Cell framework.
///
/// One screen proves the framework's core proposition in under a minute:
///
/// * **Auditable** — every mutation goes through `Cell.apply`, so every
///   mutation produces an [ApplyReceipt] with a correlation id, timestamp,
///   capability-manifest (`vetted`) flag, and the exact command arguments.
/// * **Governed** — an [TestCell] integrity gate sits in front of every
///   command. The "Try invalid mutation" button is rejected by the gate and
///   the state does not change.
/// * **Reversible** — the accepted mutation carries an
///   [ApplyCompensation] blueprint (the same mechanism `Cell.txApply` uses
///   for Saga compensation of multi-step commits), and the undo button
///   executes that compensation *inside a real `Cell.txApply` transaction*,
///   producing its own receipt in the ledger.
///
/// This is a demo of mechanism, not a mockup: every card in the ledger is a
/// real [ApplyReceipt] minted by the `cell` package.
library;

import 'dart:async';

import 'package:cell_flutter/cell_flutter.dart';
// ignore: depend_on_referenced_packages (dev-only; assert-guarded in release)
import 'package:cell_flutter_devtools/cell_flutter_devtools.dart';
import 'package:flutter/material.dart';

// ────────────────────────────────────────────────────────────────────────────
// The audited state — a Cell whose mutations only exist as commands.
//
// `AuditCounterCell` mirrors the canonical apply-command pattern: the
// command functions mutate the value and the cell's capability manifest
// (`modifiable`) names them, so every receipt is `vetted: true`. There is
// no `value = …` setter on this type — apply is the only mutation path.
// ────────────────────────────────────────────────────────────────────────────

class AuditCounterCell extends CellBase {
  AuditCounterCell({super.testRule}) {
    add = _add;
    subtract = _subtract;
    negative = _negative;
  }

  /// The current value. Read freely; mutate only through [apply].
  int value = 10;

  late final int Function(int amount) add;
  late final int Function(int amount) subtract;
  late final int Function(int amount) negative;

  int _add(int amount) {
    value += amount;
    return value;
  }

  int _subtract(int amount) {
    value -= amount;
    return value;
  }

  /// Would move the value below zero. The integrity gate rejects this
  /// function before it ever runs.
  int _negative(int amount) {
    value += amount;
    return value;
  }

  /// The capability manifest: these are the commands the demo may run.
  /// Membership is what makes `receipt.vetted` true.
  @override
  Iterable<Function> get modifiable => {add, subtract, negative, apply};
}

/// The integrity gate.
///
/// A `TestCell` whose [action] rule rejects the `negative` command and
/// admits everything else. This is the framework's governance seam: the
/// rejection below is produced by the gate, not by the demo's own `if`.
class AuditGate extends TestCell<Cell> {
  AuditGate() : super.fromRecord(());

  @override
  FutureOr<bool> action(
    Function action, {
    required Cell host,
    Arguments? arguments,
    ApplyCommand? command,
  }) {
    // Only `negative` is forbidden — every other command passes.
    return !identical(action, (host as AuditCounterCell).negative);
  }

  @override
  FutureOr<bool> call(object, {covariant Cell? host, arguments}) => true;

  @override
  FutureOr<bool> link(covariant Cell link, {required Cell host}) => true;

  @override
  FutureOr<bool> pulse(covariant Pulse pulse, {required Cell host}) => true;
}

/// One row of the visible ledger: the real [ApplyReceipt] plus the demo's
/// presentation metadata (label, before/after, rejection reason).
class LedgerEntry {
  LedgerEntry({
    required this.receipt,
    required this.label,
    required this.before,
    this.after,
    this.rejected = false,
    this.compensation,
  });

  final ApplyReceipt receipt;
  final String label;
  final int before;
  final int? after;
  final bool rejected;
  final ApplyCompensation? compensation;
}

// ────────────────────────────────────────────────────────────────────────────
// The demo application.
// ────────────────────────────────────────────────────────────────────────────

/// Exposed to the DevTools extension (`ext.cell.getLedger`).
final _devtoolsReceipts = <ApplyReceipt>[];
final _devtoolsRejections = <CellDevtoolsRejection>[];

void main() {
  registerCellDevTools(
      receipts: () => List.of(_devtoolsReceipts),
      rejections: () => List.of(_devtoolsRejections));
  runApp(const AuditTrailApp());
}

class AuditTrailApp extends StatelessWidget {
  const AuditTrailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'cell — Audit Trail',
      home: AuditTrailDemo(),
    );
  }
}

class AuditTrailDemo extends StatefulWidget {
  const AuditTrailDemo({super.key});

  @override
  State<AuditTrailDemo> createState() => _AuditTrailDemoState();
}

class _AuditTrailDemoState extends State<AuditTrailDemo> {
  final AuditCounterCell _counter = AuditCounterCell(testRule: AuditGate());

  /// Reactive projection of the audited value for `CellBuilder`. This is
  /// UI plumbing only — the counter itself is mutated exclusively through
  /// `Cell.apply`.
  late final StateHandle<int> _display =
      Cell.state<int>(initial: _counter.value);

  final List<LedgerEntry> _receipts = [];

  ApplyCompensation? _lastCompensation;

  Future<void> _run({
    required ApplyCommand command,
    required String label,
  }) async {
    final before = _counter.value;
    final outcome = await _counter.apply<int>(command);
    switch (outcome) {
      case ApplyAccepted<int>(result: final after, receipt: final r):
        _devtoolsReceipts.add(r);
        setState(() {
          _counter.value = after;
          _display.update(after);
          _receipts.add(LedgerEntry(
            receipt: r,
            label: label,
            before: before,
            after: after,
            compensation: command.compensation,
          ));
          if (command.compensation != null) {
            _lastCompensation = command.compensation;
          }
        });
      case ApplyRejected<int>(receipt: final r):
        _devtoolsRejections.add(CellDevtoolsRejection(
            receipt: r, reason: 'negative mutations are not allowed'));
        setState(() {
          _receipts.add(LedgerEntry(
            receipt: r,
            label: label,
            before: before,
            rejected: true,
          ));
        });
      case ApplyStaged():
        // The undo path handles staged receipts explicitly.
        break;
    }
  }

  void _addFive() {
    // The DSL attaches the reversal blueprint — the exact mechanism
    // `Cell.txApply` uses for Saga compensation of multi-step commits.
    final command = _counter
        .command(_counter.add)
        .arg(5)
        .undo(_counter.subtract, args: [5])
        .build();
    _run(command: command, label: 'add (+5)');
  }

  void _tryInvalid() {
    final command = (
      function: _counter.negative,
      arguments: (positionalArguments: [-20], namedArguments: null),
      compensation: null,
    );
    _run(command: command, label: 'negative (−20)');
  }

  /// Undo the most recent reversible mutation.
  ///
  /// The compensation is executed inside a real `Cell.txApply`
  /// transaction — the same atomic-commit mechanism the framework uses for
  /// multi-step Sagas — so the undo appears in the ledger as a staged
  /// command with its own receipt, alongside the original mutation.
  Future<void> _undoLast() async {
    final compensation = _lastCompensation;
    if (compensation == null) {
      return;
    }
    final undoCommand = (
      function: compensation.function,
      arguments: compensation.arguments,
      compensation: null,
    );
    final before = _counter.value;

    final tx = Cell.txApply();
    ApplyStaged? staged;
    await tx.execute(participants: [_counter], body: (scope) async {
      staged =
          await _counter.apply<Never>(undoCommand, tx: scope) as ApplyStaged;
    });

    setState(() {
      _display.update(_counter.value);
      _lastCompensation = null;
      final done = staged;
      if (done != null) {
        _devtoolsReceipts.add(done.receipt);
        _receipts.add(LedgerEntry(
          receipt: done.receipt,
          label: 'undo: subtract (−5)',
          before: before,
          after: _counter.value,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: _buildAppZone()),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 2, child: _buildLedgerZone()),
                ],
              ),
            ),
            _buildProveIt(),
          ],
        ),
      ),
    );
  }

  // Zone A — the app: current state and the three audited mutations.
  Widget _buildAppZone() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The app', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Every mutation below is a command that must pass the '
            'integrity gate — and every command is recorded.',
            style: theme.textTheme.bodyMedium,
          ),
          Expanded(
            child: Center(
              child: CellBuilder<int>(
                cell: _display.cell,
                builder: (_, v) => Text(
                  '${v ?? _counter.value}',
                  key: const Key('counter-value'),
                  style: theme.textTheme.displayLarge,
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                key: const Key('add-button'),
                onPressed: _addFive,
                child: const Text('Add +5'),
              ),
              OutlinedButton(
                key: const Key('invalid-button'),
                onPressed: _tryInvalid,
                child: const Text('Try invalid mutation'),
              ),
              OutlinedButton.icon(
                key: const Key('undo-button'),
                onPressed: _undoLast,
                icon: const Icon(Icons.undo),
                label: const Text('Undo last change'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'No `value = …` setter exists on this cell — `Cell.apply` is the '
            'only mutation path, which is exactly why the ledger never '
            'stays empty.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // Zone B — the ledger: one card per real ApplyReceipt.
  Widget _buildLedgerZone() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The ledger', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Live `ApplyLedger` receipts from the `cell` package — nothing '
            'here is mocked.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _receipts.isEmpty
                ? Center(
                    child: Text(
                      'No commands yet.\nPress “Add +5” to mint the first '
                      'receipt.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    itemCount: _receipts.length,
                    itemBuilder: (_, i) => _ReceiptCard(entry: _receipts[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // Zone C — the one-line proof.
  Widget _buildProveIt() {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.inverseSurface,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      child: Text(
        'This is the Cell difference: every state change is a record you '
        'can audit, a gate you can enforce, and a command you can undo.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onInverseSurface,
            ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.entry});

  final LedgerEntry entry;

  static const _accepted = Color(0xFF2E7D32);
  static const _rejected = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    final r = entry.receipt;
    final accent = entry.rejected ? _rejected : _accepted;
    final args = (r.arguments.positionalArguments ?? const [])
        .map((a) => '$a')
        .join(', ');
    final change = entry.rejected
        ? '${entry.before} — unchanged'
        : '${entry.before} → ${entry.after}';
    final time = r.timestamp.toLocal();
    final stamp = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: accent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'REQ: ${entry.label}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(
                  entry.rejected ? Icons.close : Icons.check,
                  size: 18,
                  color: accent,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('ID: ${r.id.split('-').first}…',
                style: Theme.of(context).textTheme.bodySmall),
            Text('Time: $stamp',
                style: Theme.of(context).textTheme.bodySmall),
            Text('Vetted: ${r.vetted ? '✓' : '✗'}',
                style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 12),
            Text('$change  (args: $args)',
                style: Theme.of(context).textTheme.bodyMedium),
            if (entry.compensation != null)
              Text(
                'compensation: ${(entry.compensation!.arguments.positionalArguments ?? const []).map((a) => '$a').join(', ')}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            if (entry.rejected)
              Text(
                'Rejected by the integrity gate: negative mutations are not '
                'allowed.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _rejected),
              ),
          ],
        ),
      ),
    );
  }
}
