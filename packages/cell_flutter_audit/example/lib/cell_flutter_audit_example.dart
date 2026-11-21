// The canonical named example program for cell_flutter_audit.
//
// A tiny audited counter: every mutation goes through `Cell.apply`, the
// outcome is fed to an AuditTrailController, and AuditTrailView renders
// the receipts. `example/lib/main.dart` is the thin pub.dev entry point
// that delegates here.

// Example application for cell_flutter_audit.
//
// A tiny audited counter: every mutation goes through `Cell.apply`, the
// outcome is fed to an AuditTrailController, and AuditTrailView renders
// the receipts. This is the README quick-start, runnable.
library;

import 'package:cell_flutter/cell_flutter.dart';
import 'package:cell_flutter_audit/cell_flutter_audit.dart';
import 'package:flutter/material.dart';

/// The audited counter — commands only, no `value =` setter.
class CounterCell extends CellBase {
  CounterCell() {
    add = _add;
    subtract = _subtract;
  }

  int value = 0;

  late final void Function(int delta) add;
  late final void Function(int delta) subtract;

  void _add(int delta) => value += delta;

  void _subtract(int delta) => value -= delta;

  @override
  Iterable<Function> get modifiable => {add, subtract, apply};
}

ApplyCommand _command(Function function, List<Object?> args) => (
      function: function,
      arguments: (positionalArguments: args, namedArguments: null),
      compensation: null,
    );



/// Runs the example app (delegated to from `example/lib/main.dart`).
void runCellFlutterAuditExample() => runApp(const AuditApp());

class AuditApp extends StatefulWidget {
  const AuditApp({super.key});

  @override
  State<AuditApp> createState() => _AuditAppState();
}

class _AuditAppState extends State<AuditApp> {
  final CounterCell counter = CounterCell();
  final AuditTrailController controller = AuditTrailController();
  final StateHandle<int> display = Cell.state<int>(initial: 0);

  Future<void> _run(Function command, List<Object?> args) async {
    final outcome = await counter.apply<void>(_command(command, args));
    controller.addOutcome(outcome);
    if (outcome is ApplyAccepted) {
      display.update(counter.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('cell_flutter_audit example'),
          actions: [
            CellBuilder<int>(
              cell: display.cell,
              builder: (context, value) =>
                  Center(child: Text('${value ?? 0}')),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: AuditTrailView(controller: controller),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton(
                key: const Key('add-button'),
                onPressed: () => _run(counter.add, [1]),
                child: const Text('Add +1'),
              ),
              FilledButton(
                key: const Key('subtract-button'),
                onPressed: () => _run(counter.subtract, [1]),
                child: const Text('Subtract −1'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
