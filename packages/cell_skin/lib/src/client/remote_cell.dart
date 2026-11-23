// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The remote cell facade (first cut).
///
/// A [RemoteCellClient] gives downstream code a cell-shaped handle to a
/// remote target: `call` submits an `ApplyCommand`-style invocation
/// over the transport and returns the target's real [ApplyOutcome];
/// `observe` follows the egress stream. The full `implements Cell`
/// facade — which would let any existing `Cell.apply` caller consume a
/// remote cell with zero code changes — needs the entire `Cell`
/// interface surface mirrored (id, deputy, unmodifiable, …) and is the
/// documented next hardening of this class, not a silent approximation.
/// {@category Features}
library;

import 'package:cell/cell.dart';

import '../client/skin_client.dart';
import '../wire/wire_message.dart';

/// A cell-shaped handle to one remote cell, backed by a transport.
final class RemoteCellClient {
  /// The remote graph name.
  final String cellId;

  /// The transport: submits a wire message and awaits the correlated
  /// reply. `SkinClient` implements this in-process; a future
  /// `DartMcpAdapter`-backed client implements it over JSON-RPC.
  final Future<WireMessage> Function(WireMessage message, String type)
      transport;

  /// Egress stream accessor for [observe].
  final Stream<Pulse<WireMessage>> Function(String cellId) observeStream;

  int _correlationCounter = 0;

  /// Creates the in-process variant over [client].
  factory RemoteCellClient.inProcess(SkinClient client, String cellId) =>
      RemoteCellClient._(
        cellId: cellId,
        transport: (message, type) =>
            client.membrane.request(message, type: type),
        observeStream: client.observe,
      );

  RemoteCellClient._({
    required this.cellId,
    required this.transport,
    required this.observeStream,
  });

  /// Invokes [function] on the remote target and returns the target's
  /// real outcome. Throws [SkinError] for exposure/cursor/argument
  /// rejections; returns `null` for a `pendingReceipt` response.
  Future<ApplyOutcome<Object?>?> call(
    String function, {
    List<Object?>? positional,
    Map<String, Object?>? named,
    int? lastSeenSeq,
  }) {
    final request = WireRequest(
      cellId: cellId,
      function: function,
      positional: positional == null
          ? null
          : {for (var i = 0; i < positional.length; i++) '$i': positional[i]},
      named: named,
      // A counter, not a timestamp: concurrent identical calls must
      // never share a correlation id.
      correlationId:
          'remote-${DateTime.now().microsecondsSinceEpoch}-${_correlationCounter++}',
      lastSeenSeq: lastSeenSeq,
    );
    return transport(request, SkinPulseTypes.restApplyRequest).then((message) {
      return switch (message) {
        WireResponse response => response.outcome,
        WireError error => throw SkinError(error.code, error.message),
        _ => throw SkinError('unexpected_response', '$message'),
      };
    });
  }

  /// State-change pulses for this cell (`skin.egress.<cellId>` carrying
  /// [WireStateChange]).
  Stream<Pulse<WireMessage>> observe() => observeStream(cellId);
}
