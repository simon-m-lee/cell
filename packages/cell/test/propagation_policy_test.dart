// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'package:test/test.dart';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// Test Fixtures
// ─────────────────────────────────────────────────────────────────────────

/// A cell that records received pulses for verification.
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

/// Create a test setup with a recorder and synapses.
({RecordingCell recorder, Synapses synapses}) createTestSetup({
  PropagationPolicy? policy,
  FilterRule? filter,
}) {
  final recorder = RecordingCell();
  final synapses = Synapses(
    downstreams: [recorder],
    policy: policy,
    filter: filter,
  );
  return (recorder: recorder, synapses: synapses);
}

/// Send a pulse through synapses using the synapses' call method directly.
void sendPulse(Synapses synapses, Pulse pulse) {
  // The synapses' call method processes the pulse and delivers it to all
  // downstream observers that are linked to the synapses.
  // Since the recorder is in the downstreams list, it will receive the pulse.
  synapses.call(pulse);
}

/// Helper to create a policy with a specific strategy.
PropagationPolicy createPolicy({
  PropagationStrategy strategy = PropagationStrategy.immediate,
  Duration debounceTime = const Duration(milliseconds: 150),
  Duration throttleTime = const Duration(milliseconds: 200),
  int batchSize = 10,
}) {
  return PropagationPolicy(
    strategy: strategy,
    debounceTime: debounceTime,
    throttleTime: throttleTime,
    batchSize: batchSize,
  );
}

/// Helper to wait for async operations.
Future<void> delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

// ─────────────────────────────────────────────────────────────────────────
// PropagationPolicy Tests
// ─────────────────────────────────────────────────────────────────────────

