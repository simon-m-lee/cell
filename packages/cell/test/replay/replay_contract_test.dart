// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell/replay.dart';
import 'package:test/test.dart';

import 'ledger_store_conformance.dart';

/// The acceptance criterion for any `LedgerStore`: the shipped stores
/// pass the conformance suite, so a downstream store that passes it is
/// behaviourally interchangeable.
///
/// the tooling layer's exit criterion: this suite passes for
/// `InMemoryLedgerStore` and `FileLedgerStore`.
void main() {
  runLedgerStoreConformance(
    'InMemoryLedgerStore',
    () => InMemoryLedgerStore(genesisHash: 'test-genesis'),
  );

  // The durable factory must reopen the *same* file within one test;
  // `fresh` allocates a new per-test file so tests do not pollute each
  // other (the conformance suite calls it before every test body).
  late final Directory dir;
  late String path;
  var fileCounter = 0;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('file_store_conformance');
  });
  tearDownAll(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  runLedgerStoreConformance(
    'FileLedgerStore',
    () => FileLedgerStore.open(path, genesisHash: 'test-genesis'),
    isDurable: true,
    fresh: () {
      path = '${dir.path}/ledger-${++fileCounter}.jsonl';
    },
  );
}
