// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// The demo's network-boundary gate: two kiosk "processes" (two
// `FirebaseMemoryStore`s, one shared uid) race the stock book through
// the demo's own books, pipeline, and memory boundary — the 1.0.0
// two-client acceptance shape, live.
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

import 'package:cell_memory/cell_memory.dart';
import 'package:cell_memory_firebase/cell_memory_firebase.dart';
import 'package:cell_memory_live_demo/boundary/firebase.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cell_memory_live_demo/boundary/memory.dart';
import 'package:cell_memory_live_demo/domain/books.dart';
import 'package:cell_memory_live_demo/domain/pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Runs on a real device/Chrome runner where the Firebase plugins have
  // their platform channels; the VM `flutter test` harness does not.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('the last-cup race: a stale generation after remove-and-recreate '
      'is a MemoryConflict carrying the new generation', () async {
    if (Platform.environment['FIRESTORE_EMULATOR_HOST'] == null) {
      markTestSkipped(
          'FIRESTORE_EMULATOR_HOST is unset; run under firebase '
          'emulators:exec with --only firestore,auth');
      return;
    }

    final boot = await bootFirebase();
    final storeA = FirebaseMemoryStore(firestore: boot.db, uid: boot.uid);
    final storeB = FirebaseMemoryStore(firestore: boot.db, uid: boot.uid);

    // Rules smoke test: a wrong-uid store must be denied. If this passes
    // on an open emulator, the rules were not loaded. Stop.
    final intruder =
        FirebaseMemoryStore(firestore: boot.db, uid: 'someone-else');
    await expectLater(
      intruder.write(
        MemoryEnvelope(
          generation: MemoryEnvelope.mintGeneration(),
          id: 'stock',
          revision: 1,
          payload: 0,
        ),
        expectedRevision: 0,
      ),
      throwsA(isA<MemoryIoException>()),
      reason: 'wrong-uid writes must be denied by firestore.rules',
    );

    // Kiosk A boots cold and brews: stock 24 → 23, revision 1, G1.
    final booksA = KioskBooks();
    final boundaryA = MemoryBoundary(books: booksA, store: storeA);
    await boundaryA.open();
    final pipelineA = OrderPipeline(booksA);
    pipelineA.order(const OrderLine(drink: 'flat white', price: 2.50));
    await boundaryA.saveAll();
    final row1 = await storeA.read('stock');
    expect(row1?.revision, 1);
    expect(row1?.payload, 23);
    final g1 = row1!.generation;

    // Kiosk B boots and loads the same row.
    final booksB = KioskBooks();
    final boundaryB = MemoryBoundary(books: booksB, store: storeB);
    await boundaryB.open();
    final pipelineB = OrderPipeline(booksB);
    expect(booksB.stock.value, 23);

    // Kiosk B removes, then brews: the new row is revision 1 again with
    // a fresh generation G2.
    await boundaryB.stockMemory!.remove();
    pipelineB.order(const OrderLine(drink: 'cold brew', price: 3.00));
    await boundaryB.saveAll();
    final row2 = await storeB.read('stock');
    expect(row2?.revision, 1);
    expect(row2?.payload, 22);
    final g2 = row2!.generation;
    expect(g2, isNot(g1));

    // Kiosk A, which never reloaded, brews the last cup and syncs: the
    // stale generation is a MemoryConflict whose stored generation is
    // G2, and the boundary adopts the winner. The bug the plan closes is
    // A reusing G1.
    pipelineA.order(const OrderLine(drink: 'espresso', price: 1.50));
    await boundaryA.syncAll();
    expect(booksA.stock.value, 22,
        reason: 'the boundary adopted the winner after the conflict');

    final fromA = await storeA.read('stock');
    final fromB = await storeB.read('stock');
    expect(fromA?.payload, 22);
    expect(fromA?.generation, g2);
    expect(fromB?.payload, 22);
    expect(fromB?.generation, g2);
  });
}
