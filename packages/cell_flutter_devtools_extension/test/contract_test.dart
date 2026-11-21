// Wire-contract test: the provider's serializer output must parse through
// the extension UI's model — both packages pinned to the same contract.
library;

import 'package:cell/cell.dart';
import 'package:cell_flutter_devtools/cell_flutter_devtools.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cell_flutter_devtools_extension/src/ledger_model.dart';

/// A cell with instance-method command tear-offs, like a real app.
class ContractCell extends CellBase {
  ContractCell() {
    add = _add;
  }

  late final void Function(int delta) add;

  void _add(int delta) {}

  @override
  Iterable<Function> get modifiable => {add, apply};
}

ApplyCommand _command(Function function, List<Object?> args) => (
      function: function,
      arguments: (positionalArguments: args, namedArguments: null),
      compensation: null,
    );

void main() {
  test('the provider wire contract parses in the extension UI', () {
    final cell = ContractCell();
    final receipt = ApplyLedger.receipt(
      cell: cell,
      command: _command(cell.add, [5]),
      txSequence: 3,
    );
    final payload = buildCellLedgerResponse(
      receipts: () => [receipt],
      rejections: () => [
        CellDevtoolsRejection(receipt: receipt, reason: 'governed'),
      ],
    );

    expect(payload.containsKey('error'), isFalse);
    final entry = DevtoolsLedgerEntry.fromJson(
      (payload['receipts']! as List).single as Map<String, dynamic>,
    );
    expect(entry.id, receipt.id);
    expect(entry.functionName, 'add'); // underscore + @hash stripped
    expect(entry.vetted, isTrue);
    expect(entry.txSequence, 3);
    expect(entry.arguments?['positional'], [5]);

    final rejection = DevtoolsRejectionEntry.fromJson(
      (payload['rejections']! as List).single as Map<String, dynamic>,
    );
    expect(rejection.functionName, 'add');
    expect(rejection.reason, 'governed');
  });
}
