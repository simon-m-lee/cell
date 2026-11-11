// GENERATED FILE — do not edit by hand.
// Regenerate with: dart run tool/generate_ai_examples.dart
//
// Compiles and executes every `Minimal compilable example` from the
// `### AI Agent Guide` doc blocks in lib/. Verified by
// test/ai_guide_examples_test.dart.
// ignore_for_file: non_constant_identifier_names, avoid_print

import 'package:cell/cell.dart';
import 'dart:io' as io;

// <lib/src/cell.dart:89>
Future<void> aiExampleCell() async {
  final inGate = Cell.ingress<int>();
  final seen = <int>[];
  final o = Cell.observe(source: inGate.cell, effect: (Pulse p) => seen.add(p.payload as int));
  inGate.emit(1);
  o.stop();
  print(seen); // [1]
}

// <lib/src/cell.dart:1858>
Future<void> aiExampleCell_asyncMap() async {
  final src = Cell.ingress<int>();
  final am = Cell.asyncMap<int, String>(src.cell, (v) async => 'v=$v');
  final o = Cell.observe(source: am, effect: (Pulse p) => print(p.payload));
  src.emit(3);
  await Future<void>.delayed(const Duration(milliseconds: 30));
  o.stop();
}

// <lib/src/cell.dart:1562>
Future<void> aiExampleCell_debounce() async {
  final src = Cell.ingress<String>();
  final db = Cell.debounce(src.cell, const Duration(milliseconds: 50));
  final o = Cell.observe(source: db, effect: (Pulse p) => print(p.payload));
  src.emit('a');
  src.emit('b');
  await Future<void>.delayed(const Duration(milliseconds: 80));
  o.stop();
}

// <lib/src/cell.dart:2240>
Future<void> aiExampleCell_deputy() async {
  final c = Cell.state<int>(initial: 1);
  final d = await c.cell.deputy(testRule: TestCell.readOnly);
  print(d);
}

// <lib/src/cell.dart:748>
Future<void> aiExampleCell_derive() async {
  final src = Cell.ingress<int>();
  final dbl = Cell.derive<Pulse<int>, Pulse<int>>(
    source: src.cell,
    project: (p) => Pulse<int>((p.payload ?? 0) * 2),
  );
  final o = Cell.observe(source: dbl, effect: (Pulse p) => print(p.payload));
  src.emit(21);
  o.stop();
}

// <lib/src/cell.dart:1728>
Future<void> aiExampleCell_distinct() async {
  final src = Cell.ingress<int>();
  final d = Cell.distinct(src.cell);
  final seen = <int>[];
  final o = Cell.observe(source: d, effect: (Pulse p) => seen.add(p.payload as int));
  src.emit(1);
  src.emit(1); // suppressed
  src.emit(2);
  o.stop();
  print(seen); // [1, 2]
}

// <lib/src/cell.dart:2035>
Future<void> aiExampleCell_fromFuture() async {
  final f = Cell.fromFuture<int>(Future.value(7));
  final o = Cell.observe(source: f, effect: (Pulse p) => print(p.payload));
  await Future<void>.delayed(const Duration(milliseconds: 10));
  o.stop();
}

// <lib/src/cell.dart:348>
Future<void> aiExampleCell_fromNucleus() async {
  final blueprint = Nucleus(
    receptor: Receptor((cell, pulse, {user}) {
      final token = pulse.payload as String;
      return Pulse(token.isNotEmpty ? 'Valid' : 'Invalid');
    }),
    testRule: TestCell((value, {host, arguments, user}) => value is String),
  );
  final authCell = Cell.fromNucleus(blueprint);
  print(authCell);
}

// <lib/src/cell.dart:1955>
Future<void> aiExampleCell_fromStream() async {
  final s = Cell.fromStream<int>(Stream.fromIterable([1, 2, 3]));
  final o = Cell.observe(source: s, effect: (Pulse p) => print(p.payload));
  await Future<void>.delayed(const Duration(milliseconds: 30));
  o.stop();
}

// <lib/src/cell.dart:246>
Future<void> aiExampleCell_governed() async {
  final g = Cell.governed(context: Context.system);
  print(g.isGoverned); // true
}

// <lib/src/cell.dart:881>
Future<void> aiExampleCell_hub() async {
  final hub = Cell.hub(spokes: {
    'echo': (cell, pulse, {user}) => Pulse('echo:${pulse.payload}'),
  });
  print(hub.root);
}

