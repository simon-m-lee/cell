// The canonical named example program for cell_flutter_devtools.
//
// A minimal audited counter that registers the DevTools service
// extension: run it with `flutter run`, open Flutter DevTools, enable
// the cell_flutter_devtools extension, and the receipts from every
// button press appear in the ledger timeline. `example/lib/main.dart`
// is the thin pub.dev entry point that delegates here.
library;

import 'package:cell/cell.dart';
import 'package:cell_flutter_devtools/cell_flutter_devtools.dart';
import 'package:flutter/material.dart';

/// The audited counter — mutations only through `Cell.apply`.
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

/// Receipts collected for the DevTools extension.
final List<ApplyReceipt> devtoolsReceipts = [];

/// Runs the example app (delegated to from `example/lib/main.dart`).
void runCellFlutterDevtoolsExample() {
  // Debug/profile only: the registration is assert-guarded and
  // tree-shaken out of release builds.
  registerCellDevTools(receipts: () => List.of(devtoolsReceipts));
  runApp(const DevtoolsExampleApp());
}

class DevtoolsExampleApp extends StatefulWidget {
  const DevtoolsExampleApp({super.key});

  @override
  State<DevtoolsExampleApp> createState() => _DevtoolsExampleAppState();
}

class _DevtoolsExampleAppState extends State<DevtoolsExampleApp> {
  final CounterCell counter = CounterCell();

  Future<void> _run(Function command, List<Object?> args) async {
    final outcome = await counter.apply<void>(_command(command, args));
    if (outcome is ApplyAccepted<void>) {
      devtoolsReceipts.add(outcome.receipt);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('cell_flutter_devtools example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${counter.value}', style: const TextStyle(fontSize: 48)),
              Text('${devtoolsReceipts.length} receipts',
                  key: const Key('receipt-count')),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Open Flutter DevTools and enable the cell_flutter_devtools '
                  'extension to inspect the ledger live.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              key: const Key('subtract-button'),
              heroTag: 'subtract',
              onPressed: () => _run(counter.subtract, [1]),
              child: const Icon(Icons.remove),
            ),
            const SizedBox(width: 12),
            FloatingActionButton(
              key: const Key('add-button'),
              heroTag: 'add',
              onPressed: () => _run(counter.add, [1]),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
