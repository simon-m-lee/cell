// GENERATED FILE — do not edit by hand.
// Regenerate with: dart run tool/generate_ai_examples.dart
//
// Compiles and executes every `Minimal compilable example` from the
// `### AI Agent Guide` doc blocks in lib/. Verified by
// test/ai_guide_examples_test.dart.
// ignore_for_file: non_constant_identifier_names, avoid_print, unused_local_variable

import 'package:cell_flow/cell_flow.dart';
import 'dart:io' as io;
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/distinct.dart';
import 'package:cell_flow/src/instruction/tap.dart';

// <lib/src/instruction/distinct.dart:454>
Future<void> aiExampleDistinct() async {
  final src = Cell.ingress<int>();
  final h = Distinct<int>().toHandle(source: src.cell);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  src.emit(1); // suppressed
  o.stop();
}

// <lib/src/instruction/distinct.dart:188>
Future<void> aiExampleDistinctUntilChanged() async {
  final src = Cell.ingress<int>();
  final h = DistinctUntilChanged<int>().toHandle(source: src.cell);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  src.emit(1); // suppressed
  o.stop();
}

// <lib/src/instruction/filter.dart:161>
Future<void> aiExampleFilter() async {
  final src = Cell.ingress<int>();
  final h = Filter<int>((v) => v > 0).toHandle(source: src.cell);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  src.emit(-1); // dropped
  o.stop();
}

