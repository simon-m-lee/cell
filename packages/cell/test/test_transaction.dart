// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'package:test/test.dart';
import 'package:cell/cell.dart';

// ignore_for_file: use_super_parameters

// ─────────────────────────────────────────────────────────────────────────
// Test Fixtures
// ─────────────────────────────────────────────────────────────────────────

/// A [ValueCell] whose receptor records each applied write.
///
/// Commit applies via [ValueCell]'s `_emit`, which runs this transform and
/// then the post-process rule that stores the value. [updateCount] therefore
/// counts real applies, not buffered [TransactionScope.update] calls.
class TrackedValueCell<V> extends ValueCell<V> {
  int updateCount = 0;

  TrackedValueCell({
    V? initial,
    Cell? bind,
    Context context = Context.system,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
  }) : super(
          initial: initial,
          bind: bind,
          context: context,
          testRule: testRule,
          synapses: synapses,
          transform: (host, pulse, {user, bind}) {
            (host as TrackedValueCell<V>).updateCount++;
            return pulse as Pulse<V>?;
          },
        );
}

/// A [ValueCell] whose [TestCell] records each commit-time candidate and
/// rejects negatives. Live state is the nucleus box — not a shadow field —
/// so failed commits can be asserted against [value].
class ValidatingCell<T> extends ValueCell<T> {
  final List<T?> validationAttempts = [];

  ValidatingCell({
    T? initial,
    Cell? bind,
    Context context = Context.system,
    Synapses synapses = Synapses.enabled,
  }) : super(
          initial: initial,
          bind: bind,
          context: context,
          synapses: synapses,
          testRule: TestCell<Cell>((object, {host, arguments, user}) {
            final candidate = object is Pulse ? object.payload : object;
            if (host is ValidatingCell<T>) {
              host.validationAttempts.add(candidate as T?);
            }
            if (candidate is num) return candidate >= 0;
            return candidate != null;
          }),
        );
}

/// A non-[ValueCell] that records pulses delivered through its receptor.
class RecordingCell extends CellBase {
  final List<Pulse> receivedPulses = [];
  final List<dynamic> receivedPayloads = [];

  RecordingCell({super.bind})
      : super(
          receptor: Receptor((cell, pulse, {user}) {
            final recorder = cell as RecordingCell;
            recorder.receivedPulses.add(pulse);
            recorder.receivedPayloads.add(pulse.payload);
            return pulse;
          }),
        );
}

// ─────────────────────────────────────────────────────────────────────────
// Helper Functions
// ─────────────────────────────────────────────────────────────────────────

({TrackedValueCell<int> a, TrackedValueCell<int> b}) createAccountPair({
  int initialA = 100,
  int initialB = 200,
}) {
  final a = TrackedValueCell<int>(initial: initialA);
  final b = TrackedValueCell<int>(initial: initialB);
  return (a: a, b: b);
}

/// Commits [newValue] through a separate transaction so isolation tests can
/// change live state without calling library-private `_emit`.
Future<void> commitLive<T>(ValueCell<T> cell, T? newValue) async {
  final tx = Cell.transaction();
  await tx.begin([cell]);
  tx.update(cell, newValue);
  await tx.commit();
}

Future<void> delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

TestCell<Cell> nonNegativeRule() {
  return TestCell<Cell>((object, {host, arguments, user}) {
    final candidate = object is Pulse ? object.payload : object;
    if (candidate is int) {
      return candidate >= 0;
    }
    return true;
  });
}

Matcher isValidationException({dynamic value, int? count}) {
  var matcher = isA<TransactionValidationException>();
  if (count != null) {
    matcher = matcher.having((e) => e.failures.length, 'failures.length', count);
  }
  if (value != null) {
    matcher = matcher.having(
      (e) => e.failures.map((f) => f.value),
      'failure values',
      contains(value),
    );
  }
  return matcher;
}

Matcher isConflictException({dynamic value}) {
  var matcher = isA<TransactionConflictException>();
  if (value != null) {
    matcher = matcher.having(
      (e) => e.conflicts.map((c) => c.value),
      'conflict values',
      contains(value),
    );
  }
  return matcher;
}

// ─────────────────────────────────────────────────────────────────────────
// Transaction Tests
// ─────────────────────────────────────────────────────────────────────────

