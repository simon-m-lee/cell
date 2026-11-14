// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:collection';

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../pulse_delivery.dart';

/// Invokes [onPulse] for every pulse emitted by [cell].
///
/// The hook equivalent of `CellListener`. Does not rebuild the widget —
/// that's the point. Use for navigation, snackbars, haptics, analytics.
///
/// ## Mid-frame deferral
///
/// Pulses fired during Flutter's build or mid-frame phases are delivered
/// at the end of the frame, so `Navigator.push` and friends are safe.
/// Pulses fired outside the build phases are delivered synchronously.
///
/// Multiple pulses queued in the same frame are delivered in order, in a
/// single post-frame callback. On cell swap, the pending queue is cleared
/// before the new egress is bound.
///
/// ## Error pulses
///
/// `fromFuture`, `fromStream`, and `asyncMap` emit `type: 'error'` pulses.
/// Do not cast the payload blindly on that path.
///
/// ```dart
/// onPulse: (context, pulse) {
///   if (pulse.type == 'error') {
///     showErrorDialog(context, pulse.payload);
///     return;
///   }
///   handleValue(pulse.payload);
/// },
/// ```
///
/// `useCellListener` delivers each queued pulse once, in order. The
/// post-frame callback must not close over the pulse that scheduled it.
///
/// ## Error containment
///
/// If [onPulse] throws, the error is reported via `FlutterError.reportError`
/// and the listener continues to receive subsequent pulses.
void useCellListener<V>({
  required Cell cell,
  required void Function(BuildContext context, Pulse<V> pulse) onPulse,
}) {
  final context = useContext();
  final onPulseRef = useRef(onPulse);
  onPulseRef.value = onPulse;
  final pending = useMemoized(Queue<Pulse<V>>.new, [cell]);
  final flushScheduled = useRef(false);

  useEffect(() {
    var disposed = false;
    final egress = Cell.observe<Pulse<V>>(
      source: cell,
      effect: (pulse) {
        if (disposed || !context.mounted) return;
        void invoke(Pulse<V> next) {
          try {
            onPulseRef.value(context, next);
          } catch (e, st) {
            FlutterError.reportError(FlutterErrorDetails(
              exception: e,
              stack: st,
              library: 'cell_flutter',
              context: ErrorDescription(
                'while invoking useCellListener.onPulse',
              ),
            ));
          }
        }

        if (!isCellBuildPhase) {
          invoke(pulse);
          return;
        }
        pending.add(pulse);
        if (flushScheduled.value) return;
        flushScheduled.value = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          flushScheduled.value = false;
          while (pending.isNotEmpty && !disposed && context.mounted) {
            // Remove before invoke. An onPulse that unmounts the hook
            // clears [pending]; removing afterwards throws.
            invoke(pending.removeFirst());
          }
          pending.clear();
        });
      },
      initiallyStarted: true,
    );
    return () {
      disposed = true;
      egress.stop();
      pending.clear();
      flushScheduled.value = false;
    };
  }, [cell]);
}
