// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_tissue/cell_tissue.dart';

/// Minimal, runnable quick start for `cell_tissue`.
///
/// Shows the three things every tissue can do:
/// 1. behave like the standard Dart collection it wraps,
/// 2. enforce a validation gate on every mutation, and
/// 3. expose a reactive scalar with async, serialized writes.
Future<void> main() async {
  // 1. A reactive list behaves like a normal List.
  final tasks = TissueList.of(['Buy milk', 'Walk dog']);
  tasks.add('Write report');
  tasks.remove('Buy milk');
  print('Tasks: $tasks');

  // 2. Validation is a gate, not a callback you remember to call.
  final positiveIntegers = TissueList<int>(
    testRule: TestTissue<int, TissueList<int>>(
      (value, {host, arguments, user}) => (value as int) > 0,
    ),
  );
  positiveIntegers.add(5); // accepted
  positiveIntegers.add(-3); // rejected by the gate, no event emitted
  print('Positive integers: $positiveIntegers');

  // 3. A reactive scalar with an async, lock-serialized write path.
  final counter = TissueValue<int>(0);
  counter.value = 42;
  final asyncCounter = ModifiableValueAsync<int>(counter);
  await asyncCounter.set(100);
  print('Counter: ${counter.value}');
}
