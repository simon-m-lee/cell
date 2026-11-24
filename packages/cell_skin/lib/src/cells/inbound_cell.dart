// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The inbound transport cell.
///
/// Decoding transport bytes into `Pulse<WireMessage>` is the adapter's
/// job; this cell's only logic is the integrity gate: reject anything
/// that is not a wire pulse. The gate only inspects the *pulse* channel
/// — the link and action channels must pass, or the router's `asyncMap`
/// bridge is refused at construction.
/// {@category Architecture}
library;

import 'dart:async';

import 'package:cell/cell.dart';

import '../wire/wire_message.dart';

/// An integrity gate that ensures only valid wire signals enter the somatic graph.
///
/// In the framework's biological metaphor, [WirePulseGate] acts as the
/// **Ingress Membrane Filter**. It sits at the absolute edge of the
/// **Skin Membrane** to verify that an incoming impulse is a recognized
/// **Nervous Signal** (a [WireMessage]) before it is allowed to begin a
/// **Command Journey**.
///
/// ### When to use
/// - **Ingress Validation**: Automatically used by the framework's
///   inbound transport cell to prevent malformed or non-somatic data from
///   polluting the reactive graph.
/// - **Structural Integrity**: Ensures that every pulse entering via a
///   physical adapter (REST, MCP, SSE) carries a payload that can be
///   sanitized and recorded.
///
/// ### How it works
/// 1. **Signal Ingress**: A pulse arrives at the membrane's ingress pore.
/// 2. **Payload Inspection**: The gate inspects the `object.payload`.
/// 3. **Verification**:
///    - If the payload is a [WireMessage], the signal is vetted.
///    - If the payload is another [Pulse] (wrapped ingress), it recursively
///      checks for an internal [WireMessage].
/// 4. **Rejection**: If no [WireMessage] is found, the gate triggers a
///    **Membrane Rejection**, discarding the impulse.
///
/// ### Non‑obvious behavior
/// - **Pre-Forensic Gate**: Because this check happens at the entry point
///   of the [Cell.ingress], a rejection here occurs before the signal is
///   assigned a sequence number. This results in a **Forensic Hole** if
///   not explicitly logged by the transport adapter.
/// - **Channel Permissiveness**: This gate specifically filters the
///   *pulse* channel. It allows other internal signals (like link or
///   action updates) to pass through, as those are governed by the
///   underlying `ingress` cell's native logic.
///
/// ### See also
/// - [WireMessage]: The base contract for all signals crossing the membrane.
/// - [buildInboundCell]: The factory that installs this gate at the pore.
final class WirePulseGate extends TestCell<Cell> {
  WirePulseGate() : super((object, {host, arguments, user}) => true);

  @override
  FutureOr<bool> call(dynamic object, {Cell? host, dynamic arguments}) {
    if (object is Pulse) {
      final payload = object.payload;
      if (payload is WireMessage) return true;
      if (payload is Pulse) return payload.payload is WireMessage;
      return false;
    }
    return true;
  }
}

/// Builds the inbound transport cell from the framework's own
/// [Cell.ingress].
///
/// [context] stamps every inbound pulse's provenance — the security
/// layer's [ContextBridge] result is the intended value. The default
/// is **least privilege**: a described untrusted context, never
/// [Context.system]. System authority is an explicit opt-in.
IngressHandle<Pulse<WireMessage>> buildInboundCell({
  Cell? source,
  Context context = _defaultContext,
  TestCell? testRule,
}) =>
    Cell.ingress<Pulse<WireMessage>>(
      source: source,
      context: context,
      testRule: testRule ?? WirePulseGate(),
    );

/// The least-privilege default context for inbound transport pulses.
const Context _defaultContext = Context.describe('skin:untrusted');
