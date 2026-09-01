// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'package:test/test.dart';
import 'package:cell/cell.dart';

Cell hostCell(EphemeralPolicy policy) => Cell.governed(
      ephemeralPolicy: policy,
      context: Context.system,
    );

void main() {
  group('EphemeralPolicy', () {
    group('Construction', () {
      test('stores duration and leaves eventLimit unset', () {
        final policy = EphemeralPolicy(
          duration: Duration(seconds: 5),
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: 0),
          onInvalidate: (nucleus) => true,
        );
        expect(policy.duration, Duration(seconds: 5));
        expect(policy.eventLimit, isNull);
        expect(policy.events, 0);
        expect(policy.isInvalidated, isFalse);
      });

      test('stores eventLimit and leaves duration unset', () {
        final policy = EphemeralPolicy(
          eventLimit: 10,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) => true,
        );
        expect(policy.eventLimit, 10);
        expect(policy.duration, isNull);
        expect(policy.events, 0);
      });

      test('stores duration and eventLimit together', () {
        final policy = EphemeralPolicy(
          duration: Duration(minutes: 1),
          eventLimit: 50,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: 0),
          onInvalidate: (nucleus) => true,
        );
        expect(policy.duration, Duration(minutes: 1));
        expect(policy.eventLimit, 50);
      });

      test('allows a tracking-only policy with no TTL or quota', () {
        final policy = EphemeralPolicy(
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) => true,
        );
        expect(policy.duration, isNull);
        expect(policy.eventLimit, isNull);
        expect(policy.isInvalidated, isFalse);
      });

      test('stores user metadata for onEvent', () {
        dynamic seenUser;
        final policy = EphemeralPolicy(
          user: {'retry_count': 3, 'timeout': 500},
          onEvent: (object, {required cell, required policy, arguments, user}) {
            seenUser = user;
            return (events: 0);
          },
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy('hit', cell: cell);
        expect(seenUser, {'retry_count': 3, 'timeout': 500});
      });

      test('omitted user is null in onEvent', () {
        dynamic seenUser = 'unset';
        final policy = EphemeralPolicy(
          onEvent: (object, {required cell, required policy, arguments, user}) {
            seenUser = user;
            return (events: 0);
          },
          onInvalidate: (nucleus) => true,
        );
        policy('hit', cell: hostCell(policy));
        expect(seenUser, isNull);
      });
    });

    group('call / events', () {
      test('forwards the interaction object to onEvent', () {
        final seen = <dynamic>[];
        final policy = EphemeralPolicy(
          onEvent: (object, {required cell, required policy, arguments, user}) {
            seen.add(object);
            return (events: seen.length);
          },
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy(42, cell: cell);
        policy('link', cell: cell);
        final pulse = Pulse<int>(1);
        policy(pulse, cell: cell);
        expect(seen, [42, 'link', pulse]);
        expect(policy.events, 3);
      });

      test('forwards the host cell to onEvent', () {
        Cell? seenCell;
        final policy = EphemeralPolicy(
          onEvent: (object, {required cell, required policy, arguments, user}) {
            seenCell = cell as Cell;
            return (events: 0);
          },
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy('hit', cell: cell);
        expect(seenCell, same(cell));
      });

      test('forwards call arguments to onEvent', () {
        dynamic seenArgs;
        final policy = EphemeralPolicy(
          onEvent: (object, {required cell, required policy, arguments, user}) {
            seenArgs = arguments;
            return (events: 0);
          },
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy('action', cell: cell, arguments: {'op': 'apply'});
        expect(seenArgs, {'op': 'apply'});
      });

      test('updates the events counter from onEvent', () {
        final policy = EphemeralPolicy(
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 2),
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy('a', cell: cell);
        expect(policy.events, 2);
        policy('b', cell: cell);
        expect(policy.events, 4);
      });

      test('ignores an event when onEvent returns a negative count', () {
        final policy = EphemeralPolicy(
          eventLimit: 10,
          onEvent: (object, {required cell, required policy, arguments, user}) {
            if (object == 'skip') return (events: -1);
            return (events: policy.events + 1);
          },
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy('keep', cell: cell);
        expect(policy.events, 1);
        policy('skip', cell: cell);
        expect(policy.events, 1);
        expect(policy.isInvalidated, isFalse);
      });

      test('returning zero is a counted event and stores 0', () {
        final policy = EphemeralPolicy(
          eventLimit: 5,
          onEvent: (object, {required cell, required policy, arguments, user}) {
            if (object == 'reset') return (events: 0);
            return (events: policy.events + 1);
          },
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy(1, cell: cell);
        policy(2, cell: cell);
        expect(policy.events, 2);
        policy('reset', cell: cell);
        expect(policy.events, 0);
        expect(policy.isInvalidated, isFalse);
      });

      test('does not invoke onEvent after the cell is reclaimed', () {
        var calls = 0;
        final policy = EphemeralPolicy(
          eventLimit: 1,
          onEvent: (object, {required cell, required policy, arguments, user}) {
            calls++;
            return (events: policy.events + 1);
          },
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy('first', cell: cell);
        expect(policy.isInvalidated, isTrue);
        expect(calls, 1);
        policy('second', cell: cell);
        expect(calls, 1);
        expect(policy.events, 1);
      });
    });

    group('eventLimit', () {
      test('does not reclaim below the threshold', () {
        final policy = EphemeralPolicy(
          eventLimit: 3,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy(1, cell: cell);
        policy(2, cell: cell);
        expect(policy.events, 2);
        expect(policy.isInvalidated, isFalse);
      });

      test('reclaims when the counter reaches the limit', () {
        Nucleus? seenNucleus;
        var invalidateCalls = 0;
        final policy = EphemeralPolicy(
          eventLimit: 3,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) {
            invalidateCalls++;
            seenNucleus = nucleus;
            return true;
          },
        );
        final cell = hostCell(policy);
        policy(1, cell: cell);
        policy(2, cell: cell);
        policy(3, cell: cell);
        expect(policy.events, 3);
        expect(invalidateCalls, 1);
        expect(policy.isInvalidated, isTrue);
        expect(cell.isInvalidated, isTrue);
        expect(seenNucleus, isNotNull);
        expect(seenNucleus!.isInvalidated, isTrue);
      });

      test('reclaims on the first counted event when eventLimit is 1', () {
        final policy = EphemeralPolicy(
          eventLimit: 1,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: 1),
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy('once', cell: cell);
        expect(policy.isInvalidated, isTrue);
      });

      test('resetting the counter avoids the quota', () {
        final policy = EphemeralPolicy(
          eventLimit: 3,
          onEvent: (object, {required cell, required policy, arguments, user}) {
            if (object == 'reset') return (events: 0);
            return (events: policy.events + 1);
          },
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy(1, cell: cell);
        policy(2, cell: cell);
        policy('reset', cell: cell);
        policy(3, cell: cell);
        expect(policy.events, 1);
        expect(policy.isInvalidated, isFalse);
      });

      test('failed onInvalidate leaves the cell alive for a later retry', () {
        var attempts = 0;
        final policy = EphemeralPolicy(
          eventLimit: 1,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) {
            attempts++;
            return attempts >= 2;
          },
        );
        final cell = hostCell(policy);
        policy('first', cell: cell);
        expect(policy.isInvalidated, isFalse);
        expect(attempts, 1);
        policy('retry', cell: cell);
        expect(policy.isInvalidated, isTrue);
        expect(attempts, 2);
      });

      test('without an eventLimit the counter never reclaims', () {
        final policy = EphemeralPolicy(
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        for (var i = 0; i < 20; i++) {
          policy(i, cell: cell);
        }
        expect(policy.events, 20);
        expect(policy.isInvalidated, isFalse);
      });
    });

    group('TTL', () {
      test('does not start the timer until the first interaction', () async {
        var invalidated = false;
        final policy = EphemeralPolicy(
          duration: Duration(milliseconds: 30),
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: 0),
          onInvalidate: (nucleus) {
            invalidated = true;
            return true;
          },
        );
        final cell = hostCell(policy);
        await Future<void>.delayed(Duration(milliseconds: 40));
        expect(invalidated, isFalse);
        expect(policy.isInvalidated, isFalse);
        expect(cell.isInvalidated, isFalse);
      });

      test('reclaims after duration from the first interaction', () async {
        final policy = EphemeralPolicy(
          duration: Duration(milliseconds: 30),
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: 0),
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy('start', cell: cell);
        expect(policy.isInvalidated, isFalse);
        await Future<void>.delayed(Duration(milliseconds: 80));
        expect(policy.isInvalidated, isTrue);
        expect(cell.isInvalidated, isTrue);
      });

      test('does not restart the TTL on later interactions', () async {
        final policy = EphemeralPolicy(
          duration: Duration(milliseconds: 40),
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: 0),
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy('start', cell: cell);
        await Future<void>.delayed(Duration(milliseconds: 20));
        policy('again', cell: cell);
        await Future<void>.delayed(Duration(milliseconds: 40));
        expect(policy.isInvalidated, isTrue);
      });

      test('dispose cancels a pending TTL', () async {
        final policy = EphemeralPolicy(
          duration: Duration(milliseconds: 30),
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: 0),
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy('start', cell: cell);
        policy.dispose();
        await Future<void>.delayed(Duration(milliseconds: 80));
        expect(policy.isInvalidated, isFalse);
        expect(cell.isInvalidated, isFalse);
      });

      test('TTL is a no-op if the cell was already reclaimed', () async {
        var invalidations = 0;
        final policy = EphemeralPolicy(
          duration: Duration(milliseconds: 30),
          eventLimit: 1,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) {
            invalidations++;
            return true;
          },
        );
        final cell = hostCell(policy);
        policy('quota', cell: cell);
        expect(policy.isInvalidated, isTrue);
        expect(cell.isInvalidated, isTrue);
        expect(invalidations, 1);
        await Future<void>.delayed(Duration(milliseconds: 80));
        expect(invalidations, 1);
      });
    });

    group('combined TTL and eventLimit', () {
      test('event quota can reclaim before the TTL', () async {
        final policy = EphemeralPolicy(
          duration: Duration(milliseconds: 80),
          eventLimit: 2,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy(1, cell: cell);
        policy(2, cell: cell);
        expect(policy.isInvalidated, isTrue);
        expect(cell.isInvalidated, isTrue);
      });

      test('TTL can reclaim before the event quota', () async {
        final policy = EphemeralPolicy(
          duration: Duration(milliseconds: 30),
          eventLimit: 50,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        policy(1, cell: cell);
        expect(policy.isInvalidated, isFalse);
        await Future<void>.delayed(Duration(milliseconds: 80));
        expect(policy.isInvalidated, isTrue);
        expect(cell.isInvalidated, isTrue);
        expect(policy.events, 1);
      });
    });

    group('mask', () {
      ({int events}) onEvent(dynamic object,
              {required Cell cell,
              required EphemeralPolicy policy,
              dynamic arguments,
              dynamic user}) =>
          (events: 0);

      bool onInvalidate(Nucleus nucleus) => true;

      test('bit 0: callbacks only', () {
        final record = EphemeralPolicy.mask(
          onEvent: onEvent,
          onInvalidate: onInvalidate,
        ) as dynamic;
        expect(record.onEvent, same(onEvent));
        expect(record.onInvalidate, same(onInvalidate));
      });

      test('bit 1: eventLimit', () {
        final record = EphemeralPolicy.mask(
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          eventLimit: 7,
        ) as dynamic;
        expect(record.eventLimit, 7);
      });

      test('bit 2: duration', () {
        final record = EphemeralPolicy.mask(
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          duration: Duration(seconds: 2),
        ) as dynamic;
        expect(record.duration, Duration(seconds: 2));
      });

      test('bit 3: eventLimit and duration', () {
        final record = EphemeralPolicy.mask(
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          eventLimit: 4,
          duration: Duration(milliseconds: 9),
        ) as dynamic;
        expect(record.eventLimit, 4);
        expect(record.duration, Duration(milliseconds: 9));
      });

      test('bit 4: user', () {
        final record = EphemeralPolicy.mask(
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          user: 'tag',
        ) as dynamic;
        expect(record.user, 'tag');
      });

      test('bit 5: eventLimit and user', () {
        final record = EphemeralPolicy.mask(
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          eventLimit: 1,
          user: 42,
        ) as dynamic;
        expect(record.eventLimit, 1);
        expect(record.user, 42);
      });

      test('bit 6: duration and user', () {
        final record = EphemeralPolicy.mask(
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          duration: Duration(hours: 1),
          user: {'k': 'v'},
        ) as dynamic;
        expect(record.duration, Duration(hours: 1));
        expect(record.user, {'k': 'v'});
      });

      test('bit 7: eventLimit, duration, and user', () {
        final record = EphemeralPolicy.mask(
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          eventLimit: 8,
          duration: Duration(seconds: 3),
          user: true,
        ) as dynamic;
        expect(record.eventLimit, 8);
        expect(record.duration, Duration(seconds: 3));
        expect(record.user, isTrue);
      });
    });

    group('cell integration', () {
      test('an unused hosted policy does not invalidate the cell', () {
        final policy = EphemeralPolicy(
          eventLimit: 1,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: 1),
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        expect(cell.isInvalidated, isFalse);
        expect(policy.isInvalidated, isFalse);
      });

      test('Cell and Nucleus follow a hosted policy after reclamation', () {
        final policy = EphemeralPolicy(
          eventLimit: 1,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) => true,
        );
        final nucleus = Nucleus(ephemeralPolicy: policy, forceLock: false);
        expect(nucleus.isInvalidated, isFalse);
        final cell = Cell.fromNucleus(nucleus);
        policy('quota', cell: cell);
        expect(policy.isInvalidated, isTrue);
        expect(nucleus.isInvalidated, isTrue);
        expect(cell.isInvalidated, isTrue);
      });

      test('a deputy without its own policy follows the principal', () async {
        final policy = EphemeralPolicy(
          eventLimit: 1,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) => true,
        );
        final cell = hostCell(policy);
        final deputy = await cell.deputy(
          testRule: TestCell((object, {host, arguments, user}) => true),
        );
        expect(deputy.isInvalidated, isFalse);
        policy('quota', cell: cell);
        expect(cell.isInvalidated, isTrue);
        expect(deputy.isInvalidated, isTrue);
      });

      test('two policies keep independent event counters', () {
        final a = EphemeralPolicy(
          eventLimit: 10,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) => true,
        );
        final b = EphemeralPolicy(
          eventLimit: 10,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) => true,
        );
        final cellA = hostCell(a);
        final cellB = hostCell(b);
        a('x', cell: cellA);
        a('x', cell: cellA);
        b('y', cell: cellB);
        expect(a.events, 2);
        expect(b.events, 1);
      });
    });
  });
}