// <lib/src/flow.dart:54>
Future<void> aiExampleFlow() async {
  final src = Cell.ingress<int>();
  final h = Flow.filter<int>(src.cell, test: (v) => v > 0);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:1895>
Future<void> aiExampleFlow_asyncMapLatest() async {
  final src = Cell.ingress<String>();
  final h = Flow.asyncMapLatest<String, int>(src.cell, mapper: (v) async => v.length);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit('abc');
  await Future<void>.delayed(const Duration(milliseconds: 20));
  o.stop();
}

// <lib/src/flow.dart:4225>
Future<void> aiExampleFlow_combineLatestWith() async {
  final src = Cell.ingress<int>();
  final h = Flow.combineLatestWith<int, String>(
    src.cell,
    others: [Cell.ingress<String>().cell],
    combine: (a, latest) => '$a:${latest.single}',
  );
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:3346>
Future<void> aiExampleFlow_concatMap() async {
  final src = Cell.ingress<int>();
  final h = Flow.concatMap<int, int>(src.cell, project: (v) async => v * 2);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:4705>
Future<void> aiExampleFlow_debounce() async {
  final src = Cell.ingress<String>();
  final h = Flow.debounce<String>(src.cell, duration: const Duration(milliseconds: 50));
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit('a');
  src.emit('b');
  await Future<void>.delayed(const Duration(milliseconds: 80));
  o.stop();
}

// <lib/src/flow.dart:3249>
Future<void> aiExampleFlow_distinct() async {
  final src = Cell.ingress<int>();
  final h = Flow.distinct<int>(src.cell);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:3752>
Future<void> aiExampleFlow_exhaustMap() async {
  final src = Cell.ingress<int>();
  final h = Flow.exhaustMap<int, int>(src.cell, project: (v) async => v * 2);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:2673>
Future<void> aiExampleFlow_filter() async {
  final src = Cell.ingress<int>();
  final h = Flow.filter<int>(src.cell, test: (v) => v.isEven);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:407>
Future<void> aiExampleFlow_fromFuture() async {
  final src = Cell.ingress<int>();
  final h = Flow.fromFuture<int>(src.cell, future: Future.value(5));
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(0);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  o.stop();
}

// <lib/src/flow.dart:568>
Future<void> aiExampleFlow_fromStream() async {
  final src = Cell.ingress<int>();
  final h = Flow.fromStream<int>(src.cell, stream: Stream.fromIterable([1, 2]));
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(0);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  o.stop();
}

// <lib/src/flow.dart:5791>
Future<void> aiExampleFlow_groupBy() async {
  final src = Cell.ingress<int>();
  final h = Flow.groupBy<int, int>(src.cell, keyOf: (v) => v % 2);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:736>
Future<void> aiExampleFlow_map() async {
  final src = Cell.ingress<int>();
  final h = Flow.map<int, int>(src.cell, project: (v) => v * 2);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:3580>
Future<void> aiExampleFlow_mergeMap() async {
  final src = Cell.ingress<int>();
  final h = Flow.mergeMap<int, int>(src.cell, project: (v) async => v * 2);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:3832>
Future<void> aiExampleFlow_mergeWith() async {
  final src = Cell.ingress<int>();
  final h = Flow.mergeWith<int>(src.cell, others: [Cell.ingress<int>().cell]);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:128>
Future<void> aiExampleFlow_of() async {
  final src = Cell.ingress<int>();
  final h = Flow.of<int>(src.cell, values: [1, 2, 3]);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:1273>
Future<void> aiExampleFlow_pluck() async {
  final src = Cell.ingress<Map<String, Object>>();
  final h = Flow.pluck<int>(src.cell, key: 'a');
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit({'a': 1});
  o.stop();
}

// <lib/src/flow.dart:4382>
Future<void> aiExampleFlow_race() async {
  final src = Cell.ingress<int>();
  final h = Flow.race<int>(src.cell, competitors: [1, 2]);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:6453>
Future<void> aiExampleFlow_retry() async {
  final src = Cell.ingress<int>();
  final h = Flow.retry<int, int>(src.cell, task: (v) async => v, count: 2);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  o.stop();
}

// <lib/src/flow.dart:1565>
Future<void> aiExampleFlow_scan() async {
  final src = Cell.ingress<int>();
  final h = Flow.scan<int, int>(src.cell, accumulate: (acc, v) => acc + v);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:2940>
Future<void> aiExampleFlow_skip() async {
  final src = Cell.ingress<int>();
  final h = Flow.skip<int>(src.cell, count: 1);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:3670>
Future<void> aiExampleFlow_switchMap() async {
  final src = Cell.ingress<int>();
  final h = Flow.switchMap<int, int>(src.cell, project: (v) async => v * 2);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:2748>
Future<void> aiExampleFlow_take() async {
  final src = Cell.ingress<int>();
  final h = Flow.take<int>(src.cell, count: 2);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:6538>
Future<void> aiExampleFlow_tap() async {
  final src = Cell.ingress<int>();
  final h = Flow.tap<int>(src.cell, onValue: (v) => print(v));
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  o.stop();
}

// <lib/src/flow.dart:4790>
Future<void> aiExampleFlow_throttle() async {
  final src = Cell.ingress<int>();
  final h = Flow.throttle<int>(src.cell, duration: const Duration(milliseconds: 50));
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  src.emit(2);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  o.stop();
}

// <lib/src/flow.dart:5123>
Future<void> aiExampleFlow_timeout() async {
  final src = Cell.ingress<int>();
  final h = Flow.timeout<int>(src.cell, duration: const Duration(milliseconds: 50));
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(1);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  o.stop();
}

// <lib/src/flow_core.dart:549>
Future<void> aiExampleFlowHandle() async {
  final src = Cell.ingress<int>();
  final h = Flow.filter<int>(src.cell, test: (v) => true);
  h.emit(1);
  print(h.cell);
}

// <lib/src/flow_core.dart:71>
Future<void> aiExampleFlowInstruction() async {
  final gate = FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) => p);
  final h = gate.toHandle(source: Cell.ingress<String>().cell);
  h.emit('x');
}

// <lib/src/flow_core.dart:247> (top-level declarations)
enum Risk { go, hold }
class RiskGate extends FlowInstructionBase<Cell, Pulse, Pulse> {
  RiskGate() : super.future((p, {cell, user, future, token}) => p);
  static Risk riskOf(String word) => word == 'x' ? Risk.hold : Risk.go;
  Risk? lastDecision;
}
Future<void> aiExampleFlowInstructionBase() async {
  final gate = RiskGate();
  print(gate.lastDecision);
}

// <lib/src/instruction/map.dart:231>
Future<void> aiExampleMapValue() async {
  final src = Cell.ingress<int>();
  final h = MapValue<int, String>((v) => 'v=$v').toHandle(source: src.cell);
  final o = Cell.observe(source: h.cell, effect: (Pulse p) => print(p.payload));
  src.emit(7);
  o.stop();
}

// <lib/src/instruction/tap.dart:205>
Future<void> aiExampleTap() async {
  final src = Cell.ingress<int>();
  final h = Tap<int>((v) => print('tapped $v')).toHandle(source: src.cell);
  src.emit(1);
  print(h.cell);
}

Future<void> main() async {
  var failures = 0;
  try { await aiExampleDistinct(); print('ai-example: Distinct ok'); }
  catch (e, st) { failures++; print('ai-example: Distinct FAILED: $e'); print(st); }
  try { await aiExampleDistinctUntilChanged(); print('ai-example: DistinctUntilChanged ok'); }
  catch (e, st) { failures++; print('ai-example: DistinctUntilChanged FAILED: $e'); print(st); }
  try { await aiExampleFilter(); print('ai-example: Filter ok'); }
  catch (e, st) { failures++; print('ai-example: Filter FAILED: $e'); print(st); }
  try { await aiExampleFlow(); print('ai-example: Flow ok'); }
  catch (e, st) { failures++; print('ai-example: Flow FAILED: $e'); print(st); }
  try { await aiExampleFlow_asyncMapLatest(); print('ai-example: Flow.asyncMapLatest ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.asyncMapLatest FAILED: $e'); print(st); }
  try { await aiExampleFlow_combineLatestWith(); print('ai-example: Flow.combineLatestWith ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.combineLatestWith FAILED: $e'); print(st); }
  try { await aiExampleFlow_concatMap(); print('ai-example: Flow.concatMap ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.concatMap FAILED: $e'); print(st); }
  try { await aiExampleFlow_debounce(); print('ai-example: Flow.debounce ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.debounce FAILED: $e'); print(st); }
  try { await aiExampleFlow_distinct(); print('ai-example: Flow.distinct ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.distinct FAILED: $e'); print(st); }
  try { await aiExampleFlow_exhaustMap(); print('ai-example: Flow.exhaustMap ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.exhaustMap FAILED: $e'); print(st); }
  try { await aiExampleFlow_filter(); print('ai-example: Flow.filter ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.filter FAILED: $e'); print(st); }
  try { await aiExampleFlow_fromFuture(); print('ai-example: Flow.fromFuture ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.fromFuture FAILED: $e'); print(st); }
  try { await aiExampleFlow_fromStream(); print('ai-example: Flow.fromStream ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.fromStream FAILED: $e'); print(st); }
  try { await aiExampleFlow_groupBy(); print('ai-example: Flow.groupBy ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.groupBy FAILED: $e'); print(st); }
  try { await aiExampleFlow_map(); print('ai-example: Flow.map ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.map FAILED: $e'); print(st); }
  try { await aiExampleFlow_mergeMap(); print('ai-example: Flow.mergeMap ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.mergeMap FAILED: $e'); print(st); }
  try { await aiExampleFlow_mergeWith(); print('ai-example: Flow.mergeWith ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.mergeWith FAILED: $e'); print(st); }
  try { await aiExampleFlow_of(); print('ai-example: Flow.of ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.of FAILED: $e'); print(st); }
  try { await aiExampleFlow_pluck(); print('ai-example: Flow.pluck ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.pluck FAILED: $e'); print(st); }
  try { await aiExampleFlow_race(); print('ai-example: Flow.race ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.race FAILED: $e'); print(st); }
  try { await aiExampleFlow_retry(); print('ai-example: Flow.retry ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.retry FAILED: $e'); print(st); }
  try { await aiExampleFlow_scan(); print('ai-example: Flow.scan ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.scan FAILED: $e'); print(st); }
  try { await aiExampleFlow_skip(); print('ai-example: Flow.skip ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.skip FAILED: $e'); print(st); }
  try { await aiExampleFlow_switchMap(); print('ai-example: Flow.switchMap ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.switchMap FAILED: $e'); print(st); }
  try { await aiExampleFlow_take(); print('ai-example: Flow.take ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.take FAILED: $e'); print(st); }
  try { await aiExampleFlow_tap(); print('ai-example: Flow.tap ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.tap FAILED: $e'); print(st); }
  try { await aiExampleFlow_throttle(); print('ai-example: Flow.throttle ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.throttle FAILED: $e'); print(st); }
  try { await aiExampleFlow_timeout(); print('ai-example: Flow.timeout ok'); }
  catch (e, st) { failures++; print('ai-example: Flow.timeout FAILED: $e'); print(st); }
  try { await aiExampleFlowHandle(); print('ai-example: FlowHandle ok'); }
  catch (e, st) { failures++; print('ai-example: FlowHandle FAILED: $e'); print(st); }
  try { await aiExampleFlowInstruction(); print('ai-example: FlowInstruction ok'); }
  catch (e, st) { failures++; print('ai-example: FlowInstruction FAILED: $e'); print(st); }
  try { await aiExampleFlowInstructionBase(); print('ai-example: FlowInstructionBase ok'); }
  catch (e, st) { failures++; print('ai-example: FlowInstructionBase FAILED: $e'); print(st); }
  try { await aiExampleMapValue(); print('ai-example: MapValue ok'); }
  catch (e, st) { failures++; print('ai-example: MapValue FAILED: $e'); print(st); }
  try { await aiExampleTap(); print('ai-example: Tap ok'); }
  catch (e, st) { failures++; print('ai-example: Tap FAILED: $e'); print(st); }
  if (failures > 0) {
    print('ai-examples: $failures of 33 failed');
    io.exitCode = 1;
  } else {
    print('ai-examples: all 33 passed');
  }
}
