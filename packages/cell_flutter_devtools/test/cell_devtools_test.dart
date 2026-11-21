// Provider-package tests: serialization contract, error handling, and
// registration smoke.
library;

import 'package:cell/cell.dart';
import 'package:cell_flutter_devtools/cell_flutter_devtools.dart';
import 'package:test/test.dart';

final ValueCell<int> _host = Cell.state<int>(initial: 0).cell;

void addCounter(int delta) {}

void toggleTodo() {}

ApplyCommand _command(Function function, List<Object?>? positional) => (
      function: function,
      arguments: (positionalArguments: positional, namedArguments: null),
      compensation: null,
    );

ApplyReceipt _receipt(
  Function function,
  List<Object?>? positional, {
  int? txSequence,
}) =>
    ApplyLedger.receipt(
      cell: _host,
      command: _command(function, positional),
      txSequence: txSequence,
    );

void main() {
  group('serializeReceipt', () {
    test('produces the wire-contract shape', () {
      final json = serializeReceipt(_receipt(addCounter, [5], txSequence: 2));
      expect(json.keys.toSet(), {
        'id',
        'function',
        'arguments',
        'timestamp',
        'vetted',
        'txSequence',
      });
      expect(json['function'], 'addCounter');
      expect(
        (json['arguments'] as Map)['positional'],
        [5],
      );
      expect(json['vetted'], isTrue);
      expect(json['txSequence'], 2);
    });

    test('serializes named arguments with symbol keys as strings', () {
      final command = (
        function: toggleTodo,
        arguments: (
          positionalArguments: null,
          namedArguments: {#delta: 7},
        ),
        compensation: null,
      );
      final receipt = ApplyLedger.receipt(cell: _host, command: command);
      final json = serializeReceipt(receipt);
      expect((json['arguments'] as Map)['named'], {'delta': 7});
    });
  });

  group('buildCellLedgerResponse', () {
    test('returns receipts and an empty rejection list', () {
      final payload = buildCellLedgerResponse(
        receipts: () => [_receipt(addCounter, [5])],
      );
      expect(payload.containsKey('error'), isFalse);
      expect((payload['receipts'] as List), hasLength(1));
      expect(payload['rejections'], isEmpty);
    });

    test('returns an empty ledger as an empty list', () {
      final payload = buildCellLedgerResponse(receipts: () => []);
      expect(payload['receipts'], isEmpty);
    });

    test('includes rejections reported by the app', () {
      final payload = buildCellLedgerResponse(
        receipts: () => [_receipt(addCounter, [5])],
        rejections: () => [
          CellDevtoolsRejection(
            receipt: _receipt(addCounter, [-20]),
            reason: 'negative mutations are not allowed',
          ),
        ],
      );
      final rejections = payload['rejections'] as List;
      expect(rejections, hasLength(1));
      expect(
        (rejections.single as Map)['reason'],
        'negative mutations are not allowed',
      );
    });

    test('converts a throwing provider into an error payload', () {
      final payload = buildCellLedgerResponse(
        receipts: () => throw StateError('boom'),
      );
      expect(payload.containsKey('error'), isTrue);
      expect('${payload['error']}', contains('boom'));
    });
  });

  group('registerCellDevTools', () {
    test('registers without throwing (assert-guarded, no-op without a '
        'VM service)', () {
      registerCellDevTools(receipts: () => []);
    });
  });
}
