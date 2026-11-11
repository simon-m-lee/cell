// Compares the three public write paths on ValueCell:
// value setter vs StateHandle.update vs vetted Cell.apply.
//
// Each `run()` performs exactly one operation and lets benchmark_harness
// scale the iteration count, so the reported score is microseconds per
// single write/update/apply. (A fixed 100k-operation loop per run forced
// the harness to run multi-minute phases because it always executes a
// minimum of two iterations per phase.)
//
// Run: dart run benchmark/micro/value_emit.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

/// Control: bare field write on a plain Dart class.
class PlainFieldWrite extends BenchmarkBase {
  PlainFieldWrite() : super('[control] plain field write');

  final box = _PlainBox(0);
  var i = 0;

  @override
  void run() {
    box.value = i++;
  }
}

class ValueSetter extends BenchmarkBase {
  ValueSetter() : super('ValueCell.value =');

  final cell = Cell.state<int>(initial: 0).cell;
  var i = 0;

  @override
  void run() {
    cell.value = i++;
  }
}

class StateUpdate extends BenchmarkBase {
  StateUpdate() : super('StateHandle.update');

  final handle = Cell.state<int>(initial: 0);
  var i = 0;

  @override
  void run() {
    handle.update(i++);
  }
}

class ApplyCommand extends AsyncBenchmarkBase {
  ApplyCommand() : super('Cell.apply (vetted)');

  final cell = Cell.state<int>(initial: 0).cell;
  var i = 0;

  @override
  Future<void> run() async {
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
    i++;
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
