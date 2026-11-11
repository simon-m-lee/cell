// Compares the three public write paths on ValueCell:
// value setter vs StateHandle.update vs vetted Cell.apply.
//
// Run: dart run benchmark/micro/value_emit.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

/// Control: bare field write on a plain Dart class.
class PlainFieldWrite extends BenchmarkBase {
  PlainFieldWrite() : super('[control] plain field write');

  final cell = _PlainBox(0);

  @override
  void run() {
    for (var i = 0; i < 100000; i++) {
      cell.value = i;
    }
  }
}

class ValueSetter extends BenchmarkBase {
  ValueSetter() : super('ValueCell.value =');

  final cell = Cell.state<int>(initial: 0).cell;

  @override
  void run() {
    for (var i = 0; i < 100000; i++) {
      cell.value = i;
    }
  }
}

class StateUpdate extends BenchmarkBase {
  StateUpdate() : super('StateHandle.update');

  final handle = Cell.state<int>(initial: 0);

  @override
  void run() {
    for (var i = 0; i < 100000; i++) {
      handle.update(i);
    }
  }
}

class ApplyCommand extends AsyncBenchmarkBase {
  ApplyCommand() : super('Cell.apply (vetted)');

  final cell = Cell.state<int>(initial: 0).cell;

  @override
  Future<void> run() async {
    for (var i = 0; i < 10000; i++) {
      await cell.apply<int>(
        (
          function: (ValueCell<int> c) {
            c.value = i;
            return i;
          },
          arguments: (positionalArguments: [cell], namedArguments: null),
          compensation: null,
        ),
      );
    }
  }
}

class _PlainBox {
  _PlainBox(this.value);

  int value;
}

Future<void> main() async {
  PlainFieldWrite().report();
  ValueSetter().report();
  StateUpdate().report();
  await ApplyCommand().report();
}