void main() {
  group('PropagationPolicy', () {
    // ─────────────────────────────────────────────────────────────
    // Construction & Defaults
    // ─────────────────────────────────────────────────────────────

    group('Construction & Defaults', () {
      test('default constructor uses immediate strategy', () {
        final policy = PropagationPolicy();
        expect(policy.strategy, PropagationStrategy.immediate);
        expect(policy.debounceTime, const Duration(milliseconds: 150));
        expect(policy.throttleTime, const Duration(milliseconds: 200));
        expect(policy.batchSize, 10);
      });

      test('constructor sets strategy', () {
        final policy = PropagationPolicy(
          strategy: PropagationStrategy.debounced,
        );
        expect(policy.strategy, PropagationStrategy.debounced);
      });

      test('constructor sets debounceTime', () {
        final policy = PropagationPolicy(
          strategy: PropagationStrategy.debounced,
          debounceTime: const Duration(milliseconds: 300),
        );
        expect(policy.debounceTime, const Duration(milliseconds: 300));
      });

      test('constructor sets throttleTime', () {
        final policy = PropagationPolicy(
          strategy: PropagationStrategy.throttled,
          throttleTime: const Duration(milliseconds: 500),
        );
        expect(policy.throttleTime, const Duration(milliseconds: 500));
      });

      test('constructor sets batchSize', () {
        final policy = PropagationPolicy(
          strategy: PropagationStrategy.batched,
          batchSize: 25,
        );
        expect(policy.batchSize, 25);
      });

      test('constructor with all parameters', () {
        final policy = PropagationPolicy(
          strategy: PropagationStrategy.debounced,
          debounceTime: const Duration(milliseconds: 300),
          throttleTime: const Duration(milliseconds: 400),
          batchSize: 50,
        );
        expect(policy.strategy, PropagationStrategy.debounced);
        expect(policy.debounceTime, const Duration(milliseconds: 300));
        expect(policy.throttleTime, const Duration(milliseconds: 400));
        expect(policy.batchSize, 50);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Strategy Tests - Using synapses.call() directly
    // ─────────────────────────────────────────────────────────────

    group('Strategy: immediate', () {
      test('immediate delivers pulses synchronously', () {
        final setup = createTestSetup(
          policy: createPolicy(strategy: PropagationStrategy.immediate),
        );
        final pulse = Pulse<int>(42);

        // Send the pulse using synapses.call()
        sendPulse(setup.synapses, pulse);

        expect(setup.recorder.receivedPulses.length, 1);
        expect(setup.recorder.receivedPayloads.first, 42);
      });

      test('immediate delivers all pulses in order', () {
        final setup = createTestSetup(
          policy: createPolicy(strategy: PropagationStrategy.immediate),
        );

        sendPulse(setup.synapses, Pulse<int>(1));
        sendPulse(setup.synapses, Pulse<int>(2));
        sendPulse(setup.synapses, Pulse<int>(3));

        expect(setup.recorder.receivedPulses.length, 3);
        expect(setup.recorder.receivedPayloads, [1, 2, 3]);
      });
    });

    group('Strategy: debounced', () {
      test('debounced delays delivery until silence', () async {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.debounced,
            debounceTime: const Duration(milliseconds: 50),
          ),
        );

        sendPulse(setup.synapses, Pulse<int>(42));

        // Should not be delivered immediately
        expect(setup.recorder.receivedPulses.isEmpty, true);

        // Wait for debounce to complete
        await delay(60);

        expect(setup.recorder.receivedPulses.length, 1);
        expect(setup.recorder.receivedPayloads.first, 42);
      });

      test('debounced resets timer on each pulse', () async {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.debounced,
            debounceTime: const Duration(milliseconds: 50),
          ),
        );

        // Send multiple pulses within the debounce window
        sendPulse(setup.synapses, Pulse<int>(1));
        await delay(20);
        sendPulse(setup.synapses, Pulse<int>(2));
        await delay(20);
        sendPulse(setup.synapses, Pulse<int>(3));

        // No pulses should have been delivered yet
        expect(setup.recorder.receivedPulses.isEmpty, true);

        // Wait for debounce to complete after the last pulse
        await delay(60);

        // Only the last pulse should be delivered
        expect(setup.recorder.receivedPulses.length, 1);
        expect(setup.recorder.receivedPayloads.first, 3);
      });

      test('debounced with zero duration delivers immediately', () async {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.debounced,
            debounceTime: Duration.zero,
          ),
        );

        sendPulse(setup.synapses, Pulse<int>(42));

        expect(setup.recorder.receivedPulses.length, 1);
        expect(setup.recorder.receivedPayloads.first, 42);
      });
    });

    group('Strategy: throttled', () {
      test('throttled delivers first pulse immediately', () async {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.throttled,
            throttleTime: const Duration(milliseconds: 50),
          ),
        );

        sendPulse(setup.synapses, Pulse<int>(42));

        expect(setup.recorder.receivedPulses.length, 1);
        expect(setup.recorder.receivedPayloads.first, 42);
      });

      test('throttled suppresses subsequent pulses during window', () async {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.throttled,
            throttleTime: const Duration(milliseconds: 50),
          ),
        );

        sendPulse(setup.synapses, Pulse<int>(1));
        sendPulse(setup.synapses, Pulse<int>(2));
        sendPulse(setup.synapses, Pulse<int>(3));

        // Only first pulse should be delivered
        expect(setup.recorder.receivedPulses.length, 1);
        expect(setup.recorder.receivedPayloads.first, 1);

        // Wait for throttle to expire
        await delay(60);

        // Send another pulse
        sendPulse(setup.synapses, Pulse<int>(4));

        // Should be delivered
        expect(setup.recorder.receivedPulses.length, 2);
        expect(setup.recorder.receivedPayloads.last, 4);
      });

      test('throttled with zero duration delivers all pulses', () async {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.throttled,
            throttleTime: Duration.zero,
          ),
        );

        sendPulse(setup.synapses, Pulse<int>(1));
        sendPulse(setup.synapses, Pulse<int>(2));
        sendPulse(setup.synapses, Pulse<int>(3));

        expect(setup.recorder.receivedPulses.length, 3);
        expect(setup.recorder.receivedPayloads, [1, 2, 3]);
      });
    });

    group('Strategy: batched', () {
      test('batched accumulates pulses until batchSize', () async {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.batched,
            batchSize: 3,
          ),
        );

        // Send pulses below batch size
        sendPulse(setup.synapses, Pulse<int>(1));
        sendPulse(setup.synapses, Pulse<int>(2));

        // No delivery yet
        expect(setup.recorder.receivedPulses.isEmpty, true);

        // Send the third pulse to reach batch size
        sendPulse(setup.synapses, Pulse<int>(3));

        // All pulses should be delivered as a batch
        expect(setup.recorder.receivedPulses.length, 1);
        final batch = setup.recorder.receivedPulses.first;
        expect(batch.isComposite, true);
        expect(batch.payload.length, 3);
        expect(batch.payload.elementAt(0).payload, 1);
        expect(batch.payload.elementAt(1).payload, 2);
        expect(batch.payload.elementAt(2).payload, 3);
      });

      test('batched with batchSize 1 delivers immediately', () {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.batched,
            batchSize: 1,
          ),
        );

        sendPulse(setup.synapses, Pulse<int>(42));

        expect(setup.recorder.receivedPulses.length, 1);
        final batch = setup.recorder.receivedPulses.first;
        expect(batch.isComposite, true);
        expect(batch.payload.length, 1);
        expect(batch.payload.elementAt(0).payload, 42);
      });

      test('batched with large batch size buffers until threshold', () async {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.batched,
            batchSize: 10,
          ),
        );

        // Send 9 pulses
        for (var i = 1; i <= 9; i++) {
          sendPulse(setup.synapses, Pulse<int>(i));
        }

        // No delivery yet
        expect(setup.recorder.receivedPulses.isEmpty, true);

        // Send the 10th pulse
        sendPulse(setup.synapses, Pulse<int>(10));

        // All 10 should be delivered as a batch
        expect(setup.recorder.receivedPulses.length, 1);
        final batch = setup.recorder.receivedPulses.first;
        expect(batch.payload.length, 10);
      });
    });

    group('Strategy: buffered', () {
      test('buffered accumulates pulses and flushes after throttleTime', () async {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.buffered,
            throttleTime: const Duration(milliseconds: 50),
            batchSize: 10,
          ),
        );

        // Send multiple pulses
        sendPulse(setup.synapses, Pulse<int>(1));
        sendPulse(setup.synapses, Pulse<int>(2));
        sendPulse(setup.synapses, Pulse<int>(3));

        // No delivery yet
        expect(setup.recorder.receivedPulses.isEmpty, true);

        // Wait for buffer flush
        await delay(60);

        // All pulses should be delivered as a batch
        expect(setup.recorder.receivedPulses.length, 1);
        final batch = setup.recorder.receivedPulses.first;
        expect(batch.payload.length, 3);
        expect(batch.payload.elementAt(0).payload, 1);
        expect(batch.payload.elementAt(1).payload, 2);
        expect(batch.payload.elementAt(2).payload, 3);
      });

      test('buffered flushes when batchSize is reached', () async {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.buffered,
            throttleTime: const Duration(milliseconds: 100),
            batchSize: 3,
          ),
        );

        sendPulse(setup.synapses, Pulse<int>(1));
        sendPulse(setup.synapses, Pulse<int>(2));
        sendPulse(setup.synapses, Pulse<int>(3));

        // Should flush immediately when batchSize is reached
        expect(setup.recorder.receivedPulses.length, 1);
        final batch = setup.recorder.receivedPulses.first;
        expect(batch.payload.length, 3);
      });
    });

    group('Strategy: audit', () {
      test('audit delivers the latest pulse at intervals', () async {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.audit,
            throttleTime: const Duration(milliseconds: 50),
          ),
        );

        // Send a pulse
        sendPulse(setup.synapses, Pulse<int>(1));

        // Should not deliver immediately
        expect(setup.recorder.receivedPulses.isEmpty, true);

        // Send another pulse during the window
        await delay(20);
        sendPulse(setup.synapses, Pulse<int>(2));

        // Wait for audit interval
        await delay(40);

        // Should deliver the latest pulse
        expect(setup.recorder.receivedPulses.length, 1);
        expect(setup.recorder.receivedPayloads.first, 2);
      });

      test('audit with zero throttleTime delivers immediately', () async {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.audit,
            throttleTime: Duration.zero,
          ),
        );

        sendPulse(setup.synapses, Pulse<int>(42));

        expect(setup.recorder.receivedPulses.length, 1);
        expect(setup.recorder.receivedPayloads.first, 42);
      });
    });

    group('Strategy: debounceLeading', () {
      test('debounceLeading delivers first pulse immediately', () async {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.debounceLeading,
            throttleTime: const Duration(milliseconds: 50),
          ),
        );

        sendPulse(setup.synapses, Pulse<int>(1));

        // First pulse should be delivered immediately
        expect(setup.recorder.receivedPulses.length, 1);
        expect(setup.recorder.receivedPayloads.first, 1);

        // Subsequent pulses should be suppressed during window
        sendPulse(setup.synapses, Pulse<int>(2));
        sendPulse(setup.synapses, Pulse<int>(3));

        expect(setup.recorder.receivedPulses.length, 1);

        // Wait for window to expire
        await delay(60);

        // Send another pulse
        sendPulse(setup.synapses, Pulse<int>(4));

        // Should be delivered
        expect(setup.recorder.receivedPulses.length, 2);
        expect(setup.recorder.receivedPayloads.last, 4);
      });
    });

    group('Strategy: sample', () {
      test('sample heartbeats the first pulse then stops when unlinked', () async {
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

        synapses.call(Pulse<int>(1));
        synapses.call(Pulse<int>(99));
        expect(recorder.receivedPulses, isEmpty);

        await delay(30);
        expect(recorder.receivedPayloads, [1]);
        final afterFirstTick = recorder.receivedPulses.length;

        // Later ticks rebroadcast the same pulse; the cycle checker
        // drops revisits, so observers see it once.
        await delay(45);
        expect(recorder.receivedPulses.length, afterFirstTick);
        expect(recorder.receivedPayloads.toSet(), {1});

        expect(synapses.unlink(host, downstreamCell: recorder), isTrue);
        await delay(45);
        expect(recorder.receivedPulses.length, afterFirstTick);
      });
    });

    group('Strategy: exhaust', () {
      test('exhaust delivers pulses to downstreams', () {
        final setup = createTestSetup(
          policy: createPolicy(strategy: PropagationStrategy.exhaust),
        );
        sendPulse(setup.synapses, Pulse<int>(1));
        sendPulse(setup.synapses, Pulse<int>(2));
        expect(setup.recorder.receivedPayloads, [1, 2]);
      });
    });

    group('Strategy: resilient', () {
      test('resilient delivers when the observer accepts the pulse', () {
        final setup = createTestSetup(
          policy: createPolicy(strategy: PropagationStrategy.resilient),
        );
        sendPulse(setup.synapses, Pulse<int>(4));
        expect(setup.recorder.receivedPayloads, [4]);
      });
    });

    group('Strategy: retry', () {
      test('retry delivers when the observer accepts the pulse', () {
        final setup = createTestSetup(
          policy: createPolicy(
            strategy: PropagationStrategy.retry,
            throttleTime: Duration.zero,
            batchSize: 1,
          ),
        );
        sendPulse(setup.synapses, Pulse<int>(7));
        expect(setup.recorder.receivedPayloads, [7]);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Policy Composition & Equality
    // ─────────────────────────────────────────────────────────────

    group('Policy Composition & Equality', () {
      test('two identical policies are equal', () {
        final policy1 = PropagationPolicy(
          strategy: PropagationStrategy.debounced,
          debounceTime: const Duration(milliseconds: 300),
        );
        final policy2 = PropagationPolicy(
          strategy: PropagationStrategy.debounced,
          debounceTime: const Duration(milliseconds: 300),
        );
        expect(policy1 == policy2, true);
        expect(policy1.hashCode, policy2.hashCode);
      });

      test('two different policies are not equal', () {
        final policy1 = PropagationPolicy(
          strategy: PropagationStrategy.immediate,
        );
        final policy2 = PropagationPolicy(
          strategy: PropagationStrategy.debounced,
        );
        expect(policy1 == policy2, false);
      });

      test('policies with different debounce times are not equal', () {
        final policy1 = PropagationPolicy(
          strategy: PropagationStrategy.debounced,
          debounceTime: const Duration(milliseconds: 150),
        );
        final policy2 = PropagationPolicy(
          strategy: PropagationStrategy.debounced,
          debounceTime: const Duration(milliseconds: 300),
        );
        expect(policy1 == policy2, false);
      });

      test('policies with different throttle times are not equal', () {
        final policy1 = PropagationPolicy(
          strategy: PropagationStrategy.throttled,
          throttleTime: const Duration(milliseconds: 200),
        );
        final policy2 = PropagationPolicy(
          strategy: PropagationStrategy.throttled,
          throttleTime: const Duration(milliseconds: 400),
        );
        expect(policy1 == policy2, false);
      });

      test('policies with different batch sizes are not equal', () {
        final policy1 = PropagationPolicy(
          strategy: PropagationStrategy.batched,
          batchSize: 10,
        );
        final policy2 = PropagationPolicy(
          strategy: PropagationStrategy.batched,
          batchSize: 20,
        );
        expect(policy1 == policy2, false);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Edge Cases
    // ─────────────────────────────────────────────────────────────

    group('Edge Cases', () {
      test('zero duration works', () {
        final policy = PropagationPolicy(
          strategy: PropagationStrategy.debounced,
          debounceTime: const Duration(milliseconds: 0),
        );
        expect(policy.debounceTime, const Duration(milliseconds: 0));
      });

      test('batchSize of 0 works', () {
        final policy = PropagationPolicy(
          strategy: PropagationStrategy.batched,
          batchSize: 0,
        );
        expect(policy.batchSize, 0);
      });

      test('all strategies can be instantiated', () {
        for (final strategy in PropagationStrategy.values) {
          final policy = PropagationPolicy(strategy: strategy);
          expect(policy.strategy, strategy);
          expect(policy, isA<PropagationPolicy>());
        }
      });

      test('policy with no parameters uses defaults', () {
        final policy = PropagationPolicy();
        expect(policy.strategy, PropagationStrategy.immediate);
        expect(policy.debounceTime, const Duration(milliseconds: 150));
        expect(policy.throttleTime, const Duration(milliseconds: 200));
        expect(policy.batchSize, 10);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Integration with Synapses
    // ─────────────────────────────────────────────────────────────

    group('Integration with Synapses', () {
      test('policy can be used with synapses', () {
        final policy = PropagationPolicy(
          strategy: PropagationStrategy.debounced,
          debounceTime: const Duration(milliseconds: 50),
        );
        final synapses = Synapses<Pulse<int>, Cell>(
          policy: policy,
        );
        expect(synapses, isA<Synapses>());
      });

      test('multiple policies can be used with different synapses', () {
        final policy1 = PropagationPolicy(
          strategy: PropagationStrategy.immediate,
        );
        final policy2 = PropagationPolicy(
          strategy: PropagationStrategy.debounced,
          debounceTime: const Duration(milliseconds: 100),
        );

        final synapses1 = Synapses<Pulse<int>, Cell>(policy: policy1);
        final synapses2 = Synapses<Pulse<int>, Cell>(policy: policy2);

        expect(synapses1, isA<Synapses>());
        expect(synapses2, isA<Synapses>());
        expect(synapses1, isNot(same(synapses2)));
      });

      test('policy with filter preserves payload', () {
        final filter = FilterRule<Pulse<int>>((pulse, {user}) {
          return Pulse(pulse.payload! * 2);
        });
        final setup = createTestSetup(filter: filter);

        sendPulse(setup.synapses, Pulse<int>(21));

        expect(setup.recorder.receivedPulses.length, 1);
        expect(setup.recorder.receivedPayloads.first, 42);
      });

      test('policy with filter can drop pulses', () {
        final filter = FilterRule<Pulse<int>>((pulse, {user}) {
          final value = pulse.payload;
          if (value! < 0) {
            return null;
          }
          return pulse;
        });
        final setup = createTestSetup(filter: filter);

        sendPulse(setup.synapses, Pulse<int>(5));
        expect(setup.recorder.receivedPulses.length, 1);

        sendPulse(setup.synapses, Pulse<int>(-1));
        expect(setup.recorder.receivedPulses.length, 1); // Still 1, pulse was dropped
      });
    });

    // ─────────────────────────────────────────────────────────────
    // toString Tests
    // ─────────────────────────────────────────────────────────────

    group('toString', () {
      test('policy returns string representation', () {
        final policy = PropagationPolicy(
          strategy: PropagationStrategy.debounced,
          debounceTime: const Duration(milliseconds: 300),
        );
        final str = policy.toString();
        expect(str, contains('PropagationPolicy'));
      });

      test('policy with immediate strategy toString', () {
        final policy = PropagationPolicy();
        final str = policy.toString();
        expect(str, contains('PropagationPolicy'));
      });
    });
  });
}