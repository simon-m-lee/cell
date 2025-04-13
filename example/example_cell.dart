// It is an A.I. generated document. The content is based on the code provided
// and may not accurately reflect the intended functionality or usage of the
// package. Please review and modify as necessary to ensure accuracy and clarity.

import 'package:cell/cell.dart';

Future<void> main() async {

  var result;

  // Create a basic cell
  final baseCell = Cell();
  final boundCell = Cell(bind: baseCell);
  
  // Create a listening cell
  final listener = Cell.listen<Signal<String>>(
    bind: baseCell,
    listen: (signal, _) => print('Received: ${signal.body}'),
  );
  
  // Create a transforming cell
  final transformer = Cell.signaling<Signal<String>, Signal<int>>(
    bind: baseCell,
    transform: (signal, _) => Signal<int>(signal.body!.length),
  );

  // Create an open cell that provides open receptor
  final open = Cell.open<Cell, Cell, Signal<int>, Signal<String>>(
    receptor: Receptor<Cell, Signal<int>, Signal<String>>(
      transform: ({required cell, required signal, dynamic user}) {
        return Signal<String>('Transformed: ${signal.body}');
      },
    ),
  );

  result = open.receptor(Signal<int>(10));
  print(result); // Output: Signal<String>('Transformed: 10')

  // Accesses the asynchronous version of a cell using `cell.async`
  final asyncCell = open.async;
  result = asyncCell.async.receptor(Signal<int>(10));
  
}
