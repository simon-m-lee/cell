// Initialises the Flutter binding for the whole package test run.
//
// Several unit tests (CellNotifier, CellScope, pumpWithCells, ...) run as
// plain `test()` bodies but reach code that reads
// `SchedulerBinding.instance.schedulerPhase` (pulse_delivery.dart). Without
// this file those reads throw inside the cell observer effect — where the
// framework's error contract swallows them — and every update silently
// disappears instead of failing the test.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await testMain();
}
