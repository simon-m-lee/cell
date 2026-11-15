// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  final context = Context.fromEntries([
    Ontology.domains.entry('finance'),
  ]);

  group('explainSource', () {
    test('filters decisions emitted by a given source', () async {
      final source = Cell.ingress<int>(context: context);
      final handle = cognitive(cell: source.cell);
      source.emit(1);
      source.emit(2);
      await Future<void>.delayed(Duration.zero);
      final paths = explainSource(source.cell, handle);
      expect(paths, hasLength(2));
      expect(paths.map((p) => p.pulse?.payload), [1, 2]);
    });

    test('returns an empty list for unrelated sources', () async {
      final source = Cell.ingress<int>(context: context);
      final other = Cell.ingress<int>(context: context);
      final handle = cognitive(cell: source.cell);
      source.emit(1);
      await Future<void>.delayed(Duration.zero);
      expect(explainSource(other.cell, handle), isEmpty);
    });

    test('excludes action decisions', () async {
      final source = Cell.ingress<int>(context: context);
      final handle = cognitive(cell: source.cell);
      int noop() => 0;
      await handle.cognitive.apply<Object>(
        (
          function: noop,
          arguments: (positionalArguments: null, namedArguments: null),
          compensation: null,
        ),
      );
      source.emit(1);
      await Future<void>.delayed(Duration.zero);
      final paths = explainSource(source.cell, handle);
      expect(paths, hasLength(1),
          reason: 'Action decisions have no pulse source.');
    });
  });
}
