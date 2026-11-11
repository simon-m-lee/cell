import 'dart:async';

import 'package:cell/cell.dart';
import 'package:test/test.dart';

Future<void> _pump() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('Receptor.pipeline with Instruction.future + postProcess', () {
    test('postProcess commits ValueCell state on the async path', () async {
      final source = Cell.ingress<int>();

      final receptor = Receptor.pipeline(
        instruction: Instruction<ValueCell<int>, Pulse, Pulse>.future(
          (pulse, {cell, user, future, token}) {
            // Suspend synchronously, resume on the next microtask.
            Future<void>.microtask(() {
              future?.call(result: pulse, token: token);
            });
            return null;
          },
        ),
        postProcess: ValueCell.postProcessRule,
      );

      final valueCell = ValueCell<int>(
        initial: 0,
        receptor: receptor,
        bind: source.cell,
      );

      source.emit(42);
      await _pump();

      expect(valueCell.value, 42,
          reason: 'postProcess must be given the host cell so it can commit to '
              'the shared Box; without it, `cell!` NPEs and the state is '
              'never written');
    });

    test('postProcess output is propagated to downstream observers', () async {
      final source = Cell.ingress<int>();

      // postProcess that returns a distinct derived pulse. The host is a
      // plain Cell (no library-private access needed in tests); the async
      // continuation must propagate whatever the postProcess returns.
      final receptor = Receptor.pipeline(
        instruction: Instruction<Cell, Pulse, Pulse>.future(
          (pulse, {cell, user, future, token}) {
            Future<void>.microtask(() {
              future?.call(result: pulse, token: token);
            });
            return null;
          },
        ),
        postProcess: Instruction<Cell, Pulse, Pulse>(
          (pulse, {cell, user}) =>
              Pulse<int>((pulse.payload as int) * 10, type: 'derived'),
        ),
      );

      final host = Cell(
        bind: source.cell,
        receptor: receptor,
      );

      final received = <int>[];
      Cell.observe<Pulse<int>>(
        source: host,
        effect: (p) => received.add(p.payload as int),
      );

      source.emit(7);
      await _pump();

      expect(received, [70],
          reason: 'the postProcess return value must reach synapses');
    });
  });
}
