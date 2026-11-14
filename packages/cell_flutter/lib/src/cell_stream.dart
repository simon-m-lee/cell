import 'dart:async';

import 'package:cell/cell.dart';

import 'pulse_delivery.dart';

/// Bridges a [Cell] to a `Stream<V?>`.
extension CellAsStream on Cell {
  /// Bridges this cell to a `Stream<V?>`.
  ///
  /// Emits every pulse's payload. If [emitErrors] is `true` (default),
  /// error pulses become `Stream.addError`. Cancelling the stream stops
  /// the internal subscription.
  ///
  /// ## Sync vs async
  ///
  /// [sync] defaults to `true`. Sync streams deliver values in the same
  /// microtask as the pulse — useful for testing (no `pump()` required).
  /// For production interop with Streams that dislike sync delivery,
  /// pass `sync: false`.
  ///
  /// ## Lifecycle
  ///
  /// The stream's `StreamController` is single-subscription. Calling
  /// `stream.listen` twice throws. For broadcast use, wrap with
  /// `.asBroadcastStream()`. The egress is started in `onListen` and
  /// stopped in `onCancel`. Dropping the stream without listening does
  /// not subscribe. `onCancel` does not call `close()` — `close()` waits
  /// on `onCancel`, so calling it from there deadlocks the done future.
  ///
  /// ## Error pulses
  ///
  /// `Cell.fromFuture`, `Cell.fromStream`, and `Cell.asyncMap` emit
  /// `type: 'error'` pulses. [emitErrors] turns those into
  /// `Stream.addError`.
  ///
  /// ## Usage
  ///
  /// ```dart
  /// final counter = Cell.state<int>(initial: 0);
  /// await for (final v in counter.cell.asStream<int>()) {
  ///   print(v);  // 1, 2, ...
  ///   if (v! >= 3) break;
  /// }
  /// ```
  Stream<V?> asStream<V>({bool sync = true, bool emitErrors = true}) {
    late final StreamController<V?> controller;
    EgressHandle<Pulse<Object?>>? egress;

    controller = StreamController<V?>(
      sync: sync,
      onListen: () {
        var sawLive = false;
        egress = Cell.observe<Pulse<Object?>>(
          source: this,
          effect: (pulse) {
            sawLive = true;
            if (controller.isClosed) return;
            _addPulse<V>(controller, pulse, emitErrors);
          },
          initiallyStarted: true,
        );
        if (!sawLive) {
          final latest = retainedPulseOf(this);
          if (latest != null && !controller.isClosed) {
            _addPulse<V>(controller, latest, emitErrors);
          }
        }
      },
      onCancel: () {
        egress?.stop();
        egress = null;
      },
    );
    return controller.stream;
  }
}

void _addPulse<V>(
  StreamController<V?> controller,
  Pulse<Object?> pulse,
  bool emitErrors,
) {
  if (pulse.type == 'error') {
    if (emitErrors) {
      controller.addError(
        pulse.payload ?? StateError('Unknown error pulse'),
      );
    }
    return;
  }
  final payload = pulse.payload;
  if (payload == null && null is V) {
    controller.add(null);
  } else if (payload is V) {
    controller.add(payload);
  } else {
    controller.addError(
      StateError(
        'asStream<$V>: pulse payload is ${payload.runtimeType}, not $V?.',
      ),
    );
  }
}