// <lib/src/cell.dart:470>
Future<void> aiExampleCell_ingress() async {
  final gate = Cell.ingress<int>(
    testRule: TestCell((v, {arguments, host, user}) => v is int && v >= 0),
  );
  gate.emit(1);
  gate.emit(-1); // rejected by the TestCell gate
  print('ok');
}

// <lib/src/cell.dart:662>
Future<void> aiExampleCell_observe() async {
  final events = Cell.ingress<String>();
  final o = Cell.observe(
    source: events.cell,
    effect: (Pulse p) => print('got ${p.payload}'),
  );
  events.emit('x');
  o.stop();
}

// <lib/src/cell.dart:1294>
Future<void> aiExampleCell_open() async {
  final o = Cell.open();
  o.emit(Pulse('hello'));
}

// <lib/src/cell.dart:983>
Future<void> aiExampleCell_sanitized() async {
  final src = Cell.ingress<int>();
  final clean = Cell.sanitized<Pulse<int>>(
    src.cell,
    redact: (p) => Pulse(p.payload, type: 'redacted'),
  );
  final o = Cell.observe(source: clean, effect: (Pulse p) => print(p.type));
  src.emit(42);
  o.stop();
}

// <lib/src/cell.dart:574>
Future<void> aiExampleCell_state() async {
  final counter = Cell.state<int>(initial: 0);
  counter.update(5);
  print(counter.cell.value); // 5
}

// <lib/src/cell.dart:2129>
Future<void> aiExampleCell_switchMap() async {
  final src = Cell.ingress<String>();
  final sm = Cell.switchMap<String, int>(
    src.cell,
    (v) => Cell.state<int>(initial: v.length).cell,
  );
  final o = Cell.observe(source: sm, effect: (Pulse p) => print(p.payload));
  src.emit('abc');
  await Future<void>.delayed(const Duration(milliseconds: 20));
  o.stop();
}

// <lib/src/cell.dart:1397>
Future<void> aiExampleCell_synthesis() async {
  final a = Cell.state<int>(initial: 2);
  final b = Cell.state<int>(initial: 3);
  final sum = Cell.synthesis<Pulse<int>>([a.cell, b.cell], aggregator: (cells, emit) {
    final total = cells.fold<int>(0, (acc, c) => acc + (((c as ValueCell).value as int?) ?? 0));
    return Pulse<int>(total);
  });
  final o = Cell.observe(source: sum, effect: (Pulse p) => print(p.payload));
  a.update(4);
  b.update(5);
  o.stop();
}

