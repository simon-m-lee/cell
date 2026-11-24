// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The projection layer for interacting with distant somatic entities.
///
/// In the framework's biological metaphor, this library defines the
/// **Synaptic Projection**. It provides the [RemoteCellClient], which acts
/// like an axon extending from the local environment to a cell physically
/// located behind a remote **Skin Membrane**.
///
/// ### Why this exists
/// A [RemoteCellClient] allows local logic to treat a remote cell as a
/// near-native participant in the reactive graph. It abstracts the
/// complexities of the transport layer, allowing developers to trigger
/// **Somatic State Transitions** on a distant target using familiar
/// cell-like patterns.
///
/// ### The Remote Command Journey
/// When a function is invoked on a remote handle:
/// 1.  **Signal Packaging**: The local call is wrapped into a **Nervous Signal**
///     ([WireRequest]) containing the necessary **Skin Payload**.
/// 2.  **Transport Crossing**: The signal travels across a physical seam
///     (REST, MCP, or in-process bridge) to reach the remote membrane.
/// 3.  **Forensic Resolution**: The client awaits a **Forensic Receipt**
///     ([WireResponse]) or handles a **Membrane Rejection** ([WireError]).
/// 4.  **Observation**: The client follows the remote cell's **External Echo**
///     by subscribing to its egress stream.
///
/// ### Forensic Integrity
/// Even though the cell is remote, this library ensures that the
/// **Command Journey** remains traceable. The [RemoteCellClient] propagates
/// `lastSeenSeq` markers to maintain **Causal Linkage**, ensuring that
/// concurrent mutations across different somatic clusters do not result
/// in forensic ambiguity.
///
/// ### Somatic Mirroring (Future Hardening)
/// The current implementation provides a functional facade. The documented
/// next evolution is the "Somatic Mirror"—a full `implements Cell`
/// representation that mirrors the entire technical "DNA" (ID, deputy,
/// metadata) of the remote target, allowing it to be injected into
/// local `Cell.apply` calls with zero code changes.
///
/// ### See also
/// - [RemoteCellClient]: The primary handle for remote interaction.
/// - [SkinClient]: The underlying transport coordinator.
/// - [WireMessage]: The envelopes used to bridge the distance.
/// {@category Features}
library;

import 'package:cell/cell.dart';

import '../client/skin_client.dart';
import '../wire/correlation_id.dart';
import '../wire/wire_message.dart';

/// A local handle representing a distant somatic entity behind a remote membrane.
///
/// In the framework's biological metaphor, [RemoteCellClient] is a
/// **Synaptic Projection**. It acts as an **Axon** extending from the local
/// environment to a cell physically located behind a remote **Skin Membrane**.
///
/// It provides a cell-like interface for triggering **Somatic State Transitions**
/// on a target that exists in a separate somatic cluster, abstracting away
/// the underlying transport (REST, MCP, or in-process bridge).
///
/// ### When to use
/// - **Cross-Cluster Interaction**: Use this to mutate or observe cells
///   hosted on a different server, AI agent, or process.
/// - **Orchestration**: Ideal for building distributed somatic systems where
///   one "brain" needs to stimulate "muscles" in a remote limb.
///
/// ### How it works
/// 1. **Signal Packaging**: Local calls are converted into **Nervous Signals**
///    ([WireRequest]) containing the **Skin Payload**.
/// 2. **Axonal Transport**: The signal travels across the [transport] seam.
/// 3. **Forensic Resolution**: The client awaits a **Forensic Receipt**
///    ([WireResponse]) to confirm the transition was anchored in the
///    remote **Forensic Ledger**.
///
/// ### Non‑obvious behavior
/// - **Causal Linkage**: The client automatically propagates `lastSeenSeq`
///   markers. This ensures that the **Command Journey** maintains
///   forensic integrity even across network boundaries.
/// - **Idempotency**: Every impulse is stamped with a unique **Causal Link**
///   (correlation ID) to prevent duplicate transitions if the transport
///   layer retries the signal.
/// - **Observation**: Calling [observe] creates a subscription to the
///   remote cell's **External Echo**, allowing the local system to react
///   to distant state changes.
///
/// ### See also
/// - [SkinClient]: The coordinator usually responsible for spawning these handles.
/// - [WireRequest]: The envelope used to stimulate the remote cell.
/// - [RemoteCellClient.inProcess]: For simulating remote axons within the same memory space.
///
/// ### AI Agent Guide
/// **Layer:** Skin Client — this is your axon to a remote tool.
/// **Live signature:** `final class RemoteCellClient { factory RemoteCellClient.inProcess(SkinClient client, String cellId); Future<WireMessage> request(WireMessage message, String type); Stream<Pulse<WireMessage>> observe(String cellId); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Traceability:** Always provide `lastSeenSeq` to maintain causal integrity.
/// **Constraint:** A [RemoteCellClient] is fixed to a single [cellId].
final class RemoteCellClient {
  /// The unique **Somatic Address** of the remote cell.
  final String cellId;

  /// The physical seam used to transmit signals across the membrane.
  ///
  /// In the framework's biological metaphor, this is the **Axonal Transport**.
  /// It takes a **Nervous Signal** ([WireRequest]) and returns the
  /// remote system's response.
  final Future<WireMessage> Function(WireMessage message, String type)
  transport;

  /// The mechanism for listening to the remote cell's **External Echo**.
  final Stream<Pulse<WireMessage>> Function(String cellId) observeStream;

  /// Creates an **In-Process Axon** connected to a local [SkinClient].
  ///
  /// Useful for testing and architectural decoupling where the "remote"
  /// cell is actually in the same process but should be treated as
  /// existing behind a membrane boundary.
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


  /// Stimulates the remote cell to perform a **Somatic State Transition**.
  ///
  /// This method initiates a **Command Journey**. It packages the
  /// [positional] and [named] nutrients into a [WireRequest] and
  /// awaits the remote **Forensic Receipt**.
  ///
  /// ### Outcomes
  /// - **Accepted**: Returns an `ApplyOutcome` if the remote
  ///   **Integrity Gate** anchored the change.
  /// - **Membrane Rejection**: Throws a [SkinError] if the remote membrane
  ///   discarded the signal (e.g., bad arguments, cursor conflict).
  /// - **Pending**: Returns `null` if the remote system generated a
  ///   `pendingReceipt`, indicating the journey is not yet anchored.
  ///
  /// ### Parameters
  /// - [function]: The **Signal Label** of the remote pore to stimulate.
  /// - [lastSeenSeq]: The last known sequence from the remote
  ///   **Forensic Ledger** to ensure **Causal Linkage**.
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
      // The shared isolate-wide sequence: concurrent identical calls
      // from several clients must never share a correlation id.
      correlationId: nextCorrelationId('remote'),
      lastSeenSeq: lastSeenSeq,
    );
    return transport(request, SkinPulseTypes.restApplyRequest).then((message) {
      return switch (message) {
        WireResponse response => SkinClient.outcomeOf(response),
        WireError error => throw SkinError(error.code, error.message),
        _ => throw SkinError('unexpected_response', '$message'),
      };
    });
  }

  /// Subscribes to the remote cell's **External Echo**.
  ///
  /// Returns a stream of [WireStateChange] or [WireNotification] signals
  /// emitted by the remote cell as it undergoes transitions in its
  /// local somatic graph.
  Stream<Pulse<WireMessage>> observe() => observeStream(cellId);
}
