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

/// Rejects pulses whose payload is not a [WireMessage] (at either wrap
/// level — `Cell.ingress<Pulse<WireMessage>>` wraps the wire pulse in
/// the ingress's own pulse); allows every other channel.
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
