// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'package:test/test.dart';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// Fixtures
//
// [Synapses.call] delivers to [downstreams] whose receptors are activated
// (a RecordingCell constructed with a receptor). [Synapses.link] only
// succeeds when [cell]'s nucleus holds this same synapses instance.
// ─────────────────────────────────────────────────────────────────────────

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

Future<void> delay(int milliseconds) =>
    Future.delayed(Duration(milliseconds: milliseconds));

void main() {
  group('Synapses', () {
    group('disabled', () {
      test('is a reusable singleton', () {
        expect(identical(Synapses.disabled, Synapses.disabled), isTrue);
      });

      test('call is a no-op', () {
        Synapses.disabled.call(Pulse<int>(1) as PulseBase);
      });

      test('link and unlink return false', () {
        final host = Cell();
        final observer = RecordingCell();
        expect(
          Synapses.disabled.link(host, downstreamCell: observer),
          isFalse,
        );
        expect(
          Synapses.disabled.unlink(host, downstreamCell: observer),
          isFalse,
        );
      });

      test('is an empty iterable', () {
        expect(Synapses.disabled, isEmpty);
        expect(Synapses.disabled.length, 0);
      });

      test('async is unsupported', () {
        expect(() => Synapses.disabled.async, throwsUnsupportedError);
      });

      test('Cell with disabled synapses is terminal', () {
        final cell = Cell(synapses: Synapses.disabled);
        expect(cell.isTerminal, isTrue);
      });
    });

    group('enabled', () {
      test('is a reusable singleton flyweight', () {
        expect(identical(Synapses.enabled, Synapses.enabled), isTrue);
      });

      test('link and unlink return false on the flyweight', () {
        final host = Cell();
        final observer = RecordingCell();
        expect(
          Synapses.enabled.link(host, downstreamCell: observer),
          isFalse,
        );
        expect(
          Synapses.enabled.unlink(host, downstreamCell: observer),
          isFalse,
        );
      });

      test('is an empty iterable', () {
        expect(Synapses.enabled, isEmpty);
      });

      test('async is unsupported on the flyweight', () {
        expect(() => Synapses.enabled.async, throwsUnsupportedError);
      });

      test('Cell with default synapses is not terminal', () {
        expect(Cell().isTerminal, isFalse);
      });
    });

    group('Construction & broadcast', () {
      test('empty synapses complete a pulse without observers', () {
        final synapses = Synapses();
        expect(synapses, isEmpty);
        synapses.call(Pulse<int>(1));
      });

      test('constructor registers initial downstreams', () {
        final a = RecordingCell();
        final b = RecordingCell();
        final synapses = Synapses(downstreams: [a, b]);
        expect(synapses.length, 2);
        expect(synapses.contains(a), isTrue);
        expect(synapses.contains(b), isTrue);
      });

      test('call delivers to every downstream in order', () {
        final a = RecordingCell();
        final b = RecordingCell();
        final synapses = Synapses(downstreams: [a, b]);

        synapses.call(Pulse<int>(7));

        expect(a.receivedPayloads, [7]);
        expect(b.receivedPayloads, [7]);
      });

      test('call delivers successive pulses in order', () {
        final recorder = RecordingCell();
        final synapses = Synapses(downstreams: [recorder]);

        synapses.call(Pulse<int>(1));
        synapses.call(Pulse<int>(2));
        synapses.call(Pulse<int>(3));

        expect(recorder.receivedPayloads, [1, 2, 3]);
      });

      test('cycle checker skips a downstream already visited by the pulse', () {
        final recorder = RecordingCell();
        final synapses = Synapses(downstreams: [recorder]);
        final pulse = Pulse<int>(1);

        synapses.call(pulse);
        synapses.call(pulse);

        expect(recorder.receivedPulses.length, 1);
      });

      test('empty synapses still complete a governed pulse with onComplete', () {
        var completed = false;
        final synapses = Synapses();
        final pulse = Pulse<int>.governed(
          payload: 1,
          onComplete: (p) {
            completed = true;
          },
        );
        synapses.call(pulse);
        expect(completed, isTrue);
      });
    });

    group('link / unlink', () {
      test('link adds an observer when the synapses belong to the host', () {
        final synapses = Synapses();
        final host = Cell(synapses: synapses);
        final observer = RecordingCell();

        expect(synapses.link(host, downstreamCell: observer), isTrue);
        expect(synapses.contains(observer), isTrue);

        synapses.call(Pulse<int>(9));
        expect(observer.receivedPayloads, [9]);
      });

      test('link returns false when the synapses are not the host\'s', () {
        final synapses = Synapses();
        final other = Cell();
        final observer = RecordingCell();

        expect(synapses.link(other, downstreamCell: observer), isFalse);
        expect(synapses.contains(observer), isFalse);
      });

      test('duplicate link returns false', () {
        final synapses = Synapses();
        final host = Cell(synapses: synapses);
        final observer = RecordingCell();

        expect(synapses.link(host, downstreamCell: observer), isTrue);
        expect(synapses.link(host, downstreamCell: observer), isFalse);
        expect(synapses.length, 1);
      });

      test('unlink removes an observer', () {
        final observer = RecordingCell();
        final synapses = Synapses(downstreams: [observer]);
        final host = Cell(synapses: synapses);

        expect(synapses.unlink(host, downstreamCell: observer), isTrue);
        expect(synapses.contains(observer), isFalse);

        synapses.call(Pulse<int>(1));
        expect(observer.receivedPulses, isEmpty);
      });

      test('unlink of a missing observer returns false', () {
        final synapses = Synapses();
        final host = Cell(synapses: synapses);
        expect(
          synapses.unlink(host, downstreamCell: RecordingCell()),
          isFalse,
        );
      });

      test('link is rejected when the host testRule denies the observer', () {
        final synapses = Synapses();
        final host = Cell(
          synapses: synapses,
          testRule: TestCell((object, {host, arguments, user}) => false),
        );
        final observer = RecordingCell();

        expect(synapses.link(host, downstreamCell: observer), isFalse);
        expect(synapses.contains(observer), isFalse);
      });

      test('async testRule Future is awaited on link', () async {
        final synapses = Synapses();
        final allow = Cell(
          synapses: synapses,
          testRule: TestCell((object, {host, arguments, user}) async {
            await Future<void>.delayed(Duration.zero);
            return true;
          }),
        );
        final denySynapses = Synapses();
        final deny = Cell(
          synapses: denySynapses,
          testRule: TestCell((object, {host, arguments, user}) async {
            await Future<void>.delayed(Duration.zero);
            return false;
          }),
        );
        final observer = RecordingCell();
        expect(
          await synapses.link(allow, downstreamCell: observer),
          isTrue,
        );
        expect(
          await denySynapses.link(deny, downstreamCell: observer),
          isFalse,
        );
      });
    });

    group('FilterRule', () {
      test('filter transforms the outgoing payload', () {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          filter: FilterRule<Pulse>((pulse, {user}) {
            return Pulse((pulse.payload as int) * 2);
          }),
        );

        synapses.call(Pulse<int>(21));
        expect(recorder.receivedPayloads, [42]);
      });

      test('filter returning null drops the pulse', () {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          filter: FilterRule<Pulse>((pulse, {user}) {
            final value = pulse.payload as int;
            return value > 0 ? pulse : null;
          }),
        );

        synapses.call(Pulse<int>(5));
        synapses.call(Pulse<int>(-1));
        expect(recorder.receivedPayloads, [5]);
      });

      test('+ chains filters sequentially', () {
        final recorder = RecordingCell();
        final doubleIt = FilterRule<Pulse>((pulse, {user}) {
          return Pulse((pulse.payload as int) * 2);
        });
        final addTen = FilterRule<Pulse>((pulse, {user}) {
          return Pulse((pulse.payload as int) + 10);
        });
        final synapses = Synapses(
          downstreams: [recorder],
          filter: doubleIt + addTen,
        );

        synapses.call(Pulse<int>(5));
        expect(recorder.receivedPayloads, [20]);
      });

      test('FilterRule.chain stops when a stage returns null', () {
        var ranSecond = false;
        final drop = FilterRule<Pulse>((pulse, {user}) => null);
        final second = FilterRule<Pulse>((pulse, {user}) {
          ranSecond = true;
          return pulse;
        });
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          filter: FilterRule.chain([drop, second]),
        );

        synapses.call(Pulse<int>(1));
        expect(recorder.receivedPulses, isEmpty);
        expect(ranSecond, isFalse);
      });

      test('FilterRule.base is an identity', () {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          filter: FilterRule.base(),
        );

        synapses.call(Pulse<int>(3));
        expect(recorder.receivedPayloads, [3]);
      });

      test('a throwing filter leaves the original pulse', () {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          filter: FilterRule<Pulse>((pulse, {user}) {
            throw StateError('bad filter');
          }),
        );

        synapses.call(Pulse<int>(4));
        expect(recorder.receivedPayloads, [4]);
      });

      test('FilterRule.user is passed to the rule', () {
        dynamic seenUser;
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          filter: FilterRule<Pulse>((pulse, {user}) {
            seenUser = user;
            return pulse;
          }, user: 'egress'),
        );

        synapses.call(Pulse<int>(1));
        expect(seenUser, 'egress');
      });

      test('parent runs after the primary rule', () {
        final recorder = RecordingCell();
        final parent = FilterRule<Pulse>((pulse, {user}) {
          return Pulse((pulse.payload as int) + 1);
        });
        final child = FilterRule<Pulse>((pulse, {user}) {
          return Pulse((pulse.payload as int) * 2);
        }, parent: parent);
        final synapses = Synapses(
          downstreams: [recorder],
          filter: child,
        );

        synapses.call(Pulse<int>(5));
        expect(recorder.receivedPayloads, [11]);
      });

      test('chain parent runs after the collected rules', () {
        final recorder = RecordingCell();
        final first = FilterRule<Pulse>((pulse, {user}) {
          return Pulse((pulse.payload as int) * 2);
        });
        final parent = FilterRule<Pulse>((pulse, {user}) {
          return Pulse((pulse.payload as int) + 1);
        });
        final synapses = Synapses(
          downstreams: [recorder],
          filter: FilterRule.chain([first], parent: parent),
        );

        synapses.call(Pulse<int>(5));
        expect(recorder.receivedPayloads, [11]);
      });

      test('chain strategy overrides sequential rules and still calls parent', () {
        dynamic seenUser;
        final recorder = RecordingCell();
        final skipped = FilterRule<Pulse>((pulse, {user}) {
          return Pulse(999);
        });
        final parent = FilterRule<Pulse>((pulse, {user}) {
          return Pulse((pulse.payload as int) + 1);
        });
        // strategy is typed bool Function; assigning its result to Pulse
        // throws and is swallowed, so the original pulse is kept for parent.
        final synapses = Synapses(
          downstreams: [recorder],
          filter: FilterRule.chain(
            [skipped],
            parent: parent,
            user: 'strategy-user',
            strategy: (pulse, {user}) {
              seenUser = user;
              return true;
            },
          ),
        );

        synapses.call(Pulse<int>(4));
        expect(seenUser, 'strategy-user');
        expect(recorder.receivedPayloads, [5]);
      });

      test('fromRecord reconstitutes a callable rule', () {
        Pulse? identity(Pulse pulse, {dynamic user}) => pulse;
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          filter: FilterRule<Pulse>.fromRecord((rule: identity,)),
        );

        synapses.call(Pulse<int>(9));
        expect(recorder.receivedPayloads, [9]);
      });

      test('equality and hashCode follow the flyweight record', () {
        final a = FilterRule.base();
        final b = FilterRule.base();
        expect(a, a);
        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a == 1, isFalse);
        expect(
          FilterRule<Pulse>((pulse, {user}) => pulse) ==
              FilterRule<Pulse>((pulse, {user}) => pulse),
          isFalse,
        );
      });
    });

    group('relay', () {
      test('relay replaces sequential broadcast', () {
        final recorder = RecordingCell();
        final relayed = <dynamic>[];
        final synapses = Synapses<Pulse, Cell>(
          downstreams: [recorder],
          relay: (pulse) {
            relayed.add(pulse.payload);
          },
        );

        synapses.call(Pulse<int>(8));
        expect(relayed, [8]);
        expect(recorder.receivedPulses, isEmpty);
      });

      test('relay is skipped when every downstream already saw the pulse', () {
        final recorder = RecordingCell();
        final pulse = Pulse<int>(1);
        Synapses(downstreams: [recorder]).call(pulse);

        final relayed = <dynamic>[];
        final withRelay = Synapses<Pulse, Cell>(
          downstreams: [recorder],
          relay: (p) {
            relayed.add(p.payload);
          },
        );
        withRelay.call(pulse);
        expect(relayed, isEmpty);
      });
    });

    group('PropagationPolicy', () {
      test('default strategy delivers immediately', () {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(),
        );

        synapses.call(Pulse<int>(1));
        expect(recorder.receivedPayloads, [1]);
      });

      test('async strategy delivers on a later event-loop turn', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(strategy: PropagationStrategy.async),
        );

        synapses.call(Pulse<int>(1));
        expect(recorder.receivedPulses, isEmpty);

        await delay(20);
        expect(recorder.receivedPayloads, [1]);
      });

      test('persistent replays the last pulse to a newly linked observer', () {
        final synapses = Synapses(
          policy: PropagationPolicy(strategy: PropagationStrategy.persistent),
        );
        final host = Cell(synapses: synapses);
        synapses.call(Pulse<int>(42));

        final late = RecordingCell();
        expect(synapses.link(host, downstreamCell: late), isTrue);
        expect(late.receivedPayloads, [42]);
      });

      test('persistent with an existing observer stores and delivers', () {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(strategy: PropagationStrategy.persistent),
        );
        synapses.call(Pulse<int>(7));
        expect(recorder.receivedPayloads, [7]);
      });
    });

    group('async view', () {
      test('async.call delivers to downstreams', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(downstreams: [recorder]);

        await synapses.async.call(Pulse<int>(11));
        await delay(20);
        expect(recorder.receivedPayloads, [11]);
      });

      test('async.call on empty synapses completes without observers', () async {
        final synapses = Synapses();
        await synapses.async.call(Pulse<int>(1));
      });

      test('async.call on empty synapses completes a governed onComplete pulse', () async {
        var completed = false;
        final synapses = Synapses();
        await synapses.async.call(Pulse<int>.governed(
          payload: 1,
          onComplete: (p) {
            completed = true;
          },
        ) as PulseBase);
        expect(completed, isTrue);
      });

      test('async.call applies the source filter', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          filter: FilterRule<Pulse>((pulse, {user}) {
            final value = pulse.payload as int;
            return value > 0 ? pulse : null;
          }),
        );
        await synapses.async.call(Pulse<int>(4));
        await synapses.async.call(Pulse<int>(-2));
        await delay(20);
        expect(recorder.receivedPayloads, [4]);
      });

      test('async.call respects a zero-duration debounce policy', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.debounced,
            debounceTime: Duration.zero,
          ),
        );
        await synapses.async.call(Pulse<int>(2));
        await delay(20);
        expect(recorder.receivedPayloads, [2]);
      });

      test('async.call respects a zero-duration throttle policy', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.throttled,
            throttleTime: Duration.zero,
          ),
        );
        await synapses.async.call(Pulse<int>(1));
        await synapses.async.call(Pulse<int>(2));
        await delay(20);
        expect(recorder.receivedPayloads, [1, 2]);
      });

      test('async.call batches until batchSize', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.batched,
            batchSize: 2,
          ),
        );
        await synapses.async.call(Pulse<int>(1));
        expect(recorder.receivedPulses, isEmpty);
        await synapses.async.call(Pulse<int>(2));
        await delay(20);
        expect(recorder.receivedPulses, isNotEmpty);
      });

      test('async.call with audit zero throttle delivers immediately', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.audit,
            throttleTime: Duration.zero,
          ),
        );
        await synapses.async.call(Pulse<int>(8));
        await delay(20);
        expect(recorder.receivedPayloads, [8]);
      });

      test('async.call with exhaust delivers', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(strategy: PropagationStrategy.exhaust),
        );
        await synapses.async.call(Pulse<int>(3));
        await delay(20);
        expect(recorder.receivedPayloads, [3]);
      });

      test('async.call with resilient delivers', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(strategy: PropagationStrategy.resilient),
        );
        await synapses.async.call(Pulse<int>(5));
        await delay(20);
        expect(recorder.receivedPayloads, [5]);
      });

      test('async.call with retry delivers', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.retry,
            throttleTime: Duration.zero,
          ),
        );
        await synapses.async.call(Pulse<int>(6));
        await delay(20);
        expect(recorder.receivedPayloads, [6]);
      });

      test('async.call with debounceLeading zero throttle delivers', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.debounceLeading,
            throttleTime: Duration.zero,
          ),
        );
        await synapses.async.call(Pulse<int>(1));
        await delay(20);
        expect(recorder.receivedPayloads, [1]);
      });

      test('async.call uses a custom relay', () async {
        final recorder = RecordingCell();
        final relayed = <dynamic>[];
        final synapses = Synapses<Pulse, Cell>(
          downstreams: [recorder],
          relay: (pulse) {
            relayed.add(pulse.payload);
          },
        );
        await synapses.async.call(Pulse<int>(7));
        await delay(20);
        expect(relayed, [7]);
        expect(recorder.receivedPulses, isEmpty);
      });

      test('async.call with async strategy delivers', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(strategy: PropagationStrategy.async),
        );
        await synapses.async.call(Pulse<int>(4));
        await delay(20);
        expect(recorder.receivedPayloads, [4]);
      });

      test('async.call with non-zero debounce delivers after the window', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.debounced,
            debounceTime: const Duration(milliseconds: 20),
          ),
        );
        await synapses.async.call(Pulse<int>(9));
        expect(recorder.receivedPulses, isEmpty);
        await delay(40);
        expect(recorder.receivedPayloads, [9]);
      });

      test('async.call with non-zero throttle delivers the leading pulse', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.throttled,
            throttleTime: const Duration(milliseconds: 40),
          ),
        );
        await synapses.async.call(Pulse<int>(1));
        await synapses.async.call(Pulse<int>(2));
        await delay(20);
        expect(recorder.receivedPayloads, [1]);
        await delay(40);
      });

      test('async.call with audit non-zero window delivers the latest', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.audit,
            throttleTime: const Duration(milliseconds: 20),
          ),
        );
        await synapses.async.call(Pulse<int>(1));
        await synapses.async.call(Pulse<int>(2));
        expect(recorder.receivedPulses, isEmpty);
        await delay(40);
        expect(recorder.receivedPayloads, [2]);
      });

      test('async.call buffered flushes on batchSize', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.buffered,
            throttleTime: const Duration(milliseconds: 200),
            batchSize: 2,
          ),
        );
        await synapses.async.call(Pulse<int>(1));
        expect(recorder.receivedPulses, isEmpty);
        await synapses.async.call(Pulse<int>(2));
        await delay(20);
        expect(recorder.receivedPulses, isNotEmpty);
      });

      test('async.call buffered flushes after throttleTime', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.buffered,
            throttleTime: const Duration(milliseconds: 20),
            batchSize: 10,
          ),
        );
        await synapses.async.call(Pulse<int>(5));
        expect(recorder.receivedPulses, isEmpty);
        await delay(40);
        expect(recorder.receivedPulses, isNotEmpty);
      });

      test('async.call debounceLeading non-zero throttle delivers the first pulse', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.debounceLeading,
            throttleTime: const Duration(milliseconds: 40),
          ),
        );
        await synapses.async.call(Pulse<int>(1));
        await synapses.async.call(Pulse<int>(2));
        await delay(20);
        expect(recorder.receivedPayloads, [1]);
        await delay(40);
      });

      test('async.call persistent delivers to current observers', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(strategy: PropagationStrategy.persistent),
        );
        await synapses.async.call(Pulse<int>(8));
        await delay(20);
        expect(recorder.receivedPayloads, [8]);
      });

      test('async.call on a revisited pulse does not re-notify', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(downstreams: [recorder]);
        final pulse = Pulse<int>(3);
        await synapses.async.call(pulse);
        await delay(20);
        await synapses.async.call(pulse);
        await delay(20);
        expect(recorder.receivedPulses.length, 1);
      });

      test('async relay is skipped when every downstream already saw the pulse', () async {
        final recorder = RecordingCell();
        final pulse = Pulse<int>(1);
        Synapses(downstreams: [recorder]).call(pulse);

        final relayed = <dynamic>[];
        final withRelay = Synapses<Pulse, Cell>(
          downstreams: [recorder],
          relay: (p) {
            relayed.add(p.payload);
          },
        );
        await withRelay.async.call(pulse);
        await delay(20);
        expect(relayed, isEmpty);
      });

      test('async resilient swallows a throwing relay', () async {
        final recorder = RecordingCell();
        final synapses = Synapses<Pulse, Cell>(
          downstreams: [recorder],
          policy: PropagationPolicy(strategy: PropagationStrategy.resilient),
          relay: (pulse) {
            throw StateError('async fail');
          },
        );
        await synapses.async.call(Pulse<int>(1));
        await delay(20);
        expect(recorder.receivedPulses, isEmpty);
      });

      test('async retry retries a throwing relay then gives up', () async {
        var attempts = 0;
        final recorder = RecordingCell();
        final synapses = Synapses<Pulse, Cell>(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.retry,
            throttleTime: Duration.zero,
            batchSize: 1,
          ),
          relay: (pulse) {
            attempts += 1;
            throw StateError('async always');
          },
        );
        await synapses.async.call(Pulse<int>(1));
        await delay(20);
        expect(attempts, greaterThanOrEqualTo(1));
        expect(recorder.receivedPulses, isEmpty);
      });

      test('async.call sample heartbeats the first pulse then stops when unlinked', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.sample,
            throttleTime: const Duration(milliseconds: 20),
          ),
        );
        final host = Cell(synapses: synapses);
        addTearDown(() {
          synapses.unlink(host, downstreamCell: recorder);
        });

        await synapses.async.call(Pulse<int>(1));
        await synapses.async.call(Pulse<int>(99));
        expect(recorder.receivedPulses, isEmpty);

        await delay(30);
        expect(recorder.receivedPayloads, [1]);
        final afterFirstTick = recorder.receivedPulses.length;

        await delay(45);
        expect(recorder.receivedPulses.length, afterFirstTick);
        expect(recorder.receivedPayloads.toSet(), {1});

        expect(synapses.unlink(host, downstreamCell: recorder), isTrue);
        await delay(45);
        expect(recorder.receivedPulses.length, afterFirstTick);
      });

      test('async debounce completes after observers are unlinked', () async {
        var completed = false;
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.debounced,
            debounceTime: const Duration(milliseconds: 20),
          ),
        );
        final host = Cell(synapses: synapses);
        final queued = synapses.async.call(Pulse<int>.governed(
          payload: 1,
          onComplete: (p) {
            completed = true;
          },
        ) as PulseBase);
        expect(synapses.unlink(host, downstreamCell: recorder), isTrue);
        await queued;
        await delay(40);
        expect(recorder.receivedPulses, isEmpty);
        expect(completed, isTrue);
      });
    });

    group('remaining strategies', () {
      test('exhaust delivers the pulse', () {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(strategy: PropagationStrategy.exhaust),
        );
        synapses.call(Pulse<int>(1));
        synapses.call(Pulse<int>(2));
        expect(recorder.receivedPayloads, [1, 2]);
      });

      test('resilient delivers when downstreams succeed', () {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(strategy: PropagationStrategy.resilient),
        );
        synapses.call(Pulse<int>(5));
        expect(recorder.receivedPayloads, [5]);
      });

      test('retry delivers when downstreams succeed', () {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.retry,
            throttleTime: Duration.zero,
            batchSize: 2,
          ),
        );
        synapses.call(Pulse<int>(6));
        expect(recorder.receivedPayloads, [6]);
      });

      test('debounceLeading with zero throttle delivers every pulse', () {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.debounceLeading,
            throttleTime: Duration.zero,
          ),
        );
        synapses.call(Pulse<int>(1));
        synapses.call(Pulse<int>(2));
        expect(recorder.receivedPayloads, [1, 2]);
      });

      test('buffered Duration.zero flushes on the first pulse', () {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.buffered,
            throttleTime: Duration.zero,
            batchSize: 10,
          ),
        );
        synapses.call(Pulse<int>(3));
        expect(recorder.receivedPulses, isNotEmpty);
      });

      test('resilient swallows a throwing relay', () {
        final recorder = RecordingCell();
        final synapses = Synapses<Pulse, Cell>(
          downstreams: [recorder],
          policy: PropagationPolicy(strategy: PropagationStrategy.resilient),
          relay: (pulse) {
            throw StateError('downstream failed');
          },
        );
        synapses.call(Pulse<int>(1));
        expect(recorder.receivedPulses, isEmpty);
      });

      test('retry retries a throwing relay then gives up', () async {
        var attempts = 0;
        final recorder = RecordingCell();
        final synapses = Synapses<Pulse, Cell>(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.retry,
            throttleTime: Duration.zero,
            batchSize: 1,
          ),
          relay: (pulse) {
            attempts += 1;
            throw StateError('always');
          },
        );
        synapses.call(Pulse<int>(1));
        await delay(20);
        expect(attempts, greaterThanOrEqualTo(1));
        expect(recorder.receivedPulses, isEmpty);
      });

      test('sample heartbeats then stops when unlinked', () async {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.sample,
            throttleTime: const Duration(milliseconds: 20),
          ),
        );
        final host = Cell(synapses: synapses);
        addTearDown(() {
          synapses.unlink(host, downstreamCell: recorder);
        });

        synapses.call(Pulse<int>(4));
        expect(recorder.receivedPulses, isEmpty);
        await delay(45);
        expect(recorder.receivedPayloads, isNotEmpty);
        expect(recorder.receivedPayloads.toSet(), {4});
        expect(synapses.unlink(host, downstreamCell: recorder), isTrue);
        await delay(45);
      });

      test('debounced pulse completes after observers are unlinked', () async {
        var completed = false;
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          policy: PropagationPolicy(
            strategy: PropagationStrategy.debounced,
            debounceTime: const Duration(milliseconds: 20),
          ),
        );
        final host = Cell(synapses: synapses);
        synapses.call(Pulse<int>.governed(
          payload: 1,
          onComplete: (p) {
            completed = true;
          },
        ));
        expect(synapses.unlink(host, downstreamCell: recorder), isTrue);
        await delay(40);
        expect(recorder.receivedPulses, isEmpty);
        expect(completed, isTrue);
      });
    });

    group('mask combinations and equality', () {
      test('filter plus relay plus policy is a valid synapses', () {
        final recorder = RecordingCell();
        final relayed = <dynamic>[];
        final synapses = Synapses(
          downstreams: [recorder],
          filter: FilterRule.base(),
          policy: PropagationPolicy(
            strategy: PropagationStrategy.debounced,
            debounceTime: Duration.zero,
          ),
          relay: (pulse) {
            relayed.add(pulse.payload);
          },
        );
        synapses.call(Pulse<int>(3));
        expect(relayed, [3]);
        expect(recorder.receivedPulses, isEmpty);
      });

      test('two synapses instances are not identical', () {
        final a = Synapses();
        final b = Synapses();
        expect(a == b, isFalse);
        expect(a.hashCode, isA<int>());
      });
    });

    group('Graph integration', () {
      test('host synapses broadcast a bound source emission', () {
        final recorder = RecordingCell();
        final synapses = Synapses(downstreams: [recorder]);
        final source = Cell.ingress<int>();
        Cell(
          bind: source.cell,
          synapses: synapses,
        );

        source.emit(6);
        expect(recorder.receivedPayloads, [6]);
      });

      test('filter on the host synapses redacts before observers', () {
        final recorder = RecordingCell();
        final synapses = Synapses(
          downstreams: [recorder],
          filter: FilterRule<Pulse>((pulse, {user}) {
            return Pulse('redacted');
          }),
        );
        final source = Cell.ingress<String>();
        Cell(
          bind: source.cell,
          synapses: synapses,
        );

        source.emit('secret');
        expect(recorder.receivedPayloads, ['redacted']);
      });
    });
  });
}
