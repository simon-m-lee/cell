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
      // This file only runs on a device under 
      // (the plain 00:00 +0: loading D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart
00:00 +0: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: read of a missing document returns null and creates nothing
00:00 +1: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: create: expectedRevision 0 writes revision 1 with a JSON-string payload
00:00 +2: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: round-trip: read returns the envelope with the payload decoded
00:00 +3: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: CAS: expecting 4 installs 5; a second writer still expecting 4 gets MemoryConflict and the document stays the winner
00:00 +4: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: idempotent retry: this writer payload at expectedRevision + 1 returns success and does not set again
00:00 +5: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: lost race: a different payload at expectedRevision + 1 throws MemoryConflict and never sets
00:00 +6: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: an envelope numbered wrong throws MemoryCorrupt and never sets
00:00 +7: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: permission denied surfaces as MemoryIoException and is not retried as contention
00:00 +8: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: remove deletes the document; a second remove succeeds
00:00 +9: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: list returns ids under this uid only
00:00 +10: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: closed: read after close throws StateError; double close throws
00:00 +11: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: uid validation rejects empty ids and slashes
00:00 +12: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: memory id validation rejects hostile ids before any request
00:00 +13: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: the same envelope fixture round-trips through the file store and the firestore store
00:00 +14: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: a newer-schema document at the expected revision is corrupt, not overwritten
00:00 +15: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: an unencodable payload fails before any transaction
00:00 +16: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: an oversized document fails with a clear error before any transaction
00:00 +17: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: an oversized document fails with a clear error before any transaction
00:00 +18: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: an oversized document fails with a clear error before any transaction
00:00 +19: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: an oversized document fails with a clear error before any transaction
00:00 +20: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/mapping_test.dart: encodeDocument the document contains the generation
00:00 +21: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: list fails closed on an id the grammar rejects and deletes nothing
00:00 +22: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: list fails closed on an id the grammar rejects and deletes nothing
00:00 +23: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/mapping_test.dart: decodeDocument round-trips every JSON shape
00:00 +24: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/mapping_test.dart: decodeDocument round-trips every JSON shape
00:00 +25: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/mapping_test.dart: decodeDocument round-trips every JSON shape
00:00 +26: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: close drains an in-flight write started before it
00:00 +27: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/mapping_test.dart: decodeDocument the string "[1, 2]" decodes as a string, not a list
00:00 +28: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/mapping_test.dart: decodeDocument a missing payload throws MemoryCorrupt
00:00 +29: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/mapping_test.dart: decodeDocument a missing payload throws MemoryCorrupt
00:00 +30: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: the equal-revision shape with a different payload is a conflict
00:00 +31: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/mapping_test.dart: decodeDocument a missing generation throws MemoryCorrupt
00:00 +32: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: reads and lists use the configured source (server by default)
00:00 +33: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: reads and lists use the configured source (server by default)
00:00 +34: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/mapping_test.dart: decodeDocument a schema other than 1 throws MemoryCorrupt
00:00 +35: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: permission-denied on read and list surfaces as MemoryIoException
00:00 +36: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/mapping_test.dart: decodeDocument an id that does not match the path throws MemoryCorrupt
00:00 +37: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: an update with a different generation at the right revision is MemoryConflict; the winner and its generation survive
00:00 +38: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/mapping_test.dart: decodeDocument unknown keys throw MemoryCorrupt, matching the file envelope
00:00 +39: D:/Users/Simon/Workspaces/cell/packages/cell_memory_firebase/test/firebase_store_test.dart: the stale generation after remove-and-recreate is a conflict, not an ABA win
00:00 +40: All tests passed! harness never picks up
      // integration_test/), so an unset host is a broken run, not a skip.
      fail('FIRESTORE_EMULATOR_HOST is unset; run under firebase '
          'emulators:exec with --only firestore,auth');
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