void main() {
  group('Cell.transaction', () {
    group('Basic Transaction', () {
      test('commits multiple updates atomically', () async {
        final accounts = createAccountPair();
        final tx = Cell.transaction();

        await tx.begin([accounts.a, accounts.b]);

        expect(accounts.a.value, 100);
        expect(accounts.b.value, 200);

        final fromBalance = tx.read(accounts.a) as int;
        final toBalance = tx.read(accounts.b) as int;

        tx.update(accounts.a, fromBalance - 50);
        tx.update(accounts.b, toBalance + 50);

        expect(tx.pending(accounts.a), 50);
        expect(tx.pending(accounts.b), 250);
        expect(accounts.a.value, 100, reason: 'live value stays buffered until commit');
        expect(accounts.b.value, 200);
        expect(accounts.a.updateCount, 0);

        await tx.commit();

        expect(accounts.a.value, 50);
        expect(accounts.b.value, 250);
        expect(accounts.a.updateCount, 1);
        expect(accounts.b.updateCount, 1);
        await expectLater(tx.commit(), throwsA(isA<StateError>()));
      });

      test('rollback discards all changes', () async {
        final accounts = createAccountPair();
        final tx = Cell.transaction();

        await tx.begin([accounts.a, accounts.b]);

        tx.update(accounts.a, 50);
        tx.update(accounts.b, 250);
        expect(tx.pending(accounts.a), 50);

        await tx.rollback();

        expect(accounts.a.value, 100);
        expect(accounts.b.value, 200);
        expect(accounts.a.updateCount, 0);
        expect(accounts.b.updateCount, 0);
        expect(() => tx.read(accounts.a), throwsA(isA<StateError>()));
        expect(() => tx.update(accounts.a, 1), throwsA(isA<StateError>()));
      });

      test('commit after rollback works', () async {
        final accounts = createAccountPair();
        final tx = Cell.transaction();

        await tx.begin([accounts.a, accounts.b]);
        tx.update(accounts.a, 50);
        tx.update(accounts.b, 250);
        await tx.rollback();

        expect(accounts.a.value, 100);
        expect(accounts.b.value, 200);

        await tx.begin([accounts.a, accounts.b]);
        tx.update(accounts.a, 75);
        tx.update(accounts.b, 225);
        await tx.commit();

        expect(accounts.a.value, 75);
        expect(accounts.b.value, 225);
      });

      test('cannot begin while transaction is active', () async {
        final accounts = createAccountPair();
        final tx = Cell.transaction();

        await tx.begin([accounts.a, accounts.b]);
        tx.update(accounts.a, 1);

        await expectLater(
          tx.begin([accounts.a, accounts.b]),
          throwsA(isA<StateError>()),
        );
        expect(tx.pending(accounts.a), 1);

        await tx.rollback();
        expect(accounts.a.value, 100);
      });

      test('cannot update cell not in transaction', () async {
        final accounts = createAccountPair();
        final extra = TrackedValueCell<int>(initial: 300);
        final tx = Cell.transaction();

        await tx.begin([accounts.a, accounts.b]);

        expect(() => tx.update(extra, 400), throwsA(isA<ArgumentError>()));
        expect(extra.value, 300);

        await tx.commit();
        expect(accounts.a.value, 100);
        expect(extra.value, 300);
      });

      test('cannot read cell not in transaction', () async {
        final accounts = createAccountPair();
        final extra = TrackedValueCell<int>(initial: 300);
        final tx = Cell.transaction();

        await tx.begin([accounts.a, accounts.b]);

        expect(() => tx.read(extra), throwsA(isA<ArgumentError>()));
        expect(tx.read(accounts.a), 100);

        await tx.commit();
      });

      test('transaction with single cell', () async {
        final cell = TrackedValueCell<int>(initial: 42);
        final tx = Cell.transaction();

        await tx.begin([cell]);
        expect(tx.read(cell), 42);
        tx.update(cell, 100);
        expect(cell.value, 42);
        await tx.commit();

        expect(cell.value, 100);
        expect(cell.updateCount, 1);
      });

      test('empty cells list throws', () async {
        final tx = Cell.transaction();

        await expectLater(
          tx.begin([]),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('At least one cell'),
          )),
        );
      });
    });

    group('Isolation Levels', () {
      test('readCommitted reads current live values', () async {
        final accounts = createAccountPair();
        final tx = Cell.transaction(TransactionOptions(
          isolation: IsolationLevel.readCommitted,
        ));

        await tx.begin([accounts.a, accounts.b]);
        expect(tx.read(accounts.a), 100);

        await commitLive(accounts.a, 175);
        expect(accounts.a.value, 175);
        expect(tx.read(accounts.a), 175, reason: 'readCommitted sees live writes');

        tx.update(accounts.b, 201);
        await tx.commit();

        expect(accounts.a.value, 175);
        expect(accounts.b.value, 201);
      });

      test('repeatableRead reads snapshot from begin', () async {
        final accounts = createAccountPair();
        final tx = Cell.transaction(TransactionOptions(
          isolation: IsolationLevel.repeatableRead,
        ));

        await tx.begin([accounts.a, accounts.b]);
        expect(tx.read(accounts.a), 100);

        await commitLive(accounts.a, 175);
        expect(accounts.a.value, 175);
        expect(tx.read(accounts.a), 100, reason: 'repeatableRead returns the begin snapshot');

        await tx.rollback();
        expect(accounts.a.value, 175);
      });

      test('repeatableRead detects conflict on changed cell', () async {
        final accounts = createAccountPair();
        final tx = Cell.transaction(TransactionOptions(
          isolation: IsolationLevel.repeatableRead,
        ));

        await tx.begin([accounts.a, accounts.b]);
        tx.update(accounts.a, 75);

        await commitLive(accounts.a, 999);

        await expectLater(
          tx.commit(),
          throwsA(isConflictException(value: 999)),
        );
        expect(accounts.a.value, 999, reason: 'conflicting live write is kept');
        expect(accounts.b.value, 200);
      });

      test('serializable tracks read set', () async {
        final accounts = createAccountPair();
        final tx = Cell.transaction(TransactionOptions(
          isolation: IsolationLevel.serializable,
        ));

        await tx.begin([accounts.a, accounts.b]);
        expect(tx.read(accounts.a), 100);
        tx.update(accounts.b, 300);

        await commitLive(accounts.a, 50);

        await expectLater(
          tx.commit(),
          throwsA(isConflictException(value: 50)),
        );
        expect(accounts.a.value, 50);
        expect(accounts.b.value, 200, reason: 'buffered write to b is discarded');
      });

      test('serializable ignores unread, unwritten participant changes', () async {
        final accounts = createAccountPair();
        final tx = Cell.transaction(TransactionOptions(
          isolation: IsolationLevel.serializable,
        ));

        await tx.begin([accounts.a, accounts.b]);
        tx.update(accounts.b, 300);

        await commitLive(accounts.a, 50);

        await tx.commit();
        expect(accounts.a.value, 50);
        expect(accounts.b.value, 300);
      });

      test('serializable commits globally serialized', () async {
        final accounts = createAccountPair();
        final tx1 = Cell.transaction(TransactionOptions(
          isolation: IsolationLevel.serializable,
        ));
        final tx2 = Cell.transaction(TransactionOptions(
          isolation: IsolationLevel.serializable,
        ));

        await tx1.begin([accounts.a, accounts.b]);
        await tx2.begin([accounts.a, accounts.b]);

        tx1.update(accounts.a, (tx1.read(accounts.a) as int) + 10);
        tx1.update(accounts.b, (tx1.read(accounts.b) as int) + 20);
        await tx1.commit();

        expect(accounts.a.value, 110);
        expect(accounts.b.value, 220);

        tx2.update(accounts.a, 1);
        await expectLater(tx2.commit(), throwsA(isA<TransactionConflictException>()));
        expect(accounts.a.value, 110);
        expect(accounts.b.value, 220);
      });
    });

    group('Lock Ordering', () {
      test('byHashCode orders locks by hash code', () async {
        final cell1 = TrackedValueCell<int>(initial: 1);
        final cell2 = TrackedValueCell<int>(initial: 2);
        final cell3 = TrackedValueCell<int>(initial: 3);

        final tx = Cell.transaction(TransactionOptions(
          ordering: LockOrdering.byHashCode,
        ));

        await tx.begin([cell1, cell2, cell3]);
        tx.update(cell1, 10);
        tx.update(cell2, 20);
        tx.update(cell3, 30);
        await tx.commit();

        expect(cell1.value, 10);
        expect(cell2.value, 20);
        expect(cell3.value, 30);
      });

      test('insertion orders locks by insertion order', () async {
        final cell1 = TrackedValueCell<int>(initial: 1);
        final cell2 = TrackedValueCell<int>(initial: 2);
        final cell3 = TrackedValueCell<int>(initial: 3);

        final tx = Cell.transaction(TransactionOptions(
          ordering: LockOrdering.insertion,
        ));

        await tx.begin([cell1, cell2, cell3]);
        tx.update(cell1, 10);
        tx.update(cell2, 20);
        tx.update(cell3, 30);
        await tx.commit();

        expect(cell1.value, 10);
        expect(cell2.value, 20);
        expect(cell3.value, 30);
      });

      test('explicit uses custom comparator', () async {
        final cell1 = TrackedValueCell<int>(initial: 1);
        final cell2 = TrackedValueCell<int>(initial: 2);
        var comparisons = 0;

        final tx = Cell.transaction(TransactionOptions(
          ordering: LockOrdering.explicit,
          comparator: (a, b) {
            comparisons++;
            return b.hashCode.compareTo(a.hashCode);
          },
        ));

        await tx.begin([cell1, cell2]);
        tx.update(cell1, 10);
        tx.update(cell2, 20);
        await tx.commit();

        expect(comparisons, greaterThan(0), reason: 'commit sorts locks with the comparator');
        expect(cell1.value, 10);
        expect(cell2.value, 20);
      });

      test('explicit without comparator throws', () {
        expect(
          () => Cell.transaction(TransactionOptions(
            ordering: LockOrdering.explicit,
          )),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('comparator'),
          )),
        );
      });
    });

    group('Validation', () {
      test('validation fails on invalid value', () async {
        final cell = ValidatingCell<int>(initial: 10);
        final tx = Cell.transaction();

        await tx.begin([cell]);
        tx.update(cell, -5);

        await expectLater(
          tx.commit(),
          throwsA(isValidationException(value: -5, count: 1)),
        );
        expect(cell.value, 10);
        expect(cell.validationAttempts, contains(-5));
        expect(() => tx.read(cell), throwsA(isA<StateError>()));
      });

      test('custom validate callback can override', () async {
        final cell = TrackedValueCell<int>(initial: 10);

        final tx = Cell.transaction(TransactionOptions(
          validate: (cell, value) {
            if (value is int) {
              return value.isOdd;
            }
            return true;
          },
        ));

        await tx.begin([cell]);
        tx.update(cell, 7);
        await tx.commit();
        expect(cell.value, 7);

        await tx.begin([cell]);
        tx.update(cell, 8);

        await expectLater(
          tx.commit(),
          throwsA(isValidationException(value: 8)),
        );
        expect(cell.value, 7);
      });

      test('multiple cells validation', () async {
        final cell1 = ValidatingCell<int>(initial: 10);
        final cell2 = ValidatingCell<int>(initial: 20);

        final tx = Cell.transaction();

        await tx.begin([cell1, cell2]);
        tx.update(cell1, 5);
        tx.update(cell2, -5);

        await expectLater(
          tx.commit(),
          throwsA(isValidationException(value: -5)),
        );
        expect(cell1.value, 10, reason: 'no partial apply on validation failure');
        expect(cell2.value, 20);
      });

      test('cell testRule rejects negatives at commit', () async {
        final cell = TrackedValueCell<int>(
          initial: 10,
          testRule: nonNegativeRule(),
        );
        final tx = Cell.transaction();

        await tx.begin([cell]);
        tx.update(cell, -1);

        await expectLater(
          tx.commit(),
          throwsA(isValidationException(value: -1)),
        );
        expect(cell.value, 10);
        expect(cell.updateCount, 0);
      });
    });

    group('Custom Apply', () {
      test('custom apply callback overrides default', () async {
        var appliedValue = 0;
        final cell = TrackedValueCell<int>(initial: 10);

        final tx = Cell.transaction(TransactionOptions(
          apply: (cell, value) {
            appliedValue = value as int;
          },
        ));

        await tx.begin([cell]);
        tx.update(cell, 42);
        await tx.commit();

        expect(appliedValue, 42);
        expect(cell.value, 10, reason: 'custom apply replaces _emit');
        expect(cell.updateCount, 0);
      });

      test('custom apply with side effects', () async {
        var sideEffectCount = 0;
        final cell = TrackedValueCell<int>(initial: 10);

        final tx = Cell.transaction(TransactionOptions(
          apply: (cell, value) {
            sideEffectCount++;
          },
        ));

        await tx.begin([cell]);
        tx.update(cell, 42);
        await tx.commit();

        expect(sideEffectCount, 1);
        expect(cell.value, 10);
      });

      test('custom apply with multiple cells', () async {
        final applied = <int>[];
        final cell1 = TrackedValueCell<int>(initial: 10);
        final cell2 = TrackedValueCell<int>(initial: 20);

        final tx = Cell.transaction(TransactionOptions(
          apply: (cell, value) {
            applied.add(value as int);
          },
        ));

        await tx.begin([cell1, cell2]);
        tx.update(cell1, 100);
        tx.update(cell2, 200);
        await tx.commit();

        expect(applied, [100, 200]);
        expect(cell1.value, 10);
        expect(cell2.value, 20);
      });
    });

    group('Savepoint', () {
      test('savepoint captures state for rollback', () async {
        final cell1 = TrackedValueCell<int>(initial: 10);
        final cell2 = TrackedValueCell<int>(initial: 20);
        final tx = Cell.transaction();

        await tx.begin([cell1, cell2]);

        tx.update(cell1, 100);
        tx.update(cell2, 200);
        final sp = tx.savepoint();
        tx.update(cell1, 150);
        tx.update(cell2, 250);

        expect(tx.pending(cell1), 150);
        await tx.rollback(savepoint: sp);
        expect(tx.pending(cell1), 100);
        expect(tx.pending(cell2), 200);
        expect(cell1.value, 10);

        await tx.commit();

        expect(cell1.value, 100);
        expect(cell2.value, 200);
      });

      test('multiple savepoint', () async {
        final cell = TrackedValueCell<int>(initial: 0);
        final tx = Cell.transaction();

        await tx.begin([cell]);

        tx.update(cell, 10);
        tx.savepoint();

        tx.update(cell, 20);
        final sp2 = tx.savepoint();

        tx.update(cell, 30);
        tx.savepoint();

        expect(tx.pending(cell), 30);
        await tx.rollback(savepoint: sp2);
        expect(tx.pending(cell), 20);

        await tx.commit();

        expect(cell.value, 20);
      });

      test('rollback to unknown savepoint throws', () async {
        final cell = TrackedValueCell<int>(initial: 0);
        final tx = Cell.transaction();

        await tx.begin([cell]);
        tx.update(cell, 10);

        await expectLater(
          tx.rollback(savepoint: 999),
          throwsA(isA<ArgumentError>()),
        );
        expect(tx.pending(cell), 10);

        await tx.commit();
        expect(cell.value, 10);
      });

      test('savepoint after rollback', () async {
        final cell = TrackedValueCell<int>(initial: 0);
        final tx = Cell.transaction();

        await tx.begin([cell]);

        tx.update(cell, 10);
        final sp1 = tx.savepoint();

        tx.update(cell, 20);
        await tx.rollback(savepoint: sp1);
        expect(tx.pending(cell), 10);

        tx.savepoint();
        tx.update(cell, 30);
        expect(tx.pending(cell), 30);

        await tx.commit();

        expect(cell.value, 30);
      });
    });

    group('Timeout', () {
      test('transaction times out', () async {
        final cell = TrackedValueCell<int>(initial: 0);
        final tx = Cell.transaction(TransactionOptions(
          timeout: Duration(milliseconds: 50),
        ));

        await tx.begin([cell]);
        tx.update(cell, 7);
        await delay(100);

        await expectLater(
          tx.commit(),
          throwsA(isA<TransactionTimeoutException>().having(
            (e) => e.timeout,
            'timeout',
            Duration(milliseconds: 50),
          )),
        );
        expect(cell.value, 0);
      });

      test('timeout triggers rollback', () async {
        final cell = TrackedValueCell<int>(initial: 0);
        final tx = Cell.transaction(TransactionOptions(
          timeout: Duration(milliseconds: 50),
        ));

        await tx.begin([cell]);
        tx.update(cell, 100);
        await delay(100);

        await expectLater(
          tx.commit(),
          throwsA(isA<TransactionTimeoutException>()),
        );
        expect(cell.value, 0);
        expect(cell.updateCount, 0);
      });

      test('timeout event emitted', () async {
        TransactionTimedOut? timeoutEvent;
        final cell = TrackedValueCell<int>(initial: 0);

        final tx = Cell.transaction(TransactionOptions(
          timeout: Duration(milliseconds: 50),
          onEvent: (event) {
            if (event is TransactionTimedOut) {
              timeoutEvent = event;
            }
          },
        ));

        await tx.begin([cell]);
        await delay(100);

        expect(timeoutEvent, isNotNull);
        expect(timeoutEvent!.timeout, Duration(milliseconds: 50));

        await expectLater(
          tx.commit(),
          throwsA(isA<TransactionTimeoutException>()),
        );
        expect(cell.value, 0);
      });
    });

    group('Events', () {
      test('TransactionBegun event emitted', () async {
        TransactionBegun? begunEvent;
        final accounts = createAccountPair();

        final tx = Cell.transaction(TransactionOptions(
          onEvent: (event) {
            if (event is TransactionBegun) {
              begunEvent = event;
            }
          },
        ));

        await tx.begin([accounts.a, accounts.b]);

        expect(begunEvent, isNotNull);
        expect(begunEvent!.cells, [accounts.a, accounts.b]);
        expect(begunEvent!.isolation, IsolationLevel.readCommitted);

        await tx.rollback();
      });

      test('TransactionUpdated event emitted', () async {
        final updates = <TransactionUpdated>[];
        final accounts = createAccountPair();

        final tx = Cell.transaction(TransactionOptions(
          onEvent: (event) {
            if (event is TransactionUpdated) {
              updates.add(event);
            }
          },
        ));

        await tx.begin([accounts.a, accounts.b]);
        tx.update(accounts.a, 50);
        tx.update(accounts.b, 250);

        expect(updates, hasLength(2));
        expect(updates[0].cell, accounts.a);
        expect(updates[0].value, 50);
        expect(updates[1].cell, accounts.b);
        expect(updates[1].value, 250);

        await tx.commit();
        expect(accounts.a.value, 50);
        expect(accounts.b.value, 250);
      });

      test('TransactionCommitted event emitted', () async {
        TransactionCommitted? committedEvent;
        final accounts = createAccountPair();

        final tx = Cell.transaction(TransactionOptions(
          onEvent: (event) {
            if (event is TransactionCommitted) {
              committedEvent = event;
            }
          },
        ));

        await tx.begin([accounts.a, accounts.b]);
        tx.update(accounts.a, 50);
        tx.update(accounts.b, 250);
        await tx.commit();

        expect(committedEvent, isNotNull);
        expect(committedEvent!.changes, hasLength(2));
        expect(committedEvent!.changes[0].cell, accounts.a);
        expect(committedEvent!.changes[0].value, 50);
        expect(committedEvent!.changes[1].cell, accounts.b);
        expect(committedEvent!.changes[1].value, 250);
        expect(accounts.a.value, 50);
        expect(accounts.b.value, 250);
      });

      test('TransactionRolledBack event emitted', () async {
        TransactionRolledBack? rolledBackEvent;
        final accounts = createAccountPair();

        final tx = Cell.transaction(TransactionOptions(
          onEvent: (event) {
            if (event is TransactionRolledBack) {
              rolledBackEvent = event;
            }
          },
        ));

        await tx.begin([accounts.a, accounts.b]);
        tx.update(accounts.a, 50);
        tx.update(accounts.b, 250);
        await tx.rollback();

        expect(rolledBackEvent, isNotNull);
        expect(rolledBackEvent!.savepoint, isNull);
        expect(accounts.a.value, 100);
        expect(accounts.b.value, 200);
      });

      test('TransactionRolledBack with savepoint event emitted', () async {
        TransactionRolledBack? rolledBackEvent;
        final accounts = createAccountPair();

        final tx = Cell.transaction(TransactionOptions(
          onEvent: (event) {
            if (event is TransactionRolledBack) {
              rolledBackEvent = event;
            }
          },
        ));

        await tx.begin([accounts.a, accounts.b]);
        tx.update(accounts.a, 50);
        final sp = tx.savepoint();
        tx.update(accounts.b, 250);
        await tx.rollback(savepoint: sp);

        expect(rolledBackEvent, isNotNull);
        expect(rolledBackEvent!.savepoint, sp);
        expect(tx.pending(accounts.a), 50);
        expect(tx.pending(accounts.b), isNot(250));

        await tx.commit();
        expect(accounts.a.value, 50);
        expect(accounts.b.value, 200);
      });
    });

    group('Cell Types', () {
      test('transaction with ValueCell', () async {
        final cell = TrackedValueCell<int>(initial: 42);
        final tx = Cell.transaction();

        await tx.begin([cell]);
        tx.update(cell, 100);
        await tx.commit();

        expect(cell.value, 100);
        expect(cell.updateCount, 1);
      });

      test('transaction with non-ValueCell (CellBase)', () async {
        final cell = RecordingCell();
        final tx = Cell.transaction();

        await tx.begin([cell]);
        tx.update(cell, 42);
        expect(cell.receivedPayloads, isEmpty);
        await tx.commit();

        expect(cell.receivedPayloads, [42]);
        expect(cell.receivedPulses, hasLength(1));
      });

      test('pending reads see buffered writes', () async {
        final cell = TrackedValueCell<int>(initial: 0);
        final tx = Cell.transaction();

        await tx.begin([cell]);
        tx.update(cell, 100);

        expect(tx.pending(cell), 100);
        expect(tx.read(cell), 0);
        expect(cell.value, 0);

        await tx.commit();
        expect(cell.value, 100);
      });

      test('pending falls back to read', () async {
        final cell = TrackedValueCell<int>(initial: 42);
        final tx = Cell.transaction();

        await tx.begin([cell]);

        expect(tx.pending(cell), 42);
        expect(tx.read(cell), 42);

        await tx.commit();
        expect(cell.value, 42);
        expect(cell.updateCount, 0);
      });
    });

    group('Real-World Scenarios', () {
      test('bank transfer with validation to prevent negative', () async {
        final from = ValidatingCell<int>(initial: 100);
        final to = ValidatingCell<int>(initial: 50);
        final tx = Cell.transaction();

        await tx.begin([from, to]);

        final fromBalance = tx.read(from) as int;
        const amount = 150;

        tx.update(from, fromBalance - amount);
        tx.update(to, (tx.read(to) as int) + amount);

        await expectLater(
          tx.commit(),
          throwsA(isValidationException(value: -50)),
        );
        expect(from.value, 100);
        expect(to.value, 50);
      });

      test('bank transfer commits when balances stay non-negative', () async {
        final from = ValidatingCell<int>(initial: 100);
        final to = ValidatingCell<int>(initial: 50);
        final tx = Cell.transaction();

        await tx.begin([from, to]);
        tx.update(from, 60);
        tx.update(to, 90);
        await tx.commit();

        expect(from.value, 60);
        expect(to.value, 90);
      });

      test('multi-step operation with savepoint', () async {
        final step1 = TrackedValueCell<int>(initial: 0);
        final step2 = TrackedValueCell<int>(initial: 0);
        final step3 = TrackedValueCell<int>(initial: 0);
        final tx = Cell.transaction();

        await tx.begin([step1, step2, step3]);

        tx.update(step1, 10);
        tx.savepoint();

        tx.update(step2, 20);
        final sp2 = tx.savepoint();

        tx.update(step3, 30);

        await tx.rollback(savepoint: sp2);
        expect(tx.pending(step1), 10);
        expect(tx.pending(step2), 20);
        expect(tx.pending(step3), 0);

        await tx.commit();

        expect(step1.value, 10);
        expect(step2.value, 20);
        expect(step3.value, 0);
      });

      test('concurrent transactions isolation', () async {
        final accounts = createAccountPair();

        final tx1 = Cell.transaction(TransactionOptions(
          isolation: IsolationLevel.repeatableRead,
        ));
        final tx2 = Cell.transaction();

        await tx1.begin([accounts.a, accounts.b]);
        final balanceA = tx1.read(accounts.a) as int;

        await tx2.begin([accounts.a]);
        tx2.update(accounts.a, 200);
        await tx2.commit();
        expect(accounts.a.value, 200);

        tx1.update(accounts.a, balanceA + 50);

        await expectLater(
          tx1.commit(),
          throwsA(isA<TransactionConflictException>()),
        );
        expect(accounts.a.value, 200);
        expect(accounts.b.value, 200);
      });
    });

    group('Edge Cases & Error Handling', () {
      test('updating same cell multiple times uses last value', () async {
        final cell = TrackedValueCell<int>(initial: 0);
        final tx = Cell.transaction();

        await tx.begin([cell]);
        tx.update(cell, 10);
        tx.update(cell, 20);
        tx.update(cell, 30);
        expect(tx.pending(cell), 30);
        expect(cell.value, 0);

        await tx.commit();

        expect(cell.value, 30);
        expect(cell.updateCount, 3, reason: 'each buffered write is applied in order');
      });

      test('rollback when no transaction active is no-op', () async {
        final tx = Cell.transaction();
        await tx.rollback();
        await tx.rollback();
      });

      test('commit when no transaction active throws', () async {
        final tx = Cell.transaction();
        await expectLater(tx.commit(), throwsA(isA<StateError>()));
      });

      test('transaction with options and all callbacks', () async {
        final events = <TransactionEvent>[];
        final cell = TrackedValueCell<int>(initial: 0);

        final tx = Cell.transaction(TransactionOptions(
          isolation: IsolationLevel.repeatableRead,
          ordering: LockOrdering.byHashCode,
          timeout: Duration(seconds: 5),
          validate: (cell, value) => value is int && value >= 0,
          onEvent: events.add,
        ));

        await tx.begin([cell]);
        tx.update(cell, 42);
        await tx.commit();

        expect(events, hasLength(3));
        expect(events[0], isA<TransactionBegun>());
        expect(events[1], isA<TransactionUpdated>());
        expect(events[2], isA<TransactionCommitted>());
        expect(cell.value, 42);
      });

      test('transaction with null values', () async {
        final cell = TrackedValueCell<int?>(initial: null);
        final tx = Cell.transaction();

        await tx.begin([cell]);
        expect(tx.read(cell), isNull);
        tx.update(cell, 5);
        await tx.commit();
        expect(cell.value, 5);

        final tx2 = Cell.transaction();
        await tx2.begin([cell]);
        tx2.update(cell, null);
        await tx2.commit();
        expect(cell.value, isNull);
      });

      test('transaction with non-int values', () async {
        final cell = TrackedValueCell<String>(initial: 'hello');
        final tx = Cell.transaction();

        await tx.begin([cell]);
        expect(tx.read(cell), 'hello');
        tx.update(cell, 'world');
        expect(cell.value, 'hello');
        await tx.commit();

        expect(cell.value, 'world');
      });
    });

    group('Exception toString', () {
      test('TransactionValidationException toString', () {
        final failures = [
          ValidationFailure(
            cell: TrackedValueCell<int>(initial: 0),
            value: -5,
            reason: 'Negative value not allowed',
          ),
        ];
        final exception = TransactionValidationException(failures);
        final str = exception.toString();
        expect(str, contains('TransactionValidationException'));
        expect(str, contains('Negative value not allowed'));
        expect(str, contains('1 failure'));
      });

      test('TransactionConflictException toString', () {
        final conflicts = [
          ValidationFailure(
            cell: TrackedValueCell<int>(initial: 0),
            value: 50,
            reason: 'Cell changed since begin',
          ),
        ];
        final exception = TransactionConflictException(conflicts);
        final str = exception.toString();
        expect(str, contains('TransactionConflictException'));
        expect(str, contains('Cell changed since begin'));
        expect(str, contains('1 conflict'));
      });

      test('TransactionTimeoutException toString', () {
        final exception = TransactionTimeoutException(Duration(seconds: 5));
        final str = exception.toString();
        expect(str, contains('TransactionTimeoutException'));
        expect(str, contains('5'));
      });
    });
  });
}
