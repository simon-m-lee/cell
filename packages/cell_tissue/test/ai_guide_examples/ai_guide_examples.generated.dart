// GENERATED FILE — do not edit by hand.
// Regenerate with: dart run tool/generate_ai_examples.dart
//
// Compiles and executes every `Minimal compilable example` from the
// `### AI Agent Guide` doc blocks in lib/. Verified by
// test/ai_guide_examples_test.dart.
// ignore_for_file: non_constant_identifier_names, avoid_print

import 'package:cell_tissue/cell_tissue.dart';
import 'dart:io' as io;

// <lib/src/tissue.dart:107>
Future<void> aiExampleIterable() async {
  final book = TissueList.of([1, 2, 3]);
  print(book.map((e) => e * 2).toList()); // [2, 4, 6]
}

// <lib/src/tissue_pulse.dart:414>
Future<void> aiExamplePulse() async {
  final book = TissueList.of([1]);
  final seen = <Object?>[];
  final o = Cell.observe(source: book, effect: (Pulse p) => seen.add(p.payload));
  book.add(2);
  o.stop();
  print(seen.length);
}

// <lib/src/test_tissue.dart:81>
Future<void> aiExampleTestTissue() async {
  final gate = TestTissue<int, TissueList<int>>(
    (v, {host, arguments, user}) => (v as int) > 0,
  );
  final book = TissueList<int>(testRule: gate);
  book.add(1);
  book.add(-1); // rejected by the gate
  print(book.length); // 1
}

// <lib/src/tissue_list.dart:401>
Future<void> aiExampleTissueList() async {
  final list = TissueList.of(['a', 'b']);
  list.add('c');
  print(list.length); // 3
}

// <lib/src/tissue_map.dart:415>
Future<void> aiExampleTissueMap() async {
  final map = TissueMap<String, int>(entries: [MapEntry('a', 1)]);
  map['b'] = 2;
  print(map.length); // 2
}

// <lib/src/tissue_queue.dart:416>
Future<void> aiExampleTissueQueue() async {
  final q = TissueQueue<int>(capacity: 3);
  q.addLast(1);
  q.addLast(2);
  print(q.length); // 2
}

// <lib/src/tissue_set.dart:413>
Future<void> aiExampleTissueSet() async {
  final set = TissueSet<int>([1, 2, 2]);
  print(set.length); // 2
}

// <lib/src/tissue_value.dart:416>
Future<void> aiExampleTissueValue() async {
  final q = TissueQueue<int>(capacity: 3);
  q.addLast(1);
  q.addLast(2);
  print(q.length); // 2
}

// <lib/src/tissue.dart:672>
Future<void> aiExampleUnmodifiable() async {
  final book = TissueList.of([1, 2]);
  final ro = book.unmodifiable;
  print(ro.length); // 2
}

Future<void> main() async {
  var failures = 0;
  try { await aiExampleIterable(); print('ai-example: Iterable ok'); }
  catch (e, st) { failures++; print('ai-example: Iterable FAILED: $e'); print(st); }
  try { await aiExamplePulse(); print('ai-example: Pulse ok'); }
  catch (e, st) { failures++; print('ai-example: Pulse FAILED: $e'); print(st); }
  try { await aiExampleTestTissue(); print('ai-example: TestTissue ok'); }
  catch (e, st) { failures++; print('ai-example: TestTissue FAILED: $e'); print(st); }
  try { await aiExampleTissueList(); print('ai-example: TissueList ok'); }
  catch (e, st) { failures++; print('ai-example: TissueList FAILED: $e'); print(st); }
  try { await aiExampleTissueMap(); print('ai-example: TissueMap ok'); }
  catch (e, st) { failures++; print('ai-example: TissueMap FAILED: $e'); print(st); }
  try { await aiExampleTissueQueue(); print('ai-example: TissueQueue ok'); }
  catch (e, st) { failures++; print('ai-example: TissueQueue FAILED: $e'); print(st); }
  try { await aiExampleTissueSet(); print('ai-example: TissueSet ok'); }
  catch (e, st) { failures++; print('ai-example: TissueSet FAILED: $e'); print(st); }
  try { await aiExampleTissueValue(); print('ai-example: TissueValue ok'); }
  catch (e, st) { failures++; print('ai-example: TissueValue FAILED: $e'); print(st); }
  try { await aiExampleUnmodifiable(); print('ai-example: Unmodifiable ok'); }
  catch (e, st) { failures++; print('ai-example: Unmodifiable FAILED: $e'); print(st); }
  if (failures > 0) {
    print('ai-examples: $failures of 9 failed');
    io.exitCode = 1;
  } else {
    print('ai-examples: all 9 passed');
  }
}
