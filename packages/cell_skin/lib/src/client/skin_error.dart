// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The failure vocabulary for signals crossing the somatic boundary.
///
/// In the framework's biological metaphor, this library defines the
/// **Nervous Signal Rejection** protocol. It provides the structured
/// feedback mechanism for when a **Command Journey** fails to penetrate
/// the **Skin Membrane** or is interrupted before reaching the
/// **Forensic Ledger**.
///
/// ### Why this exists
/// While internal cells throw standard Dart exceptions, those failures
/// must be translated into a stable, wire-safe format ([WireError]) before
/// crossing the membrane. This library provides the client-side
/// representation of those rejections, allowing external AI agents and
/// remote axons to react to **Membrane Rejections** without needing
/// access to internal somatic DNA.
///
/// ### Forensic Implications
/// A [SkinError] typically marks a **Forensic Hole**. It signifies that
/// a stimulus was applied to the membrane, but no **Somatic State Transition**
/// was anchored in the ledger. By catching these errors, clients can
/// diagnose whether a failure was due to:
/// 1.  **Gate Blockage**: An [Integrity Gate] (like schema validation or
///     [SkinAuth]) rejected the impulse.
/// 2.  **Causal Drift**: The pulse violated **Causal Linkage** (a cursor
///     conflict).
/// 3.  **Membrane Retraction**: The physical transport layer (REST/SSE/MCP)
///     was severed during the journey.
///
/// ### See also
/// - [SkinError]: The primary exception class for boundary failures.
/// - [WireError]: The wire-format representation of these failures.
/// - [SkinClient]: The internal axon that translates wire errors into exceptions.
///
/// {@category Features}
/// {@category Security}
library;

/// A failure encountered at the boundary when a nervous signal is rejected.
///
/// In the framework's biological metaphor, [SkinError] represents a
/// **Membrane Rejection**. It is the "pain signal" returned to the
/// environment when an impulse fails to pass through an **Integrity Gate**
/// or when a **Command Journey** is terminated before it can result in a
/// **Somatic State Transition**.
///
/// Unlike internal framework exceptions, a [SkinError] is designed to cross
/// the **Skin Membrane**. It translates technical somatic failures into
/// a stable vocabulary for external AI agents and remote axons.
///
/// ### When to use
/// - **Transport Failures**: Thrown by a [SkinClient] or [RemoteCellClient]
///   when the underlying connection is severed (code: `closed`).
/// - **Gate Rejections**: Thrown when the [SkinRouter] blocks a signal
///   due to structural issues (code: `bad_arguments`) or security
///   violations (code: `unauthorized`).
/// - **Causal Conflicts**: Thrown when a pulse violates **Causal Linkage**
///   rules (code: `conflict` or `cursor_required`).
///
/// ### Forensic Integrity
/// Because a [SkinError] typically represents a rejection *before* the
/// pulse is anchored, it often corresponds to a **Forensic Hole** in the
/// target cell's ledger. The environment receives this error, but the
/// cell's internal state remains unchanged.
///
/// ### See also
/// - [WireError]: The wire-format envelope that carries this failure.
/// - [SkinRouter]: The junction that typically generates these rejections.
/// - [BadArgumentsException]: A common internal cause for this error.
///
/// ### AI Agent Guide
/// **Layer:** Skin Client — this is your feedback loop for failed tool calls.
/// **Live signature:** `final class SkinError implements Exception { final String code; final String message; const SkinError(String code, String message); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Recovery:**
/// - If `code == 'conflict'`, refresh your **Somatic Index** and check
///   the `lastSeenSeq`.
/// - If `code == 'bad_arguments'`, verify your payload against the
///   **Somatic Blueprint** (JSON Schema).
final class SkinError implements Exception {
  /// The stable somatic failure code.
  ///
  /// Acts as the **Integrity Marker** for the failure. Examples include:
  /// - `unknown_tool`: The targeted **Membrane Pore** does not exist.
  /// - `conflict`: The pulse violates **Causal Linkage**.
  /// - `bad_arguments`: The **Skin Payload** is structurally unsound.
  /// - `closed`: The **Skin Membrane** has been retracted.
  final String code;

  /// A human-readable description of the rejection.
  ///
  /// In the framework's biological metaphor, this is the **Forensic Context**.
  /// It provides enough detail for an operator to understand why the
  /// **Command Journey** failed without leaking sensitive internal DNA.
  final String message;

  const SkinError(this.code, this.message);

  @override
  String toString() => 'SkinError($code): $message';
}
