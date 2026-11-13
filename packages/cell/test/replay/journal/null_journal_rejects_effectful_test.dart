// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  test('NullJournal refuses effectful operations loudly', () {
    expect(
      () => NullJournal.instance.clock(),
      throwsA(isA<StateError>()),
    );
    expect(
      () => NullJournal.instance.uuid(),
      throwsA(isA<StateError>()),
    );
    expect(
      () => NullJournal.instance.io(
        label: 'x',
        input: null,
        run: () async => 'y',
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => NullJournal.instance.timer(
        duration: const Duration(milliseconds: 1),
        input: null,
        onFire: () {},
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('EffectJournal.current outside a scope is NullJournal', () {
    expect(EffectJournal.current, isA<NullJournal>());
    expect(EffectJournal.current, same(NullJournal.instance));
  });

  test('JournalScope is drained on exit', () async {
    final journal = RecordingJournal();
    expect(EffectJournal.current, isA<NullJournal>());

    await JournalScope.run(journal, () async {
      expect(EffectJournal.current, same(journal));
      // Nested scope: the inner journal shadows the outer one and the
      // outer one is restored on pop.
      final inner = RecordingJournal();
      await JournalScope.run(inner, () async {
        expect(EffectJournal.current, same(inner));
        return null;
      });
      expect(EffectJournal.current, same(journal));
      return null;
    });

    expect(EffectJournal.current, isA<NullJournal>());
  });

  test('JournalScope pops the journal even when the body throws', () async {
    final journal = RecordingJournal();
    await expectLater(
      JournalScope.run(journal, () async => throw StateError('boom')),
      throwsStateError,
    );
    expect(EffectJournal.current, isA<NullJournal>());
  });

  test('an effectful mapper that uses the ambient journal gets the same '
      'journal as its parameter', () async {
    final src = Cell.ingress<int>();
    final journal = RecordingJournal();
    EffectJournal? ambient;
    final out = Cell.asyncMap<int, String>(
      src.cell,
      (v, {required EffectJournal journal}) async {
        ambient = EffectJournal.current;
        return journal.io(
          label: 'ambient($v)',
          input: v,
          run: () async => 'ok-$v',
        );
      },
      journal: journal,
    );
    final observer = Cell.observe(source: out, effect: (Pulse p) {});
    src.emit(1);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(ambient, same(journal));
    expect(journal.consumed, 1);
    observer.stop();
  });
}
