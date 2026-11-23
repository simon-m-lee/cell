// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// The 1.0.0 release gate: two Firebase clients racing one memory id under
// the shipped rules, with the generation protocol closing the
// delete-and-recreate ABA hole.
//
// Run only under the emulator:
//
//   firebase emulators:exec --only firestore,auth --project demo-cell-memory \
//     "flutter test --tags acceptance"
//
// Default `flutter test` skips this file when FIRESTORE_EMULATOR_HOST is
// unset; the CI job fails if the JSON reporter shows it skipped.

@Tags(['acceptance'])
library;

import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_memory/cell_memory.dart';
import 'package:cell_memory_firebase/cell_memory_firebase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const String _projectId = 'demo-cell-memory';
const String _uid = 'same-user';
const String _email = 'race@example.com';
const String _password = 'race-password';

void main() {
  // The Firebase plugins need a real device runner (platform channels);
  // the VM flutter test harness has none.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('two clients: a stale generation after remove-and-recreate is a '
      'MemoryConflict carrying the new generation', () async {
    if (Platform.environment['FIRESTORE_EMULATOR_HOST'] == null) {
      markTestSkipped(
          'FIRESTORE_EMULATOR_HOST is unset; run under firebase '
          'emulators:exec with --only firestore,auth');
      return;
    }

    final options = FirebaseOptions(
      apiKey: 'demo',
      appId: 'demo',
      messagingSenderId: 'demo',
      projectId: _projectId,
    );
    final appA = await Firebase.initializeApp(name: 'client-a', options: options);
    final appB = await Firebase.initializeApp(name: 'client-b', options: options);
    addTearDown(() async {
      await appA.delete();
      await appB.delete();
    });

    FirebaseFirestore.instanceFor(app: appA).settings = const Settings(
      persistenceEnabled: false,
      sslEnabled: false,
    );
    FirebaseFirestore.instanceFor(app: appB).settings = const Settings(
      persistenceEnabled: false,
      sslEnabled: false,
    );
    final dbA = FirebaseFirestore.instanceFor(app: appA);
    final dbB = FirebaseFirestore.instanceFor(app: appB);
    final authA = FirebaseAuth.instanceFor(app: appA);
    final authB = FirebaseAuth.instanceFor(app: appB);
    await authA.useAuthEmulator('127.0.0.1', 9099);
    await authB.useAuthEmulator('127.0.0.1', 9099);

    // One user on both clients.
    try {
      await authA.createUserWithEmailAndPassword(
          email: _email, password: _password);
    } on FirebaseAuthException {
      // Already created by a previous run.
    }
    await authB.signInWithEmailAndPassword(
        email: _email, password: _password);

    // 1. A wrong-uid store must be denied: if this passes on an open
    //    emulator, the rules were not loaded. Stop.
    final intruder = FirebaseMemoryStore(firestore: dbA, uid: 'someone-else');
    await expectLater(
      intruder.write(
        MemoryEnvelope(
          generation: MemoryEnvelope.mintGeneration(),
          id: 'counter',
          revision: 1,
          payload: 0,
          codec: 'json',
        ),
        expectedRevision: 0,
      ),
      throwsA(isA<MemoryIoException>()),
      reason: 'wrong-uid writes must be denied by firestore.rules',
    );

    final storeA = FirebaseMemoryStore(firestore: dbA, uid: _uid);
    final storeB = FirebaseMemoryStore(firestore: dbB, uid: _uid);

    // 2. Cell A creates revision 1 with generation G1.
    final cellA = await MemoryCell.open<int>(
      id: 'counter',
      store: storeA,
      codec: JsonMemoryCodec<int>.identity(),
      initial: 0,
      policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
    );
    await _deliver(cellA, 1);
    await cellA.save();
    final row1 = await storeA.read('counter');
    expect(row1?.revision, 1);
    final g1 = row1!.generation;

    // 3. Cell B loads that row.
    final cellB = await MemoryCell.open<int>(
      id: 'counter',
      store: storeB,
      codec: JsonMemoryCodec<int>.identity(),
      initial: 0,
      policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
    );
    expect(cellB.revision, 1);

    // 4. Cell B removes, then saves 2: the new row is revision 1 again,
    //    with a fresh generation G2.
    await cellB.remove();
    await _deliver(cellB, 2);
    await cellB.save();
    final row2 = await storeB.read('counter');
    expect(row2?.revision, 1);
    expect(row2?.payload, 2);
    final g2 = row2!.generation;
    expect(g2, isNot(g1));

    // 5-6. Cell A, which has not reloaded, saves 3: a MemoryConflict
    //      whose stored generation is G2. The bug the plan closes is the
    //      cell reusing G1.
    await _deliver(cellA, 3);
    try {
      await cellA.save();
      fail('expected MemoryConflict from the stale cell');
    } on MemoryConflict catch (conflict) {
      expect(conflict.stored?.generation, g2);
    }
    final fromA = await storeA.read('counter');
    final fromB = await storeB.read('counter');
    expect(fromA?.payload, 2);
    expect(fromA?.generation, g2);
    expect(fromB?.payload, 2);
    expect(fromB?.generation, g2);
  });
}

Future<void> _deliver<T>(MemoryCell<T> cell, T? value) async {
  final tx = Cell.transaction();
  await tx.begin([cell]);
  tx.update(cell, value);
  await tx.commit();
}