// <lib/src/cell.dart:1643>
Future<void> aiExampleCell_throttle() async {
  final src = Cell.ingress<int>();
  final th = Cell.throttle(src.cell, const Duration(milliseconds: 50));
  final o = Cell.observe(source: th, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  src.emit(2); // throttled
  await Future<void>.delayed(const Duration(milliseconds: 80));
  o.stop();
}

// <lib/src/cell.dart:1141>
Future<void> aiExampleCell_transaction() async {
  final a = Cell.state<int>(initial: 1);
  final b = Cell.state<int>(initial: 10);
  final tx = Cell.transaction();
  await tx.begin([a.cell, b.cell]);
  tx.update(a.cell, 2);
  tx.update(b.cell, 20);
  await tx.commit();
  print('${a.cell.value},${b.cell.value}'); // 2,20
}

// <lib/src/cell.dart:1200>
Future<void> aiExampleCell_txApply() async {
  final counter = Cell.state<int>(initial: 0);
  final tx = Cell.txApply();
  await tx.execute(participants: [counter.cell], body: (scope) {
    counter.update(5); // staged — committed when execute completes
  });
  print(counter.cell.value);
}

// <lib/src/cell.dart:2664>
Future<void> aiExampleCell_unmodifiable() async {
  final c = Cell.state<int>(initial: 1);
  final ro = c.cell.unmodifiable;
  print(ro);
}

// <lib/src/cell.dart:1486>
Future<void> aiExampleCell_valve() async {
  final src = Cell.ingress<int>();
  final gated = Cell.valve<Pulse<int>>(src.cell, (p) => (p.payload ?? 0) > 0);
  final o = Cell.observe(source: gated, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  src.emit(-1); // blocked by the gate
  o.stop();
}

// <lib/src/pulse.dart:277>
Future<void> aiExamplePulse() async {
  final p = Pulse<int>(42, type: 'counter', step: 'init');
  print('${p.payload},${p.type}'); // 42,counter
}

// <lib/src/test_cell.dart:70>
Future<void> aiExampleTestCell() async {
  final gate = TestCell((v, {arguments, host, user}) => v is int && v >= 0);
  final c = Cell.ingress<int>(testRule: gate);
  c.emit(1);
  c.emit(-1); // rejected by the gate
  print('ok');
}

Future<void> main() async {
  var failures = 0;
  try { await aiExampleCell(); print('ai-example: Cell ok'); }
  catch (e, st) { failures++; print('ai-example: Cell FAILED: $e'); print(st); }
  try { await aiExampleCell_asyncMap(); print('ai-example: Cell.asyncMap ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.asyncMap FAILED: $e'); print(st); }
  try { await aiExampleCell_debounce(); print('ai-example: Cell.debounce ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.debounce FAILED: $e'); print(st); }
  try { await aiExampleCell_deputy(); print('ai-example: Cell.deputy ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.deputy FAILED: $e'); print(st); }
  try { await aiExampleCell_derive(); print('ai-example: Cell.derive ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.derive FAILED: $e'); print(st); }
  try { await aiExampleCell_distinct(); print('ai-example: Cell.distinct ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.distinct FAILED: $e'); print(st); }
  try { await aiExampleCell_fromFuture(); print('ai-example: Cell.fromFuture ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.fromFuture FAILED: $e'); print(st); }
  try { await aiExampleCell_fromNucleus(); print('ai-example: Cell.fromNucleus ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.fromNucleus FAILED: $e'); print(st); }
  try { await aiExampleCell_fromStream(); print('ai-example: Cell.fromStream ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.fromStream FAILED: $e'); print(st); }
  try { await aiExampleCell_governed(); print('ai-example: Cell.governed ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.governed FAILED: $e'); print(st); }
  try { await aiExampleCell_hub(); print('ai-example: Cell.hub ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.hub FAILED: $e'); print(st); }
  try { await aiExampleCell_ingress(); print('ai-example: Cell.ingress ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.ingress FAILED: $e'); print(st); }
  try { await aiExampleCell_observe(); print('ai-example: Cell.observe ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.observe FAILED: $e'); print(st); }
  try { await aiExampleCell_open(); print('ai-example: Cell.open ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.open FAILED: $e'); print(st); }
  try { await aiExampleCell_sanitized(); print('ai-example: Cell.sanitized ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.sanitized FAILED: $e'); print(st); }
  try { await aiExampleCell_state(); print('ai-example: Cell.state ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.state FAILED: $e'); print(st); }
  try { await aiExampleCell_switchMap(); print('ai-example: Cell.switchMap ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.switchMap FAILED: $e'); print(st); }
  try { await aiExampleCell_synthesis(); print('ai-example: Cell.synthesis ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.synthesis FAILED: $e'); print(st); }
  try { await aiExampleCell_throttle(); print('ai-example: Cell.throttle ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.throttle FAILED: $e'); print(st); }
  try { await aiExampleCell_transaction(); print('ai-example: Cell.transaction ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.transaction FAILED: $e'); print(st); }
  try { await aiExampleCell_txApply(); print('ai-example: Cell.txApply ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.txApply FAILED: $e'); print(st); }
  try { await aiExampleCell_unmodifiable(); print('ai-example: Cell.unmodifiable ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.unmodifiable FAILED: $e'); print(st); }
  try { await aiExampleCell_valve(); print('ai-example: Cell.valve ok'); }
  catch (e, st) { failures++; print('ai-example: Cell.valve FAILED: $e'); print(st); }
  try { await aiExamplePulse(); print('ai-example: Pulse ok'); }
  catch (e, st) { failures++; print('ai-example: Pulse FAILED: $e'); print(st); }
  try { await aiExampleTestCell(); print('ai-example: TestCell ok'); }
  catch (e, st) { failures++; print('ai-example: TestCell FAILED: $e'); print(st); }
  if (failures > 0) {
    print('ai-examples: $failures of 25 failed');
    io.exitCode = 1;
  } else {
    print('ai-examples: all 25 passed');
  }
}
