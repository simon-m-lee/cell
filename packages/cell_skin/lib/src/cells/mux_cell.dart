// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The mux and outbound cells.
///
/// The mux is the framework's existing fan-in primitive
/// (`Cell.synthesis`) over the router responses, the egress fan-in and
/// the ledger tail; the outbound cell is the terminal `Cell.observe`
/// that writes every surviving pulse back to the transport.
/// {@category Architecture}
library;

import 'package:cell/cell.dart';

import '../wire/wire_message.dart';

/// Builds the mux: a `Cell.synthesis` over [sources] that passes the
/// wire pulse through and suppresses everything else.
///
/// Two wrap levels exist by design: the router's `asyncMap` output
/// carries `Pulse<WireMessage>` *payloads*, and the egress fan-in
/// ingress double-wraps; the ledger tail (single wrap) is handled by
/// the same check. The mux emits the wire pulse itself, so the
/// outbound terminal cell always sees `Pulse<WireMessage>`.
Cell buildMuxCell({required Iterable<Cell> sources}) =>
    Cell.synthesis<Pulse<WireMessage>>(
      sources,
      aggregator: (cells, emit) {
        final payload = emit.payload;
        if (payload is WireMessage) return emit as Pulse<WireMessage>;
        if (payload is Pulse && payload.payload is WireMessage) {
          return payload as Pulse<WireMessage>;
        }
        return null;
      },
    );

/// Builds the outbound terminal cell: a `Cell.observe` on [mux] whose
/// effect is [send].
EgressHandle<Pulse<WireMessage>> buildOutboundCell({
  required Cell mux,
  required void Function(Pulse<WireMessage> pulse) send,
}) =>
    Cell.observe<Pulse<WireMessage>>(source: mux, effect: send);
