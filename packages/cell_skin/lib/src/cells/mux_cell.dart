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

/// Builds the somatic convergence point for all outbound wire signals.
///
/// In the framework's biological metaphor, the mux cell is the
/// **Egress Funnel**. It acts as a final fan-in primitive that collects
/// **Nervous Signals** from various internal somatic sources—such as
/// the router, the egress fan-in, and the **Forensic Ledger** tail—and
/// prepares them to cross the **Skin Membrane**.
///
/// ### When to use
/// - **Membrane Orchestration**: Automatically used by the [SkinMembrane]
///   to unify multiple internal signal streams into a single outbound
///   channel.
/// - **Outbound Filtering**: Essential for ensuring that only sanitized
///   [WireMessage] envelopes reach the terminal [buildOutboundCell].
///
/// ### How it works
/// 1. **Signal Collection**: It performs a `Cell.synthesis` over all
///    provided [sources].
/// 2. **Integrity Scrubbing**: The aggregator inspects every incoming
///    pulse. If the payload is not a [WireMessage] (or a pulse wrapping
///    one), it is suppressed.
/// 3. **Unwrapping**: If a signal arrives double-wrapped (e.g., from
///    an async mapping in a cell), the mux strips the outer layer to
///    ensure the outbound stream is a consistent `Pulse<WireMessage>`.
///
/// ### Non‑obvious behavior
/// - **Forensic Transparency**: The mux does not create new state; it
///   merely facilitates the exit of existing **Nervous Signals**. It
///   ensures that the **Command Journey** results and state updates
///   remain chronologically coherent during egress.
/// - **Wrap Handling**: By design, it handles both `WireMessage` payloads
///   (from the ledger tail) and `Pulse<WireMessage>` payloads (from
///   the router's `asyncMap`), preventing internal somatic structure
///   from leaking through the **Skin Membrane**.
///
/// ### See also
/// - [buildOutboundCell]: The terminal observation cell that follows this mux.
/// - [WireMessage]: The envelope required for all surviving pulses.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is the final aggregation point before egress.
/// **Live signature:** `Cell buildMuxCell({required Iterable<Cell> sources})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Status:** Passive filtering and unwrapping.
/// **Constraint:** Only `WireMessage` types survive this funnel.
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

/// Builds the terminal egress point of the membrane, connecting the internal graph to the physical transport.
///
/// In the framework's biological metaphor, [buildOutboundCell] creates the
/// **Terminal Egress Pore**. It represents the absolute boundary of the
/// **Skin Membrane**, where a **Nervous Signal** (a [WireMessage]) is
/// physically expelled from the somatic body to become an **External Echo**.
///
/// ### When to use
/// - **Transport Binding**: The final step in orchestrating a [SkinMembrane].
///   It bridges the unified [mux] stream to a specific transport effect
///   (e.g., writing to a WebSocket, SSE stream, or MCP transport).
/// - **Pore Realization**: Used by adapters to turn an internal somatic
///   event into a physical network packet.
///
/// ### How it works
/// 1. **Signal Observation**: It creates a `Cell.observe` on the [mux] cell.
/// 2. **Effect Trigger**: For every pulse that passes through the **Egress Funnel**,
///    the [send] function is executed.
/// 3. **Physical Egress**: The [send] function translates the **Skin Form**
///    of the message into the transport-specific protocol (e.g., JSON-RPC over stdio).
///
/// ### Non‑obvious behavior
/// - **Forensic Pass-through**: This cell does not alter the signal or
///   generate new forensic data. It is the final observer of the
///   **Command Journey's** result.
/// - **Lifecycle Governance**: The returned [EgressHandle] is the authoritative
///   control for this pore. If the handle is not cancelled when the external
///   connection is severed, it creates a "Forensic Leak" (a memory leak) as
///   the observation remains active.
/// - **Ordered Delivery**: It ensures that state changes and ledger entries
///   are pushed to the environment in the exact sequence they were anchored
///   in the **Forensic Ledger**.
///
/// ### See also
/// - [buildMuxCell]: The fan-in funnel that feeds this terminal pore.
/// - [EgressHandle]: The mechanism used to manage the pore's lifecycle.
/// - [WireMessage]: The envelope being transmitted.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is the physical exit point.
/// **Live signature:** `EgressHandle<Pulse<WireMessage>> buildOutboundCell({required Cell mux, required void Function(Pulse<WireMessage> pulse) send})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Status:** Terminal observation.
/// **Constraint:** The [send] effect must be exception-free; errors here
/// can crash the egress pipeline of the entire membrane.
EgressHandle<Pulse<WireMessage>> buildOutboundCell({
  required Cell mux,
  required void Function(Pulse<WireMessage> pulse) send,
}) =>
    Cell.observe<Pulse<WireMessage>>(source: mux, effect: send);
