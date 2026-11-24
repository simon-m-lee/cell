// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The wire message taxonomy for `cell_skin`.
///
/// One wire event. Every transport — MCP, REST, SSE, stdio — is a
/// `Pulse<WireMessage>` whose `type` discriminates the variant. The
/// payload classes themselves are plain JSON-serialisable objects; the
/// pulse's own `type`, `context`, `source` and `trace` fields carry
/// everything else, so no new envelope codec exists on top of the
/// framework's `PulseCodec`.
/// {@category Features}
library;

import 'package:cell/cell.dart';

import '../manifest/skin_manifest.dart';
import 'wire_outcome.dart';
import 'wire_receipt.dart';
import 'wire_version.dart';

/// A static taxonomy of names for signals crossing the system membrane.
///
/// In the framework's biological metaphor, [SkinPulseTypes] defines the
/// **Signal Vocabulary**. Every "Nervous Signal" ([Pulse]) that travels
/// across the skin must be labeled with one of these types so the receiver
/// knows how to process it and how to record it in the **Forensic Ledger**.
///
/// ### When to use
/// - **Transport Adapters**: Use these strings when building MCP, REST, or
///   SSE adapters to identify the intent of an incoming or outgoing pulse.
/// - **Signal Routing**: Use these types to filter signals in the
///   governance layer.
///
/// ### How it works
/// These are not a new type system; they are standard [Pulse.type] strings.
/// They act as the "Common Language" between the internal reactive graph
/// and the external wire.
///
/// ### Non‑obvious behavior
/// - **Outcome Mapping**: The [resultType] and [restResponseType] methods
///   use Dart pattern matching to ensure that every [ApplyOutcome] (the
///   Forensic Receipt) is mapped to a specific sub-type (e.g., `.accepted`).
/// - **Namespace Logic**: Types are grouped by protocol (like `mcp.` or `rest.`)
///   to prevent signal collisions when multiple transports are active at once.
///
/// ### Example: Labeling a Signal
/// ```dart
/// final pulse = Pulse(
///   payload: myData,
///   type: SkinPulseTypes.restApplyRequest,
/// );
/// ```
///
/// ### See also
/// - [WireMessage]: The container that carries these signals.
/// - [ApplyOutcome]: The results that these types help categorize.
/// - [guide/HowTo-Cell.apply.md](guide/HowTo-Cell.apply.md): For the
///   complete "Command Journey" context.
abstract final class SkinPulseTypes {
  static const mcpToolsCall = 'mcp.tools.call';
  static const restApplyRequest = 'rest.apply.request';
  static const mcpToolsResultPrefix = 'mcp.tools.result.';
  static const restApplyResponsePrefix = 'rest.apply.response.';
  static const mcpNotificationPrefix = 'mcp.notifications.';
  static const manifestRequest = 'skin.manifest.request';
  static const manifestResponse = 'skin.manifest.response';
  static const ledgerEntry = 'skin.ledger.entry';
  static const egressPrefix = 'skin.egress.';
  static const errorTransport = 'skin.error.transport';

  /// Translates an internal [ApplyOutcome] into a specific **Signal Label** for MCP tools.
  ///
  /// In the framework's biological metaphor, this function creates the
  /// **Forensic Stamp** for a tool result. It takes the official receipt
  /// from the cell and converts it into a vocabulary that external MCP
  /// (Model Context Protocol) clients can understand.
  ///
  /// ### When to use
  /// - **MCP Tool Responses**: Use this when you are sending the result
  ///   of a tool call back to an AI agent or an MCP host.
  /// - **Result Routing**: Use this to ensure the external signal matches
  ///   the internal state recorded in the **Forensic Ledger**.
  ///
  /// ### How it works
  /// It takes the [outcome] (the Forensic Receipt) and attaches a specific
  /// suffix to the `mcp.tools.result.` prefix based on what happened:
  /// - `accepted`: The command was successful.
  /// - `rejected`: The command was blocked by an Integrity Gate.
  /// - `staged`: The command is waiting in a transaction ledger.
  ///
  /// ### Parameters
  /// - **outcome**: The [ApplyOutcome] returned by the cell's `apply` method.
  ///
  /// ### Non‑obvious behavior
  /// - **Exhaustive Mapping**: This uses a Dart `switch` expression to
  ///   ensure that *every* possible outcome type is handled. If a new outcome
  ///   type is added to the core framework, the compiler will require
  ///   this labeler to be updated.
  /// - **Authoritative Identity**: The resulting string is used as the
  ///   `type` for the outgoing [Pulse], allowing the receiver to trace
  ///   the "Command Journey" back to its internal result.
  ///
  /// ### Example
  /// ```dart
  /// final outcome = await myCell.apply(myCommand);
  /// final signalType = SkinPulseTypes.resultType(outcome);
  ///
  /// // Returns: "mcp.tools.result.accepted"
  /// print(signalType);
  /// ```
  static String resultType(ApplyOutcome<Object?> outcome) =>
      '$mcpToolsResultPrefix${switch (outcome) {
        ApplyAccepted() => 'accepted',
        ApplyRejected() => 'rejected',
        ApplyStaged() => 'staged',
      }}';

  /// Translates an internal [ApplyOutcome] into a specific **Signal Label** for REST responses.
  ///
  /// In the framework's biological metaphor, this function creates the
  /// **Forensic Stamp** for a web response. It takes the official receipt
  /// from the cell and converts it into a vocabulary that standard REST
  /// clients can understand.
  ///
  /// ### When to use
  /// - **REST API Responses**: Use this when sending the result of a
  ///   command (POST/PUT) back to a web client.
  /// - **Transport Mapping**: Use this to ensure the external HTTP signal
  ///   matches the internal state recorded in the **Forensic Ledger**.
  ///
  /// ### How it works
  /// It takes the [outcome] (the Forensic Receipt) and attaches a specific
  /// suffix to the `rest.apply.response.` prefix based on the result:
  /// - `accepted`: The command was successful and committed.
  /// - `rejected`: The command was blocked by a safety rule (Integrity Gate).
  /// - `staged`: The command is held in a transaction and not yet final.
  ///
  /// ### Parameters
  /// - **outcome**: The [ApplyOutcome] returned by the cell's `apply` method.
  ///
  /// ### Non‑obvious behavior
  /// - **Pattern Matching**: This uses a Dart 3 `switch` expression to ensure
  ///   every outcome type is handled. If the core framework adds a new type
  ///   of outcome, the compiler will require this method to be updated.
  /// - **Authoritative Identity**: The resulting string is used as the
  ///   `type` for the outgoing [Pulse]. This allows the receiver to trace
  ///   the **Command Journey** back to its internal result.
  ///
  /// ### Example
  /// ```dart
  /// final outcome = await myCell.apply(myCommand);
  /// final signalType = SkinPulseTypes.restResponseType(outcome);
  ///
  /// // Returns: "rest.apply.response.rejected"
  /// print(signalType);
  /// ```
  static String restResponseType(ApplyOutcome<Object?> outcome) =>
      '$restApplyResponsePrefix${switch (outcome) {
        ApplyAccepted() => 'accepted',
        ApplyRejected() => 'rejected',
        ApplyStaged() => 'staged',
      }}';
}

/// The universal envelope for every signal crossing the system's membrane.
///
/// In the framework's biological metaphor, [WireMessage] is the **Skin Payload**.
/// Every **Nervous Signal** ([Pulse]) that enters or leaves the system must be
/// wrapped in this envelope so it can safely travel over the network (the "Wire")
/// via MCP, REST, or SSE.
///
/// ### When to use
/// - **Transport Adapters**: Use this when writing code that talks to the
///   outside world (like a web server or a command-line tool).
/// - **Membrane Crossing**: Use this whenever a signal needs to move from
///   the internal reactive graph to an external client.
///
/// ### How it works
/// - **Sealed Vocabulary**: This is a closed (sealed) hierarchy. Every
///   message has a specific `kind` (like `request`, `response`, or `error`).
/// - **Clean Serialization**: The [toJson] method converts the message into
///   a clean format for sending over the network.
/// - **Self-Identifying**: The [WireMessage.fromJson] factory uses the `kind`
///   field to automatically turn raw JSON back into the correct message type.
///
/// ### Non‑obvious behavior
/// - **Causal Matching**: For requests and responses, the framework uses a
///   `correlationId` to ensure the **Forensic Receipt** is matched to the
///   correct original request.
/// - **Forensic Separation**: A `WireError` represents a failure in the
///   **Skin** (like a bad network connection) and never carries a
///   **Forensic Receipt**, while a `WireResponse` carries the official
///   result from the ledger.
/// - **Stateless Metadata**: Metadata about the signal (like its timestamp)
///   travels on the [Pulse] itself, not inside the [WireMessage] data.
///
/// ### See also
/// - [SkinPulseTypes]: The taxonomy of labels used for these messages.
/// - [WireRequest]: The envelope for incoming commands.
/// - [WireResponse]: The envelope for outgoing forensic results.
/// - [guide/HowTo-Cell.apply.md](guide/HowTo-Cell.apply.md): For the
///   complete "Command Journey" context.
/// {@category Features}
/// {@category Wire Messages}
sealed class WireMessage {

  const WireMessage();

  /// The stable name of the message type used for decoding.
  ///
  /// This acts as the **Signal Label**. It tells the receiver exactly
  /// what kind of **Nervous Signal** is inside the envelope.
  String get kind;

  /// Converts the message into a JSON-safe map.
  ///
  /// This produces the **Skin Form** of the message. It ensures the
  /// payload is safe to travel over the wire while keeping internal
  /// metadata on the pulse.
  Map<String, Object?> toJson();

  /// Decodes a raw JSON map into the correct [WireMessage] type.
  ///
  /// ### How it works
  /// 1. **Kind Detection**: It looks at the `kind` field in the JSON.
  /// 2. **Type Mapping**: It uses a `switch` expression to call the specific
  ///    factory (like [WireRequest.fromJson]).
  /// 3. **Safety Gate**: If the `kind` is unknown or the data is broken,
  ///    it throws a [FormatException] instead of a raw system error.
  ///
  /// ### Forensic Integrity
  /// This factory ensures that every message entering the system is
  /// properly identified before it begins its **Command Journey**.
  factory WireMessage.fromJson(Map<String, Object?> json) {
    requireSkinWireVersion(json);
    final kind = json['kind'];
    try {
      return switch (kind) {
        'request' => WireRequest.fromJson(json),
        'response' => WireResponse.fromJson(json),
        'stateChange' => WireStateChange.fromJson(json),
        'notification' => WireNotification.fromJson(json),
        'manifestRequest' => WireManifestRequest.fromJson(json),
        'manifestResponse' => WireManifestResponse.fromJson(json),
        'ledgerEntry' => WireLedgerEntry.fromJson(json),
        'error' => WireError.fromJson(json),
        _ => throw FormatException('unknown wire message kind: $kind'),
      };
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException(
          'malformed wire message (kind: $kind): ${error.runtimeType}');
    }
  }
}

/// An envelope for an incoming command sent from the outside world into the system.///
/// In the framework's biological metaphor, [WireRequest] is a **Nervous Signal**
/// that has just touched the **Skin Membrane**. It carries the instructions
/// needed to start a [Command Journey] inside the reactive graph.
///
/// ### When to use
/// - **External Commands**: Use this when a tool (like MCP), a web client (REST),
///   or a remote server wants to trigger an action in a cell.
/// - **Skin Adapters**: Use this as the standard data format for any transport
///   layer you build.
///
/// ### How it works
/// 1. **Ingress**: The request arrives at the system membrane with a [cellId]
///    and a [function] name.
/// 2. **Correlation**: The system assigns a [correlationId] to track the
///    signal's journey through the **Forensic Ledger**.
/// 3. **Conversion**: The system turns this envelope into an internal command
///    record and sends it to the target cell's **Integrity Gate**.
///
/// ### Non‑obvious behavior
/// - **JSON Argument Stability**: Positional arguments are stored as a map
///   of index strings (e.g., `{"0": value}`) rather than a list. This ensures
///   that JSON parsers do not accidentally reorder your data.
/// - **Strict Correlation**: The [correlationId] is the "Source of Truth"
///   for the ledger. Even if a client provides their own ID, the server-assigned
///   ID is what determines the official **Forensic Receipt**.
/// - **Stateless Cursors**: The [lastSeenSeq] allows a client to say "I only
///   want to run this if my view of the data is up to date."
///
/// ### Example
/// ```dart
/// final request = WireRequest(
///   cellId: 'home.thermostat',
///   function: 'setTemperature',
///   positional: {'0': 22},
///   correlationId: 'srv-tx-777',
///   clientCorrelationId: 'my-local-req-1',
/// );
/// ```
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is a command envelope, not a graph node.
/// **When to use:** sending a command at a bound `(cellId, function)` over any transport.
/// **When NOT to use:** fire-and-forget signals — use [WireNotification]; state observations — use [WireStateChange].
/// **Live signature:** `const WireRequest({required String cellId, required String function, Map<String, Object?>? positional, Map<String, Object?>? named, required String correlationId, String? clientCorrelationId, int? lastSeenSeq, DateTime? deadline})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Do NOT confuse with:** `ApplyCommand` (the framework's own command record, built from this by the binding).
/// **Guide:** `ARCHITECTURE-Skin.md` §3 (wire taxonomy) and §6 (correlation).
/// **Example:** `example/lib/mock/mock_agent.dart` (every scripted beat is one request).
/// **Cross-layer:** the target cell's own `TestCell` gate may reject the command after exposure accepts it.
/// **Minimal compilable example**
/// ```dart
/// final request = WireRequest(
///   cellId: 'home.living.thermostat',
///   function: 'setTarget',
///   positional: {'0': 21},
///   correlationId: 'srv-1',
///   clientCorrelationId: 'client-1',
/// );
/// ```
/// See also:
/// - [WireMessage]: The base class for all signals crossing the membrane.
/// - [WireResponse]: The envelope for the result of this request.
/// - [guide/HowTo-Cell.apply.md](guide/HowTo-Cell.apply.md): For the
///   complete "Command Journey" context.
/// {@category Wire Messages}
/// {@category Idempotency}
final class WireRequest extends WireMessage {

  /// The unique name of the cell that this request is trying to reach.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Address**.
  /// It tells the system exactly where on the **Skin Membrane** the
  /// **Nervous Signal** should enter to find its physical state.
  ///
  /// ### When to use
  /// - **Signal Routing**: Always include this in a [WireRequest] so the
  ///   system knows which cell should handle the command.
  /// - **Discovery**: Used by the transport layer to find the correct
  ///   **Integrity Gate** for the action.
  ///
  /// ### How it works
  /// 1. **Address Lookup**: The system takes this ID and looks for a matching
  ///    cell in its internal registry.
  /// 2. **Signal Delivery**: Once found, the envelope is opened, and the
  ///    instructions inside begin their **Command Journey** within that cell.
  ///
  /// ### Non‑obvious behavior
  /// - **Strict Mapping**: If this ID does not match any known cell, the
  ///   request is blocked at the membrane and returns a "not found" error.
  /// - **Forensic Identity**: This address is recorded in the
  ///   **Forensic Ledger**. This allows you to look at the history later
  ///   and see exactly which "body part" (cell) was affected by the signal.
  ///
  /// ### See also
  /// - [WireRequest.function]: The specific action to perform at this address.
  final String cellId;

  /// The name of the action or update to perform on the target cell.
  ///
  /// In the framework's biological metaphor, this is the **Instruction Type**
  /// of the **Nervous Signal**. It specifies which logic should be triggered
  /// once the signal passes through the **Skin Membrane**.
  ///
  /// ### When to use
  /// - **Command Identification**: Always include this in a [WireRequest]
  ///   so the system knows which specific behavior to run.
  /// - **Interface Binding**: Used to match an external request to an
  ///   internal function defined in the cell's binding set.
  ///
  /// ### How it works
  /// 1. **Signal Validation**: The system checks if the target cell has an
  ///    **Integrity Gate** or function that matches this name.
  /// 2. **Execution**: If a match is found, the data in the request is
  ///    unpacked and the cell begins its **Command Journey**.
  ///
  /// ### Non‑obvious behavior
  /// - **Strict Exposure**: Only functions explicitly "exposed" or bound
  ///   to the cell can be called. If you provide a name that isn't
  ///   registered, the request will be rejected at the membrane.
  /// - **Forensic Logging**: This name is recorded in the **Forensic Ledger**.
  ///   This allows you to see exactly which intent caused a
  ///   **Somatic State Transition** in the history log.
  ///
  /// ### See also
  /// - [WireRequest.cellId]: The address where this function is located.
  /// - [WireRequest.positional]: The data passed to this function.
  final String function;

  /// The data passed by position, stored as a string-keyed map for JSON safety.
  ///
  /// In the framework's biological metaphor, these are the **Numbered Nutrients**
  /// of the **Nervous Signal**. They provide the raw data required by the
  /// target function in a specific order.
  ///
  /// ### When to use
  /// - **Ordered Arguments**: Use this when the function you are calling
  ///   expects arguments in a specific sequence (e.g., `(name, age)`).
  /// - **Standard Tooling**: Used by most MCP and REST bridges to pass
  ///   primary data values.
  ///
  /// ### How it works
  /// 1. **Index Mapping**: Arguments are stored using their index as a
  ///    string key (e.g., `{"0": "Simon", "1": 30}`).
  /// 2. **Unpacking**: When the signal enters the cell, the framework
  ///    converts this map back into a list to execute the internal logic.
  ///
  /// ### Non‑obvious behavior
  /// - **JSON Stability**: We use a map `{"0": ...}` instead of a standard
  ///   JSON list `[...]` because some network parsers and AI models
  ///   accidentally reorder list items. Using string keys ensures the
  ///   **Command Journey** stays accurate.
  /// - **Forensic Recording**: These values are recorded in the
  ///   **Forensic Ledger**, allowing an auditor to see the exact data
  ///   that triggered a **Somatic State Transition**.
  ///
  /// ### Example
  /// ```dart
  /// // For a function like updateTemperature(double value)
  /// positional: {'0': 22.5}
  /// ```
  ///
  /// See also:
  /// - [WireRequest.named]: For data passed using specific labels.
  final Map<String, Object?>? positional;

  /// The data passed by name, allowing for tagged arguments.
  ///
  /// In the framework's biological metaphor, these are the **Labeled Nutrients**
  /// of the **Nervous Signal**. Unlike numbered arguments, these provide
  /// data using specific tags that the target function recognizes.
  ///
  /// ### When to use
  /// - **Tagged Arguments**: Use this when the function you are calling
  ///   expects data with specific names (e.g., `updateProfile(name: 'Simon')`).
  /// - **Optional Data**: Often used for optional settings or flags where
  ///   the order of the data does not matter.
  ///
  /// ### How it works
  /// 1. **Signal Tagging**: The client provides a map where each key is a
  ///    string matching a parameter name in the cell's function.
  /// 2. **Integrity Check**: The system verifies these tags against the
  ///    cell's **Integrity Gate** to ensure they are valid.
  /// 3. **Execution**: The framework passes these values as named arguments
  ///    when the **Command Journey** begins.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Visibility**: Every named argument is recorded in the
  ///   **Forensic Ledger**. This allows auditors to see exactly which
  ///   labeled signals caused a **Somatic State Transition**.
  /// - **Safety**: If you provide a name that the cell does not recognize,
  ///   the request will be rejected at the membrane before it can change
  ///   any internal state.
  ///
  /// ### Example
  /// ```dart
  /// // For a function like setStatus({required bool active})
  /// named: {'active': true}
  /// ```
  ///
  /// See also:
  /// - [WireRequest.positional]: For data passed by specific number/order.
  final Map<String, Object?>? named;

  /// The unique ID used to track a specific request through the system.
  ///
  /// In the framework's biological metaphor, this is the **Causal Link**.
  /// It acts as a unique tag on the **Nervous Signal** so that when a
  /// **Forensic Receipt** (the response) is generated, the system knows
  /// exactly which request it belongs to.
  ///
  /// ### When to use
  /// - **Response Matching**: Always required for requests so the
  ///   [SkinMembrane] can deliver the result back to the correct caller.
  /// - **Security**: Used by transport layers to ensure that one client
  ///   cannot "hijack" or see the response meant for another client.
  ///
  /// ### How it works
  /// 1. **Signal Tagging**: When a message hits the **Skin Membrane**, the
  ///    transport layer assigns this ID.
  /// 2. **Audit Tracking**: This ID travels with the signal throughout its
  ///    entire **Command Journey**.
  /// 3. **Ledger Pairing**: The [Forensic Ledger] uses this ID to pair the
  ///    initial request with the final [ApplyOutcome].
  ///
  /// ### Non‑obvious behavior
  /// - **Authoritative Identity**: This ID is assigned by the server or
  ///   transport layer, not the client. Even if a client provides their
  ///   own ID ([clientCorrelationId]), this `correlationId` remains the
  ///   "Source of Truth" for internal tracking.
  /// - **Persistence**: This ID is physically written into the
  ///   **Forensic Ledger**, allowing you to trace a state change back
  ///   to the specific network request that caused it.
  ///
  /// ### See also
  /// - [WireRequest.clientCorrelationId]: The ID chosen by the caller.
  /// - [WireResponse.correlationId]: The matching ID in the response.
  final String correlationId;

  /// An optional ID provided by the caller to identify the response on their end.
  ///
  /// In the framework's biological metaphor, this is an **External Echo**.
  /// It acts as a private label placed on the **Nervous Signal** by the
  /// caller. The system carries this label throughout the **Command Journey**
  /// and returns it untouched.
  ///
  /// ### When to use
  /// - **Client-Side Tracking**: Use this if your client application needs
  ///   to match an incoming response to a specific local action or UI update.
  /// - **Async Coordination**: Helpful when a client sends many requests
  ///   simultaneously and needs to know which one just finished.
  ///
  /// ### How it works
  /// 1. **Signal Tagging**: The client provides this string when the
  ///    [WireRequest] is sent.
  /// 2. **Passthrough**: The system ignores this field for its internal
  ///    logic but keeps it attached to the signal.
  /// 3. **Reflection**: When the final **Forensic Receipt** ([WireResponse])
  ///    is generated, this ID is copied back into the response envelope.
  ///
  /// ### Non‑obvious behavior
  /// - **No Authority**: The system **never** uses this field for internal
  ///   matching, security, or state logic. The [correlationId] remains
  ///   the only "Source of Truth" for the **Forensic Ledger**.
  /// - **Optional**: If this field is left empty, the system will still
  ///   process the request normally.
  /// - **Verbatim Echo**: The framework returns this string exactly as it
  ///   was received, even if the request is rejected by an **Integrity Gate**.
  ///
  /// ### See also
  /// - [WireRequest.correlationId]: The authoritative ID used by the server.
  /// - [WireResponse.clientCorrelationId]: Where this ID appears in the result.
  final String? clientCorrelationId;

  /// The sequence number of the last entry the caller saw in the **Forensic Ledger**.
  ///
  /// In the framework's biological metaphor, this is the **Forensic Sync Marker**.
  /// It acts as a somatic cursor, telling the system exactly which version of the
  /// cell's "DNA" the caller was looking at when they sent the signal.
  ///
  /// ### When to use
  /// - **Strict Synchronization**: Use this when your application requires a
  ///   "Strict Cursor" to prevent updates based on old data.
  /// - **Data Integrity**: Required for specific cell bindings to ensure that
  ///   the caller is in sync with the latest **Somatic State Transition**.
  ///
  /// ### How it works
  /// 1. **Sequence Check**: When the [WireRequest] hits the membrane, the
  ///    system compares this number to the current ledger sequence.
  /// 2. **Integrity Gate**: If the numbers do not match (meaning the caller is
  ///    out of sync), the **Integrity Gate** blocks the command.
  /// 3. **Rejection**: The system returns a [WireError] so the caller knows
  ///    they must refresh their state before trying again.
  ///
  /// ### Non‑obvious behavior
  /// - **Stale Update Prevention**: This field is the primary defense against
  ///   "Race Conditions." It ensures a request doesn't accidentally overwrite
  ///   changes that happened while the signal was traveling over the wire.
  /// - **Stateless Nature**: Even if the transport layer (like REST) is
  ///   stateless, this marker provides a stateful guarantee for the
  ///   **Command Journey**.
  /// - **Forensic Traceability**: The ledger records this sequence to prove
  ///   that the caller was correctly synchronized at the time of the action.
  ///
  /// ### See also
  /// - [WireLedgerEntry]: The envelope that carries these sequence numbers.
  /// - [ApplyOutcome]: How the system reports if a cursor check failed.
  final int? lastSeenSeq;

  /// The instant after which a request that is still queued must not
  /// start.
  ///
  /// Queue metadata, not part of the command: `toJson`/`fromJson` ignore
  /// it (a round-trip drops it), and it never enters an idempotency
  /// fingerprint. The router checks it once, before `apply`; a request
  /// that is still queued when the deadline passes is `queue_timeout`
  /// (HTTP 504) and does not run. A handler timeout while `apply` is
  /// running stays `outcome_unknown` — the command keeps running.
  final DateTime? deadline;

  /// Creates a new [WireRequest] envelope to carry a signal into the system.
  ///
  /// In the framework's biological metaphor, this constructor assembles the
  /// **Nervous Signal** envelope. It prepares the data needed to cross the
  /// **Skin Membrane** and begin a **Command Journey**.
  ///
  /// ### When to use
  /// - **Transport Adapters**: Use this when writing code for MCP tools, REST
  ///   endpoints, or custom network listeners to wrap incoming data.
  /// - **Testing**: Use this to simulate external requests during integration
  ///   tests of the governance layer.
  ///
  /// ### How it works
  /// The constructor simply bundles the somatic address ([cellId]), the
  /// instruction ([function]), and the causal metadata into a stable,
  /// immutable record. This record is then vetted by the membrane before
  /// being converted into a framework command.
  ///
  /// ### Parameters
  /// - **cellId**: The name of the cell this signal is trying to reach.
  /// - **function**: The name of the update or action to perform.
  /// - **positional**: Optional data passed by order (e.g., first argument, second argument).
  /// - **named**: Optional data passed using specific labels.
  /// - **correlationId**: The unique ID used by the system to track this signal
  ///   in the **Forensic Ledger**.
  /// - **clientCorrelationId**: An optional label provided by the caller to help
  ///   them identify the response.
  /// - **lastSeenSeq**: An optional marker to ensure the caller has the
  ///   latest data before they try to change the state.
  const WireRequest({
    required this.cellId,
    required this.function,
    this.positional,
    this.named,
    required this.correlationId,
    this.clientCorrelationId,
    this.lastSeenSeq,
    this.deadline,
  });

  /// The stable identifier used to distinguish this message type on the wire.
  ///
  /// In the framework's biological metaphor, this is the **Signal Label**.
  /// It tells the **Skin Membrane** exactly what kind of **Nervous Signal**
  /// is inside the envelope so it can be routed correctly.
  ///
  /// ### When to use
  /// - **Polymorphic Decoding**: The [WireMessage.fromJson] factory uses
  ///   this value to decide which specific class to create.
  /// - **Network Routing**: External tools (like MCP hosts or REST proxies)
  ///   use this field to filter or log messages by category.
  ///
  /// ### How it works
  /// This getter always returns the string `'request'`. When [toJson] is
  /// called, this label is stamped into the JSON payload, ensuring the
  /// receiver knows how to open the envelope.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Identity**: The **Forensic Ledger** uses this label to
  ///   categorize incoming impulses. A `request` is treated as a potential
  ///   trigger for a **Somatic State Transition**, whereas a `notification`
  ///   might not be.
  /// - **Strict Value**: This value is fixed and must not be changed. The
  ///   entire signaling protocol relies on this specific string to maintain
  ///   compatibility between the skin and the core reactive graph.
  ///
  /// ### See also
  /// - [WireMessage.kind]: The base definition for all message labels.
  @override
  String get kind => 'request';

  @override
  Map<String, Object?> toJson() => withWire({
        'kind': kind,
        'cellId': cellId,
        'function': function,
        if (positional != null) 'positional': positional,
        if (named != null) 'named': named,
        'correlationId': correlationId,
        if (clientCorrelationId != null)
          'clientCorrelationId': clientCorrelationId,
        if (lastSeenSeq != null) 'lastSeenSeq': lastSeenSeq,
      });

  /// Decodes a raw JSON map into a [WireRequest] envelope.
  ///
  /// In the framework's biological metaphor, this factory acts as the
  /// **Signal Decoder** at the **Skin Membrane**. It takes raw data
  /// from the outside world and translates it into a structured
  /// **Nervous Signal** that the system can understand.
  ///
  /// ### When to use
  /// - **Transport Adapters**: Use this when your web server (REST),
  ///   AI tool (MCP), or network listener receives a JSON message
  ///   intended to trigger a cell action.
  /// - **Data Ingress**: The primary entry point for turning external
  ///   strings and numbers into a formal request.
  ///
  /// ### How it works
  /// 1. **Field Extraction**: It looks for keys like `cellId` and `function`.
  /// 2. **Type Casting**: It converts raw JSON types into the specific
  ///    types required by the [WireRequest] (e.g., ensuring IDs are strings).
  /// 3. **Argument Mapping**: It safely casts the `positional` and `named`
  ///    argument maps to ensure they are ready for the **Integrity Gate**.
  ///
  /// ### Non‑obvious behavior
  /// - **JSON Stability**: If positional arguments arrive as a list, they
  ///   must be converted to a map (e.g., `{"0": value}`) before calling
  ///   this factory. This ensures the order of the **Command Journey**
  ///   is never lost by accident.
  /// - **Null Safety**: Optional fields like [clientCorrelationId] and
  ///   [lastSeenSeq] are handled safely. If they are missing in the JSON,
  ///   they will be `null` in the resulting object.
  ///
  /// ### Forensic Integrity
  /// This factory is the first line of defense. By strictly validating
  /// the JSON structure here, the system prevents "malformed signals"
  /// from ever reaching the **Forensic Ledger**.
  ///
  /// ### See also
  /// - [WireRequest.toJson]: The reverse process of turning a request into JSON.
  /// - [WireMessage.fromJson]: The top-level factory that decides which kind
  ///   of message to decode.
  factory WireRequest.fromJson(Map<String, Object?> json) => WireRequest(
        cellId: json['cellId'] as String,
        function: json['function'] as String,
        positional: (json['positional'] as Map?)?.cast<String, Object?>(),
        named: (json['named'] as Map?)?.cast<String, Object?>(),
        correlationId: json['correlationId'] as String,
        clientCorrelationId: json['clientCorrelationId'] as String?,
        lastSeenSeq: json['lastSeenSeq'] as int?,
      );
}

/// An envelope for an outbound result: the official response to a request.
///
/// In the framework's biological metaphor, [WireResponse] is the
/// **Forensic Receipt** delivered to the **Skin Membrane**. It proves
/// that a **Nervous Signal** completed its **Command Journey** and
/// reports whether it was accepted or rejected by the system's DNA.
///
/// ### When to use
/// - **Request Completion**: Use this as the standard reply to a [WireRequest].
/// - **Transport Mapping**: Use this to send the results of a command
///   back to a web client (REST) or an AI agent (MCP).
///
/// ### How it works
/// 1. **Signal Outcome**: The system takes the [ApplyOutcome] from the
///    internal cell and packages it into this envelope.
/// 2. **Correlation**: It attaches the [correlationId] so the caller
///    can match this receipt to their original request.
/// 3. **Ledger Synchronization**: If the framework is still writing the
///    result to the permanent log, the response is marked as [pendingReceipt].
///
/// ### Non‑obvious behavior
/// - **Serialization Guard**: A live [ApplyOutcome] contains functions
///   and complex logic that cannot be sent over the wire. Therefore,
///   decoded responses store the result as [outcomeJson] instead.
/// - **Definitive Receipts**: If [pendingReceipt] is `true`, the outcome
///   provided is a "best guess." The final, authoritative proof only
///   arrives later via the **Forensic Ledger** stream.
/// - **Authoritative Outcome**: A [WireResponse] never reports transport
///   failures (like a lost connection); those are handled by [WireError].
///   This class only reports the cell's actual logic results.
///
/// ### See also
/// - [WireRequest]: The signal that triggered this response.
/// - [WireOutcome]: The specific JSON format of the result.
/// - [ApplyOutcome]: The internal framework result being wrapped.
/// - [guide/HowTo-Cell.apply.md](guide/HowTo-Cell.apply.md): For the
///   complete "Command Journey" context.
///
/// ### AI Agent Guide
/// **Layer:** Skin — the reply to a [WireRequest].
/// **When to use:** answering a `request()` — `outcome` (live),
/// `outcomeJson` (decoded), or `pendingReceipt` for an accepted pulse
/// whose entry has not landed.
/// **When NOT to use:** streaming state — [WireStateChange]; failures —
/// [WireError].
/// **Live signature:** `const WireResponse({required String correlationId, String? clientCorrelationId, ApplyOutcome<Object?>? outcome, WireOutcome? outcomeJson, bool pendingReceipt = false, Map<String, Object?>? receiptJson, List<int>? ledgerSeqs})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
final class WireResponse extends WireMessage {

  /// The unique ID that links this response to the request that started it.
  ///
  /// In the framework’s biological metaphor, this is the **Causal Link**. It
  /// acts as a unique tag that pairs a **Forensic Receipt** (this response)
  /// with the **Nervous Signal** (the request) that triggered the action.
  ///
  /// ### When to use
  /// - **Response Matching**: Use this to find out which specific command
  ///   just finished, especially when many actions are happening at once.
  /// - **Auditing**: Use this to trace a result back to the original network
  ///   signal in the logs.
  ///
  /// ### How it works
  /// 1. **Signal Tagging**: Every request enters the system with a unique ID.
  /// 2. **Journey Tracking**: That ID follows the signal through the entire
  ///    **Command Journey**.
  /// 3. **Receipt Echo**: When the cell finishes its work, it copies the ID
  ///    into this field so the caller knows the "Nervous Signal" has returned.
  ///
  /// ### Non‑obvious behavior
  /// - **Source of Truth**: This ID is the official identifier used by the
  ///   **Forensic Ledger**. Even if a client provides their own private ID,
  ///   this `correlationId` is what the system uses to prove a **Somatic
  ///   State Transition** happened.
  /// - **Reliability**: Because it is echoed directly from the request, it
  ///   guarantees that the response is legally tied to the correct impulse.
  ///
  /// ### See also
  /// - [WireRequest.correlationId]: The ID as it first enters the system.
  /// - [WireResponse.clientCorrelationId]: The optional private label from
  ///   the caller.
  final String correlationId;

  /// An optional ID provided by the caller to help them identify the response
  /// on their end.
  ///
  /// In the framework’s biological metaphor, this is an **External Echo**.
  /// It acts as a private label placed on the **Nervous Signal** by the
  /// caller. The system carries this label throughout the **Command Journey**
  /// and returns it untouched in this response.
  ///
  /// ### When to use
  /// - **Client-Side Tracking**: Use this if your client application needs
  ///   to match an incoming response to a specific local action or UI update.
  /// - **Async Coordination**: Helpful when a client sends many requests
  ///   at once and needs to know which one just finished.
  ///
  /// ### How it works
  /// 1. **Signal Tagging**: The client provides this string when the
  ///    [WireRequest] is first sent.
  /// 2. **Passthrough**: The system ignores this field for its internal
  ///    governance but keeps it attached to the signal.
  /// 3. **Reflection**: When the final **Forensic Receipt** ([WireResponse])
  ///    is generated, this ID is copied back into the envelope.
  ///
  /// ### Non‑obvious behavior
  /// - **No Internal Authority**: The system **never** uses this field for
  ///   internal matching, security, or state logic. The [correlationId]
  ///   remains the only "Source of Truth" for the **Forensic Ledger**.
  /// - **Verbatim Echo**: The framework returns this string exactly as it
  ///   was received, even if the request was rejected by an **Integrity Gate**.
  /// - **Optional**: If this field is left empty in the request, it will be
  ///   `null` here.
  ///
  /// ### See also
  /// - [WireRequest.clientCorrelationId]: Where this label is first applied.
  /// - [WireResponse.correlationId]: The authoritative ID used by the server.
  final String? clientCorrelationId;

  /// The live internal result produced by the target cell.
  ///
  /// In the framework's biological metaphor, this is the **Live Forensic
  /// Receipt**. It represents the finalized state of the **Nervous Signal**
  /// immediately after it completes its **Command Journey**.
  ///
  /// ### When to use
  /// - **Internal Processing**: Use this when you are working with a response
  ///   locally within the Dart process to check if an action succeeded.
  /// - **Direct Access**: Use this to access the typed result and metadata
  ///   of an [ApplyOutcome] before it is converted to JSON.
  ///
  /// ### How it works
  /// This field captures the exact [ApplyOutcome] returned by the cell's
  /// `apply` method. It identifies whether the transition was **Accepted**,
  /// **Rejected** (by an **Integrity Gate**), or **Staged** (in a transaction).
  ///
  /// ### Non‑obvious behavior
  /// - **Serialization Boundary**: This property is only available in "live"
  ///   responses. Because an [ApplyOutcome] can contain functions and complex
  ///   logic, it cannot survive a trip across the wire.
  /// - **Decoded Nullability**: If this [WireResponse] was created from JSON
  ///   (using [WireResponse.fromJson]), this field will be `null`. In that
  ///   case, you must use [outcomeJson] to see the data.
  /// - **Pending States**: If [pendingReceipt] is `true`, this outcome
  ///   represents the current status before the **Forensic Ledger** has
  ///   permanently finished writing the record.
  ///
  /// ### See also
  /// - [ApplyOutcome]: The internal framework result being carried.
  /// - [WireResponse.outcomeJson]: The wire-safe version of this result.
  final ApplyOutcome<Object?>? outcome;

  /// The wire-safe JSON version of the cell's result.
  ///
  /// In the framework’s biological metaphor, this is the **Skin Form** of the
  /// **Forensic Receipt**. While the [outcome] property holds a live object
  /// inside the system, this property holds a simplified version that is safe
  /// to send over the network (the "Wire").
  ///
  /// ### When to use
  /// - **Network Responses**: Use this when you are writing a client (like a
  ///   web app or an AI tool) that receives a response over a network.
  /// - **Data Inspection**: Use this to read the results of a **Command Journey**
  ///   without needing access to the original live cell objects.
  ///
  /// ### How it works
  /// 1. **Serialization**: When a response leaves the system, the framework
  ///    converts the live result into a plain JSON map.
  /// 2. **Decoding**: When [WireResponse.fromJson] is called, it places the
  ///    result data here.
  /// 3. **Result Access**: You can then check this object to see if the
  ///    original **Nervous Signal** was accepted or rejected.
  ///
  /// ### Non‑obvious behavior
  /// - **Mutually Exclusive**: If this field is filled, the live [outcome]
  ///   field will be `null`. You only use [outcomeJson] for responses that
  ///   have traveled across the **Skin Membrane**.
  /// - **Information Loss**: Because this is a simplified copy, it does not
  ///   contain the actual Dart functions or live references that were part of
  ///   the original **Somatic State Transition**.
  /// - **Pending States**: If [pendingReceipt] is `true`, this field is
  ///   usually `null` because the final result hasn't been written to the
  ///   **Forensic Ledger** yet.
  ///
  /// ### See also
  /// - [WireOutcome]: The data structure used for JSON results.
  /// - [WireResponse.outcome]: The live version of this result.
  /// - [WireResponse.fromJson]: The factory that populates this field.
  final WireOutcome? outcomeJson;

  /// Whether the permanent record for this change is still being written to the ledger.
  ///
  /// In the framework’s biological metaphor, this indicates a **Signal in Transit**.
  /// It means the **Nervous Signal** was accepted by the cell, but the
  /// **Somatic State Transition** has not yet finished landing in the
  /// **Forensic Ledger**.
  ///
  /// ### When to use
  /// - **Optimistic UI**: Use this to show a "pending" or "sending" state in
  ///   your application while waiting for the final authoritative proof.
  /// - **Forensic Integrity**: Check this to determine if the provided
  ///   [outcome] is final or if a later confirmation is expected.
  ///
  /// ### How it works
  /// 1. **Signal Acceptance**: The cell processes the command and returns an
  ///    immediate result.
  /// 2. **Ledger Staging**: If the ledger write is asynchronous, the system
  ///    sets this field to `true`.
  /// 3. **Finalization**: Once the write is complete, a separate
  ///    [WireLedgerEntry] is typically sent to confirm the permanent sequence.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Holes**: If this is `true`, the outcome provided is a "best
  ///   guess" based on the current impulse. The final, authoritative proof
  ///   only exists once it is assigned a sequence number in the ledger.
  /// - **Authoritative Conflict**: If a network error occurs while this is
  ///   `true`, the client must treat the state as "uncertain" until the
  ///   **Forensic Ledger** can be resynchronized.
  /// - **Default State**: In a standard authoritative response, this is
  ///   `false`, meaning the change is already physically committed.
  ///
  /// ### See also
  /// - [WireResponse.receiptJson]: A snapshot of the state while the receipt
  ///   is pending.
  /// - [WireLedgerEntry]: The envelope that carries the final, non-pending
  ///   confirmation.
  final bool pendingReceipt;

  /// A snapshot of the last known state of the ledger receipt for this cell.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Snapshot**.
  /// It provides a "best-effort" look at the cell's physical standing while the
  /// official **Forensic Receipt** is still being written to the ledger.
  ///
  /// ### When to use
  /// - **Pending Feedback**: Use this when [pendingReceipt] is `true` to
  ///   provide the caller with immediate, albeit unconfirmed, state data.
  /// - **Synchronization**: Helpful for clients to determine if they need to
  ///   re-fetch the full state after a **Command Journey** completes.
  ///
  /// ### How it works
  /// 1. **Capture**: If a receipt is available (even if it belongs to a
  ///    previous change or is currently being staged), it is serialized
  ///    into this map.
  /// 2. **Verification**: Once the ledger write is final, the authoritative
  ///    [WireLedgerEntry] will contain the verified version of this data.
  ///
  /// ### Non‑obvious behavior
  /// - **Nullability**: This field is `null` if no receipt has ever been
  ///   seen for the target cell (e.g., a brand new cell that has never
  ///   been physically committed).
  /// - **Unconfirmed Data**: When [pendingReceipt] is `true`, the data here
  ///   is not yet legally part of the **Forensic Ledger**. It should be
  ///   treated as a "guess" until the ledger sequence is assigned.
  /// - **Stale State**: In rare race conditions, this could reflect a
  ///   state slightly older than the current impulse if the somatic
  ///   anchoring hasn't updated yet.
  ///
  /// ### See also
  /// - [WireResponse.pendingReceipt]: The flag indicating if this snapshot
  ///   is still unconfirmed.
  /// - [WireReceipt]: The internal structure represented by this JSON map.
  final Map<String, Object?>? receiptJson;

  /// The sequence numbers of the ledger rows this apply covered, in
  /// ascending order.
  ///
  /// For a `SkinBinding.state` apply this is the single row whose receipt
  /// id equals the outcome's receipt id. For a `SkinBinding.command`
  /// (e.g. a `txApply` batch) it is every inner row, while the outer
  /// receipt is not a row. Omitted (null) when nothing was written — a
  /// domain rejection appends nothing.
  final List<int>? ledgerSeqs;

  /// Creates a new [WireResponse] envelope to carry a result back through the membrane.
  ///
  /// In the framework’s biological metaphor, this constructor assembles the
  /// **Forensic Receipt**. It marks the end of a **Command Journey** and
  /// provides the proof needed to satisfy the caller's initial **Nervous Signal**.
  ///
  /// ### When to use
  /// - **Completing a Request**: Use this when a cell has finished processing
  ///   an `apply` command and you need to send the [ApplyOutcome] back to the
  ///   originating transport (MCP, REST, etc.).
  /// - **Testing**: Use this to simulate authoritative or pending responses
  ///   in integration tests.
  ///
  /// ### How it works
  /// The constructor bundles the outcome of the state transition with causal
  /// metadata. It enforces a strict **Integrity Guard** via an assertion:
  /// a response must either be a placeholder for a ledger write in progress
  /// ([pendingReceipt]), or it must contain a concrete result ([outcome] or [outcomeJson]).
  ///
  /// ### Parameters
  /// - **correlationId**: The authoritative **Causal Link** used to pair this
  ///   receipt with the original request.
  /// - **clientCorrelationId**: The **External Echo** provided by the caller.
  /// - **outcome**: The **Live Forensic Receipt** generated by the cell
  ///   (used for internal/Dart-native responses).
  /// - **outcomeJson**: The **Skin Form** of the result (used for responses
  ///   decoded from the wire).
  /// - **pendingReceipt**: Indicates if the **Somatic State Transition** is
  ///   still being written to the **Forensic Ledger**.
  /// - **receiptJson**: A **Somatic Snapshot** of the ledger state, providing
  ///   immediate context while a receipt is pending.
  ///
  /// ### Non‑obvious behavior
  /// - **Authoritative Invariant**: You cannot create a non-pending response
  ///   without providing an outcome. This prevents "Forensic Holes" where a
  ///   command appears to finish without leaving a trace or result.
  /// - **Mutual Exclusivity**: While the constructor allows both, typically
  ///   either [outcome] (live) or [outcomeJson] (wire) is used, depending
  ///   on which side of the **Skin Membrane** the code is running.
  const WireResponse({
    required this.correlationId,
    this.clientCorrelationId,
    this.outcome,
    this.outcomeJson,
    this.pendingReceipt = false,
    this.receiptJson,
    this.ledgerSeqs,
  }) : assert(
          pendingReceipt || outcome != null || outcomeJson != null,
          'WireResponse: outcome == null requires pendingReceipt or '
          'a decoded outcomeJson',
        );

  /// The stable identifier used to distinguish this message type on the wire.
  ///
  /// In the framework's biological metaphor, this is the **Signal Label**.
  /// It tells the **Skin Membrane** that this envelope contains a
  /// **Forensic Receipt** (a response) rather than an incoming command
  /// or a simple observation.
  ///
  /// ### When to use
  /// - **Polymorphic Decoding**: The [WireMessage.fromJson] factory uses
  ///   this value to decide which specific class to create.
  /// - **Network Routing**: External tools (like MCP hosts or REST proxies)
  ///   use this field to filter or log messages by category.
  ///
  /// ### How it works
  /// This getter always returns the string `'response'`. When [toJson] is
  /// called, this label is stamped into the JSON payload, ensuring the
  /// receiver knows that a **Command Journey** has concluded.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Identity**: The **Forensic Ledger** uses this label to
  ///   categorize outcomes. A `response` is the official record of an
  ///   accepted or rejected impulse.
  /// - **Strict Value**: This value is fixed. The entire signaling protocol
  ///   relies on this specific string to maintain compatibility between the
  ///   skin membrane and external clients.
  ///
  /// ### See also
  /// - [WireMessage.kind]: The base definition for all message labels.
  @override
  String get kind => 'response';

  /// Converts the response into a JSON-safe map for transport.
  ///
  /// In the framework's biological metaphor, this method creates the
  /// **Skin Form** of the response. It applies the final **Forensic Stamp**
  /// to the envelope, proving that a **Command Journey** has successfully
  /// returned to the **Skin Membrane**.
  ///
  /// ### When to use
  /// - **Egress**: Use this when a server, MCP host, or bridge needs to
  ///   serialize a result to send it over the wire to a client.
  /// - **Persistence**: Used to store a snapshot of a response in a
  ///   transport-level log.
  ///
  /// ### How it works
  /// 1. **Signal Labeling**: It includes the [kind] ('response') so the
  ///    receiver knows how to decode the envelope.
  /// 2. **Causal Mapping**: It embeds the [correlationId] to ensure the
  ///    **Forensic Receipt** can be matched to the original request.
  /// 3. **Outcome Encoding**: It converts the internal [ApplyOutcome] into
  ///    a simplified JSON structure via `wireOutcomeJson`.
  /// 4. **Status Flagging**: It marks whether the result is a finalized
  ///    ledger entry or a [pendingReceipt].
  ///
  /// ### Non‑obvious behavior
  /// - **Serialization Guard**: If a live [outcome] object exists, it is
  ///   transformed into a wire-safe format. If the object was already
  ///   decoded from JSON, [outcomeJson] is used instead to avoid
  ///   double-encoding.
  /// - **Echo Preservation**: The [clientCorrelationId] (the **External Echo**)
  ///   is included exactly as it was received in the request, ensuring the
  ///   caller can recognize their own signal.
  /// - **Authoritative Identity**: The resulting map is the only version of
  ///   the response that is legal to transmit across the system membrane.
  ///
  /// ### See also
  /// - [WireResponse.fromJson]: The reverse process for decoding signals.
  /// - [wireOutcomeJson]: The utility that prepares the forensic result
  ///   for the wire.
  @override
  Map<String, Object?> toJson() => withWire({
        'kind': kind,
        'correlationId': correlationId,
        if (clientCorrelationId != null)
          'clientCorrelationId': clientCorrelationId,
        if (outcome != null) 'outcome': wireOutcomeJson(outcome!),
        if (outcomeJson != null) 'outcome': outcomeJson!.toJson(),
        'pendingReceipt': pendingReceipt,
        if (receiptJson != null) 'receipt': receiptJson,
        if (ledgerSeqs != null && ledgerSeqs!.isNotEmpty)
          'ledgerSeqs': ledgerSeqs,
      });

  /// Decodes a raw JSON map into a [WireResponse] envelope.
  ///
  /// In the framework's biological metaphor, this factory acts as the
  /// **Signal Decoder** at the **Skin Membrane**. It takes the raw
  /// **Forensic Stamp** received from the wire and translates it into a
  /// format the local system can read.
  ///
  /// ### When to use
  /// - **Egress Processing**: Use this when a client (AI agent, web app, or
  ///   Dart client) receives a result from a remote cell.
  /// - **Testing**: Use this to verify that a serialized response matches
  ///   the expected forensic output.
  ///
  /// ### How it works
  /// 1. **Causal Mapping**: It extracts the [correlationId] to ensure the
  ///    receipt can be matched to the original impulse.
  /// 2. **Outcome Translation**: It converts the JSON payload into a
  ///    [WireOutcome].
  /// 3. **Live Guard**: Because a live [ApplyOutcome] cannot survive the
  ///    trip across the wire, the [outcome] property is left `null`.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Holes**: If the incoming JSON lacks a result and is not
  ///   marked as [pendingReceipt], this factory will produce an object
  ///   that fails the internal **Integrity Guard** assertion.
  /// - **Somatic Snapshots**: If the response was sent while a ledger write
  ///   was in flight, [receiptJson] is captured to provide the last
  ///   known state of the cell's "DNA".
  /// - **Type Safety**: It strictly casts positional and named argument
  ///   maps to ensure the **Command Journey** data remains stable.
  ///
  /// ### See also
  /// - [WireResponse.toJson]: The reverse process for sending receipts.
  /// - [WireOutcome.fromJson]: How the result data itself is decoded.
  factory WireResponse.fromJson(Map<String, Object?> json) => WireResponse(
        correlationId: json['correlationId'] as String,
        clientCorrelationId: json['clientCorrelationId'] as String?,
        outcomeJson: json['outcome'] == null
            ? null
            : WireOutcome.fromJson(
                (json['outcome'] as Map).cast<String, Object?>()),
        pendingReceipt: json['pendingReceipt'] as bool? ?? false,
        receiptJson: (json['receipt'] as Map?)?.cast<String, Object?>(),
        ledgerSeqs: (json['ledgerSeqs'] as List?)?.cast<int>(),
      );
}

/// An outbound observation signal indicating that a cell's physical state has changed.
///
/// In the framework's biological metaphor, [WireStateChange] is a
/// **Somatic Observation**. Unlike a [WireResponse], which is a direct reply to
/// a command, this is an unsolicited **Nervous Impulse** broadcast to the
/// environment (observers) whenever a **Somatic State Transition** occurs.
///
/// ### When to use
/// - **State Streaming**: Use this to push updates to external observers via
///   SSE (`/skin/observe/:cellId`), MCP notifications, or `SkinClient.observe`.
/// - **UI Reactivity**: Use this to keep external dashboards or AI agents
///   synchronized with the live graph.
///
/// ### How it works
/// - **Ledger-Driven**: When a **Forensic Ledger** is bound, this signal is
///   triggered by the ledger's tail. The [receipt] is the authoritative proof
///   of the change.
/// - **Volatile Changes**: If no ledger is bound, the signal is sent
///   immediately, but [pendingReceipt] is always `true` because there is no
///   permanent "DNA" record of the event.
///
/// ### Non‑obvious behavior
/// - **No Correlation**: This signal never carries a `correlationId`. It is
///   an observation of the system's state, not a reply to a specific
///   **Command Journey**.
/// - **Authoritative Proof**: If [pendingReceipt] is `false`, the change is
///   guaranteed to be written in the **Forensic Ledger**. If `true`, it is a
///   "live" observation that has not yet landed in the permanent record.
///
/// ### See also
/// - [WireResponse]: A signal sent as a direct reply to a request.
/// - [WireLedgerEntry]: The complete audit row for a ledgered change.
/// - [WireReceipt]: The forensic evidence of the state transition.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is an observation, not a command reply.
/// **When to use:** streaming target state changes to observers (SSE, MCP notifications, Dart clients).
/// **When NOT to use:** completing a request — it has no correlation id; replies are [WireResponse] or [WireError].
/// **Live signature:** `const WireStateChange({required String cellId, Object? payload, WireReceipt? receipt, bool pendingReceipt = false})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Do NOT confuse with:** `WireResponse.pendingReceipt` (an accepted pulse whose entry is pending), or `WireLedgerEntry` (the audit row itself).
/// **Guide:** `ARCHITECTURE-Skin.md` §4 (receipt provenance).
/// **Example:** `example/lib/widgets/home_pane.dart` (the thermostat readout observes this variant).
/// **Cross-layer:** the payload is the cell's value — its meaning belongs to the domain cell, not the skin.
/// **Minimal compilable example**
/// ```dart
/// final change = WireStateChange(
///   cellId: 'home.living.thermostat',
///   payload: 21,
///   pendingReceipt: true, // no ledger bound — no receipt exists
/// );
/// ```
/// {@category Egress}
final class WireStateChange extends WireMessage {

  /// The unique name of the cell that has changed.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Address**.
  /// It identifies the physical location in the reactive graph where the
  /// **Somatic State Transition** occurred.
  ///
  /// ### When to use
  /// - **Event Routing**: Used by external observers (like UI dashboards or
  ///   AI agents) to filter for updates from specific parts of the system.
  /// - **State Synchronization**: Used to determine which local "Phenotype"
  ///   needs to be updated when an observation arrives.
  ///
  /// ### How it works
  /// 1. **Emission**: When a cell's value changes, the system broadcasts this
  ///    address as part of the observation signal.
  /// 2. **Observation**: Subscribers to the **Skin Membrane** use this ID to
  ///    route the new [payload] to the correct listener.
  ///
  /// ### Non‑obvious behavior
  /// - **Stateless Signals**: Unlike a [WireResponse], this field is not
  ///   correlated to a specific request. It is a broadcast of a physical
  ///   event that has already happened at this address.
  /// - **Forensic Identity**: This address matches the entry recorded in the
  ///   **Forensic Ledger**, allowing auditors to link live updates to
  ///   permanent audit rows.
  ///
  /// ### See also
  /// - [WireStateChange.payload]: The new value associated with this address.
  /// - [WireStateChange.receipt]: The forensic proof of the change at this address.
  final String cellId;

  /// The new state value of the cell, provided as a JSON-serializable object.  ///
  /// In the framework's biological metaphor, this is the **Phenotype**. It
  /// represents the observable traits of the cell immediately following a
  /// **Somatic State Transition**.
  ///
  /// ### When to use
  /// - **UI Updates**: Use this to reflect the latest state of a cell in a
  ///   dashboard or view.
  /// - **External Logic**: Used by AI agents or external systems to react to
  ///   data changes without querying the **Forensic Ledger**.
  ///
  /// ### How it works
  /// 1. **Capture**: When a cell value changes, the framework attempts to
  ///    serialize the new value.
  /// 2. **Broadcasting**: This value is wrapped as the payload of a
  ///    **Nervous Impulse** ([WireStateChange]) and pushed through the
  ///    **Skin Membrane**.
  ///
  /// ### Non‑obvious behavior
  /// - **Omission on Failure**: If a value cannot be encoded into JSON, this
  ///   field is omitted (set to `null`). In such cases, the observer should
  ///   refer to the [receipt] or the ledger entry for the authoritative data.
  /// - **Volatile State**: When [pendingReceipt] is `true`, this payload
  ///   represents an unconfirmed "live" state that has not yet been physically
  ///   committed to the permanent ledger.
  /// - **Forensic Separation**: While this field is convenient for live
  ///   reactivity, the [receipt] remains the only legal proof of the
  ///   underlying state change.
  ///
  /// ### See also
  /// - [WireStateChange.cellId]: The somatic address where this phenotype exists.
  /// - [WireStateChange.receipt]: The forensic evidence confirming this value.
  final Object? payload;

  /// The forensic evidence for the state change, if available.
  ///
  /// In the framework's biological metaphor, this is the **Forensic Receipt**.
  /// It provides the official proof from the **Forensic Ledger** that a
  /// **Somatic State Transition** has been physically recorded in the
  /// system's "DNA."
  ///
  /// ### When to use
  /// - **Verification**: Use this to confirm the sequence number, timestamp,
  ///   and authoritative signature of the cell's physical state.
  /// - **Audit Trails**: Essential for AI agents or external systems that
  ///   need to maintain a perfect, chronological record of the system's evolution.
  ///
  /// ### How it works
  /// 1. **Capture**: When a change is committed to the permanent ledger, a
  ///    receipt is generated.
  /// 2. **Broadcasting**: This receipt is attached to the [WireStateChange]
  ///    **Nervous Impulse** to serve as proof for all observers.
  ///
  /// ### Non‑obvious behavior
  /// - **Pending States**: If [pendingReceipt] is `true`, this receipt usually
  ///   represents the *previous* known transition. It is included to provide
  ///   the last known authoritative context while the new impulse is still
  ///   being ledgered.
  /// - **Never Fabricated**: The system never creates "fake" receipts. If
  ///   the ledger has never recorded a change for this cell (e.g., in a
  ///   volatile system), this field will be `null`.
  /// - **Sequence Authority**: The sequence number inside this receipt is
  ///   the only legal way to determine the global order of events across
  ///   the entire somatic graph.
  ///
  /// ### See also
  /// - [WireStateChange.pendingReceipt]: The flag indicating if the current
  ///   impulse is still waiting for its own receipt.
  /// - [WireReceipt]: The detailed structure of the forensic evidence.
  final WireReceipt? receipt;

  /// Whether the permanent record for this change is still being written to the ledger.
  ///
  /// In the framework’s biological metaphor, this indicates a **Signal in Transit**.
  /// It means the **Somatic State Transition** has occurred in the living cell, but
  /// the event has not yet landed in the **Forensic Ledger**.
  ///
  /// ### When to use
  /// - **Optimistic UI**: Use this to show a "pending" or "live" state in your
  ///   application while waiting for the authoritative proof.
  /// - **Forensic Integrity**: Check this to determine if the current observation
  ///   is a finalized part of the system's "DNA" or a volatile impulse.
  ///
  /// ### How it works
  /// 1. **Immediate Broadcast**: If a cell is not backed by a ledger, or if the
  ///    ledger write is asynchronous, this signal is sent immediately with
  ///    `pendingReceipt = true`.
  /// 2. **Finalization**: Once the **Forensic Ledger** confirms the write, a
  ///    subsequent signal (or a [WireLedgerEntry]) is typically sent with
  ///    `pendingReceipt = false`.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Holes**: If this is `true`, the state change is "unconfirmed."
  ///   If the system crashes before the ledger write completes, this change
  ///   may be lost, creating a gap in the forensic history.
  /// - **Receipt Stale-ness**: When this is `true`, the [receipt] field often
  ///   contains the *previous* authoritative receipt, providing the last
  ///   known stable context for the cell before this new transition.
  /// - **Authoritative Default**: In a system with a synchronous ledger, this
  ///   field will almost always be `false` by the time the signal reaches the
  ///   **Skin Membrane**.
  ///
  /// ### See also
  /// - [WireStateChange.receipt]: The forensic proof that eventually clears the pending status.
  /// - [WireLedgerEntry]: The complete, non-pending audit record.
  final bool pendingReceipt;

  /// Creates a new [WireStateChange] observation envelope.
  ///
  /// In the framework's biological metaphor, this constructor assembles a
  /// **Somatic Observation**. It represents a **Nervous Impulse** generated
  /// when a cell changes its physical state, ready to be broadcast across
  /// the **Skin Membrane**.
  ///
  /// ### When to use
  /// - **Observation Streaming**: Use this when a cell's state changes and
  ///   you need to notify external subscribers (via SSE, MCP, etc.).
  /// - **Testing**: Use this to simulate state transitions in integration
  ///   tests or to verify observer behavior.
  ///
  /// ### How it works
  /// The constructor bundles the cell's address ([cellId]), its new observable
  /// traits ([payload]), and its forensic evidence ([receipt]) into a stable
  /// record. By default, new observations are marked as [pendingReceipt]
  /// until the **Forensic Ledger** confirms the write.
  ///
  /// ### Parameters
  /// - **cellId**: The **Somatic Address** of the cell that changed.
  /// - **payload**: The **Phenotype** (value) of the cell after the transition.
  /// - **receipt**: The **Forensic Receipt** providing proof of the change.
  /// - **pendingReceipt**: Whether the transition is still "in-flight" and
  ///   waiting to land in the permanent ledger.
  ///
  /// ### Non‑obvious behavior
  /// - **Volatile by Default**: If not specified, `pendingReceipt` defaults
  ///   to `true`. This assumes the impulse is live and unconfirmed until
  ///   the ledger tail specifically emits an authoritative entry.
  /// - **Stateless Construction**: This constructor does not require a
  ///   `correlationId` because observations are environmental broadcasts,
  ///   not direct replies to a specific **Command Journey**.
  ///
  /// ### See also
  /// - [WireStateChange.cellId]: The unique address of the target cell.
  /// - [WireStateChange.pendingReceipt]: The flag governing the authoritative
  ///   status of this signal.
  const WireStateChange({
    required this.cellId,
    this.payload,
    this.receipt,
    this.pendingReceipt = true,
  });

  /// The stable identifier used to distinguish this message type on the wire.
  ///
  /// In the framework's biological metaphor, this is the **Signal Label**.
  /// It tells the **Skin Membrane** that this envelope contains a
  /// **Somatic Observation** (a state change) rather than an incoming
  /// command or a direct response.
  ///
  /// ### When to use
  /// - **Polymorphic Decoding**: The [WireMessage.fromJson] factory uses
  ///   this value to decide to create a [WireStateChange] instance.
  /// - **Event Filtering**: External observers (like UI dashboards or AI
  ///   agents) use this field to distinguish between unsolicited state
  ///   broadcasts and direct command responses.
  ///
  /// ### How it works
  /// This getter always returns the string `'stateChange'`. When [toJson] is
  /// called, this label is stamped into the JSON payload, ensuring the
  /// receiver knows that a **Somatic State Transition** has been observed.
  ///
  /// ### Non‑obvious behavior
  /// - **Broadcast Nature**: Unlike [WireResponse.kind], a signal labeled
  ///   as `stateChange` does not carry a `correlationId`. It is a
  ///   **Nervous Impulse** broadcast to all subscribers of a cell's somatic
  ///   address.
  /// - **Strict Value**: This value is fixed. The entire signaling protocol
  ///   relies on this specific string to maintain compatibility between the
  ///   core reactive graph and external clients.
  ///
  /// ### See also
  /// - [WireMessage.kind]: The base definition for all message labels.
  /// - [WireStateChange.cellId]: The somatic address associated with this label.
  @override
  String get kind => 'stateChange';

  /// Converts the observation into a JSON-safe map for transport.
  ///
  /// In the framework's biological metaphor, this method creates the
  /// **Skin Form** of the state change. It prepares the **Somatic Observation**
  /// to cross the **Skin Membrane** so it can be broadcast to the environment.
  ///
  /// ### When to use
  /// - **Egress**: Use this when a server, MCP host, or SSE bridge needs to
  ///   serialize a live state transition for external subscribers.
  /// - **Persistence**: Used to store a snapshot of an observation in
  ///   transport-level logs or message queues.
  ///
  /// ### How it works
  /// 1. **Signal Labeling**: It includes the [kind] ('stateChange') so the
  ///    receiver knows this is an environmental broadcast, not a response.
  /// 2. **Somatic Addressing**: It embeds the [cellId] so observers know
  ///    exactly where in the body the transition occurred.
  /// 3. **Phenotype Encoding**: It includes the [payload] (the value) if it
  ///    is serializable.
  /// 4. **Forensic Evidence**: It attaches the [receipt] to provide the
  ///    authoritative proof from the **Forensic Ledger**.
  ///
  /// ### Non‑obvious behavior
  /// - **No Causal Link**: Unlike `WireResponse.toJson`, this map does not
  ///   contain a `correlationId`. It is a broadcast of a physical fact, not
  ///   a direct reply to an impulse.
  /// - **Pending Status**: The `pendingReceipt` flag is included to tell the
  ///   receiver if the change is already part of the permanent "DNA" or if
  ///   it is a volatile, in-flight signal.
  /// - **Omission Safety**: Fields that are `null` (like a non-serializable
  ///   payload or a missing receipt) are omitted from the map to keep the
  ///   **Skin Form** lean.
  ///
  /// ### See also
  /// - [WireStateChange.fromJson]: The reverse process for decoding signals.
  /// - [WireReceipt.toJson]: How the forensic evidence is serialized.
  @override
  Map<String, Object?> toJson() => withWire({
        'kind': kind,
        'cellId': cellId,
        if (payload != null) 'payload': payload,
        if (receipt != null) 'receipt': receipt!.toJson(),
        'pendingReceipt': pendingReceipt,
      });

  /// Decodes a raw JSON map into a [WireStateChange] observation.
  ///
  /// In the framework's biological metaphor, this factory acts as the
  /// **Signal Decoder** at the **Skin Membrane**. It translates the
  /// **Skin Form** of a somatic event back into a structured
  /// **Nervous Impulse** that the local system can process.
  ///
  /// ### When to use
  /// - **Egress Processing**: Use this when a client (AI agent, web app, or
  ///   remote listener) receives a state broadcast from a cell over a
  ///   network bridge (SSE, MCP, etc.).
  /// - **Synchronization**: The primary entry point for external observers
  ///   to ingest updates and keep their local "Phenotype" in sync with
  ///   the living graph.
  ///
  /// ### How it works
  /// 1. **Address Resolution**: It extracts the `cellId` to identify the
  ///    **Somatic Address** where the change occurred.
  /// 2. **Phenotype Mapping**: It pulls the `payload` representing the
  ///    new observable state of the cell.
  /// 3. **Forensic Verification**: It attempts to decode the `receipt`
  ///    to attach authoritative proof from the **Forensic Ledger**.
  /// 4. **Authoritative Check**: It determines the stability of the
  ///    signal via the `pendingReceipt` flag.
  ///
  /// ### Non‑obvious behavior
  /// - **Volatile Default**: If `pendingReceipt` is missing from the JSON,
  ///   it defaults to `true`. This follows the principle that a signal
  ///   is "unconfirmed" until the **Forensic Ledger** explicitly clears it.
  /// - **Null Phenotypes**: If the `payload` is missing, it implies the
  ///   state was not serializable. The decoder still creates the object,
  ///   but the observer should rely on the [receipt] for sequence data.
  /// - **Recursive Decoding**: It utilizes [WireReceipt.fromJson] to
  ///   maintain the integrity of the audit trail during the decoding process.
  ///
  /// ### See also
  /// - [WireStateChange.toJson]: The reverse process for broadcasting signals.
  /// - [WireMessage.fromJson]: The top-level membrane decoder.
  /// - [WireReceipt.fromJson]: The decoder for the attached forensic proof.
  factory WireStateChange.fromJson(Map<String, Object?> json) =>
      WireStateChange(
        cellId: json['cellId'] as String,
        payload: json['payload'],
        receipt: json['receipt'] == null
            ? null
            : WireReceipt.fromJson(
                (json['receipt'] as Map).cast<String, Object?>()),
        pendingReceipt: json['pendingReceipt'] as bool? ?? true,
      );
}

/// A fire-and-forget signal used for environmental pings and lightweight updates.
///
/// In the framework's biological metaphor, [WireNotification] is a
/// **Transient Impulse**. Unlike a [WireResponse], it does not conclude a
/// **Command Journey**, and unlike a [WireStateChange], it does not represent
/// a permanent **Somatic State Transition**. It is a temporary signal that
/// leaves no trace in the **Forensic Ledger**.
///
/// ### When to use
/// - **Pings & Heartbeats**: Use this to check if the **Skin Membrane** is alive.
/// - **Lightweight Alerts**: Use this for non-critical information that
///   doesn't require forensic integrity (e.g., "AI agent is thinking...").
/// - **Protocol Signaling**: Used for MCP notifications or SSE metadata that
///   falls outside the somatic graph.
///
/// ### How it works
/// - **Stateless**: Notifications never carry a `correlationId` or a sequence
///   number. They are emitted and forgotten.
/// - **Volatile**: Because they are not ledgered, notifications are lost if
///   the recipient is not listening at the exact moment the impulse occurs.
///
/// ### Non‑obvious behavior
/// - **Forensic Holes**: Notifications are intentionally excluded from the
///   **Forensic Ledger**. Never use them to transmit data that requires
///   auditability or causal traceability.
/// - **Membrane Only**: These signals exist only at the **Skin** layer. They
///   never reach the core reactive graph or trigger internal cell updates.
///
/// ### See also
/// - [WireMessage]: The base class for all signals crossing the membrane.
/// - [WireStateChange]: For observations that represent actual state changes.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is a volatile signal.
/// **Live signature:** `final class WireNotification extends WireMessage { final String method; final Map<String, Object?> params; const WireNotification({required String method, Map<String, Object?> params = const {}}); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Constraint:** Do not use for important data; notifications are not ledgered.
/// **Comparison:** Use [WireResponse] for results and [WireStateChange] for values.
final class WireNotification extends WireMessage {

  /// The specific name of the notification event or method.///
  /// In the framework's biological metaphor, this identifies the type of
  /// **Transient Impulse** being sent (e.g., `ping`). It tells the receiver
  /// how to interpret the temporary signal crossing the **Skin Membrane**.
  ///
  /// ### When to use
  /// - **Protocol Signaling**: Use this to define the intent of the notification,
  ///   such as a heartbeat or a non-somatic alert.
  /// - **Event Routing**: Used by external listeners to filter for specific
  ///   types of volatile signals.
  ///
  /// ### How it works
  /// The string stored here is used as the primary identifier for the
  /// notification. Unlike a [WireRequest.function], this does not map to
  /// a persistent **Integrity Gate** in the core graph.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Omission**: This method name is never recorded in the
  ///   **Forensic Ledger**. It represents a "fire-and-forget" signal that
  ///   leaves no audit trail.
  /// - **Strictly External**: This value is handled entirely within the
  ///   **Skin** layer and never triggers a **Somatic State Transition**.
  final String method;

  /// The data payload associated with the notification.
  ///
  /// In the framework's biological metaphor, these are the **Transient Nutrients**
  /// carried by the impulse. Since notifications are not recorded in the
  /// **Forensic Ledger**, this data is volatile and exists only for the duration
  /// of the signal's presence at the **Skin Membrane**.
  ///
  /// ### When to use
  /// - **Lightweight Payloads**: Use this to send supplemental information for
  ///   heartbeats, progress alerts, or metadata (e.g., `{'progress': 0.5}`).
  /// - **Non-Critical Data**: Use this only for information that does not
  ///   require causal traceability or permanent auditing.
  ///
  /// ### How it works
  /// 1. **Signal Carrying**: The client or server bundles arbitrary JSON-safe
  ///    data into this map.
  /// 2. **Immediate Consumption**: The receiver reads these parameters
  ///    immediately upon arrival.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Omission**: Data stored in `params` is **never** written to the
  ///   **Forensic Ledger**. It will not appear in audit trails or somatic history.
  /// - **No Integrity Gates**: Unlike [WireRequest] arguments, these parameters
  ///   are not vetted by a cell's DNA/rules. They are strictly for
  ///   transport-layer communication.
  /// - **Memory Longevity**: Once the notification is handled by the
  ///   membrane listeners, these nutrients are "consumed" (garbage collected)
  ///   and cannot be recovered.
  ///
  /// ### See also
  /// - [WireNotification.method]: The identifier for this transient impulse.
  /// - [WireRequest.positional]: For arguments that require forensic integrity.
  final Map<String, Object?> params;

  /// Creates a new [WireNotification] envelope.
  ///
  /// In the framework's biological metaphor, this constructor assembles a
  /// **Transient Impulse**. It prepares a volatile signal that is intended
  /// to cross the **Skin Membrane** without triggering a **Somatic State
  /// Transition** or entering the **Forensic Ledger**.
  ///
  /// ### When to use
  /// - **Heartbeats**: Use this to simulate or send "keep-alive" signals
  ///   between the system and an external client.
  /// - **Testing**: Use this to verify that the **Skin Membrane** correctly
  ///   handles and routes non-somatic, fire-and-forget impulses.
  ///
  /// ### How it works
  /// The constructor bundles a [method] name (the intent) and optional
  /// [params] (the nutrients) into a stable record. Because these impulses
  /// are transient, no correlation IDs or sequence numbers are required.
  ///
  /// ### Parameters
  /// - **method**: The identifier for the impulse (e.g., `'ping'`,
  ///   `'progress'`).
  /// - **params**: The **Transient Nutrients** (data) carried by the signal.
  ///   Defaults to an empty map if no data is provided.
  ///
  /// ### Non‑obvious behavior
  /// - **Zero Trace**: Objects created with this constructor are never
  ///   ledgered. Once they are delivered to a listener at the membrane,
  ///   they are effectively forgotten by the system.
  /// - **Immutability**: Like all wire messages, once the notification
  ///   is constructed, its contents cannot be changed, ensuring the
  ///   impulse remains stable during transport.
  ///
  /// ### See also
  /// - [WireNotification.method]: The type of impulse being created.
  /// - [WireNotification.params]: The data payload of the impulse.
  const WireNotification({required this.method, this.params = const {}});

  /// The stable identifier used to distinguish this message type on the wire.
  ///
  /// In the framework's biological metaphor, this is the **Signal Label**.
  /// It tells the **Skin Membrane** that this envelope contains a
  /// **Transient Impulse** (a notification) rather than a request,
  /// response, or state change.
  ///
  /// ### When to use
  /// - **Polymorphic Decoding**: The [WireMessage.fromJson] factory uses
  ///   this value to decide to create a [WireNotification] instance.
  /// - **Event Filtering**: External tools or bridges (like MCP hosts)
  ///   use this field to quickly identify and route fire-and-forget signals.
  ///
  /// ### How it works
  /// This getter always returns the string `'notification'`. When [toJson]
  /// is called, this label is stamped into the JSON payload, ensuring the
  /// receiver knows how to open the envelope without checking for
  /// correlation IDs or somatic addresses.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Omission**: A signal labeled as `notification` is
  ///   intentionally ignored by the **Forensic Ledger**. It represents
  ///   environmental noise or transient metadata that does not contribute
  ///   to the system's "DNA."
  /// - **Strict Value**: This value is fixed. The signaling protocol
  ///   relies on this specific string to distinguish volatile impulses
  ///   from authoritative state transitions.
  ///
  /// ### See also
  /// - [WireMessage.kind]: The base definition for all message labels.
  /// - [WireNotification.method]: The specific intent behind this label.
  @override
  String get kind => 'notification';

  /// Converts the notification into a JSON-safe map for transport.
  ///
  /// In the framework's biological metaphor, this method creates the
  /// **Skin Form** of the impulse. It prepares the **Transient Impulse**
  /// to cross the **Skin Membrane** so it can be broadcast to the environment.
  ///
  /// ### When to use
  /// - **Egress**: Use this when a server, MCP host, or SSE bridge needs to
  ///   serialize a fire-and-forget signal for external subscribers.
  /// - **Persistence**: Used to store a snapshot of a notification in
  ///   transport-level logs, though it will never appear in the core ledger.
  ///
  /// ### How it works
  /// 1. **Signal Labeling**: It includes the [kind] ('notification') so the
  ///    receiver knows this is a volatile signal, not a response or state change.
  /// 2. **Intent Mapping**: It embeds the [method] name to identify the
  ///    type of impulse (e.g., a heartbeat).
  /// 3. **Nutrient Bundling**: It attaches the [params] map containing the
  ///    temporary data associated with the event.
  ///
  /// ### Non-obvious behavior
  /// - **Forensic Omission**: The resulting map is intentionally excluded
  ///   from the **Forensic Ledger**. It does not contain a correlation ID
  ///   or a sequence number, as it represents "environmental noise."
  /// - **Membrane Only**: This transformation is strictly for the **Skin**
  ///   layer. The data here never triggers a **Somatic State Transition**
  ///   in the core reactive graph.
  /// - **Stability**: Like all wire messages, the output is a standard
  ///   string-keyed map, ensuring compatibility with MCP and REST bridges.
  ///
  /// ### See also
  /// - [WireNotification.fromJson]: The reverse process for decoding impulses.
  /// - [WireMessage.kind]: The base definition for the signal label.
  @override
  Map<String, Object?> toJson() =>
      withWire({'kind': kind, 'method': method, 'params': params});

  /// Decodes a raw JSON map into a [WireNotification] impulse.
  ///
  /// In the framework's biological metaphor, this factory acts as the
  /// **Signal Decoder** at the **Skin Membrane**. It translates the
  /// **Skin Form** of a volatile event back into a structured
  /// **Transient Impulse** that the local system can process.
  ///
  /// ### When to use
  /// - **Egress Processing**: Use this when a client (AI agent, web app, or
  ///   remote listener) receives a fire-and-forget notification from the
  ///   system over a network bridge (SSE, MCP, etc.).
  /// - **Lightweight Monitoring**: The primary entry point for ingesting
  ///   non-somatic updates like heartbeats or progress alerts.
  ///
  /// ### How it works
  /// 1. **Intent Resolution**: It extracts the `method` string to identify
  ///    the type of impulse (e.g., `'ping'`).
  /// 2. **Nutrient Mapping**: It pulls the `params` map representing the
  ///    temporary data associated with the notification.
  /// 3. **Safety Casting**: It ensures that the parameters are safely cast
  ///    to a string-keyed map, defaulting to an empty map if the field is missing.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Omission**: Unlike [WireRequest.fromJson], this factory
  ///   does not look for a `correlationId` or a `lastSeenSeq`. Notifications
  ///   are environmental noise and are not tracked by the **Forensic Ledger**.
  /// - **Zero Persistence**: The resulting object is transient. Once it passes
  ///   through the decoder and is handled by a listener, it leaves no audit
  ///   trail in the somatic graph.
  ///
  /// ### See also
  /// - [WireNotification.toJson]: The reverse process for broadcasting signals.
  /// - [WireMessage.fromJson]: The top-level membrane decoder.
  factory WireNotification.fromJson(Map<String, Object?> json) =>
      WireNotification(
        method: json['method'] as String,
        params: (json['params'] as Map?)?.cast<String, Object?>() ?? const {},
      );
}

/// A discovery signal sent to the system to request a list of available tools and cells.
///
/// In the framework's biological metaphor, [WireManifestRequest] is a
/// **Discovery Impulse**. It is a **Nervous Signal** that scans the
/// **Skin Membrane** to find out what functionality is physically exposed
/// to the outside world.
///
/// ### When to use
/// - **Capability Discovery**: Use this when a client (like an AI agent or
///   a dashboard) first connects and needs to know which tools/cells it
///   is allowed to interact with.
/// - **Initialization**: The first step in establishing a connection via
///   protocols like MCP or SSE.
///
/// ### How it works
/// 1. **Signal Ingress**: The impulse hits the membrane.
/// 2. **Catalog Lookup**: The system gathers the metadata for all exposed
///    cells and tools.
/// 3. **Manifest Return**: The system responds with a [WireManifestResponse]
///    containing the **Somatic Index** (the manifest).
///
/// ### Non‑obvious behavior
/// - **Forensic Omission**: This request is a "read-only" discovery operation.
///   It is not recorded in the **Forensic Ledger** and does not trigger a
///   **Somatic State Transition**.
/// - **Stateless**: Unlike a [WireRequest], this signal does not require
///   a correlation ID or sequence markers because it is a generic
///   query for the system's current "DNA" structure.
///
/// ### See also
/// - [WireManifestResponse]: The envelope carrying the actual catalog.
/// - [SkinManifest]: The internal record being requested.
///
/// ### AI Agent Guide
/// **Layer:** Skin — a read-only catalogue query.
/// **When to use:** asking the membrane for its tool catalogue; the
/// optional `correlationId` is omitted from JSON when null.
/// **When NOT to use:** commands — [WireRequest].
/// **Live signature:** `const WireManifestRequest({String? correlationId})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
final class WireManifestRequest extends WireMessage {

  /// The optional correlation id of this discovery impulse.
  ///
  /// Omitted on the wire when `null`. A caller may set it to correlate
  /// a manifest request with the response that follows; the default is
  /// the historical stateless shape.
  final String? correlationId;

  /// Creates a new [WireManifestRequest] envelope.
  ///
  /// In the framework's biological metaphor, this constructor assembles a
  /// **Discovery Impulse**. It represents the initial signal sent to the
  /// **Skin Membrane** to query the system's capabilities and current "DNA"
  /// structure.
  ///
  /// ### When to use
  /// - **Initialization**: Use this when a client (like an AI agent or a
  ///   remote dashboard) first connects and needs to discover which cells
  ///   and tools are physically exposed.
  /// - **Dynamic Re-discovery**: Useful if a client needs to refresh its
  ///   local index of available tools after a system-wide update.
  ///
  /// ### How it works
  /// This constructor creates a stateless signal. Because discovery is a
  /// read-only scan of the membrane's surface, it does not require
  /// correlation IDs, sequence markers, or arguments.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Omission**: Signals created with this constructor never
  ///   enter the **Forensic Ledger**. They are purely observational and
  ///   do not trigger a **Somatic State Transition**.
  /// - **Singleton-like Behavior**: Since this request carries no state
  ///   or parameters, all instances are functionally identical and safe
  ///    to use as `const`.
  ///
  /// ### See also
  /// - [WireManifestResponse]: The envelope that returns the requested catalog.
  /// - [SkinManifest]: The internal record of the system's exposed surface.
  const WireManifestRequest({this.correlationId});

  /// The stable identifier used to distinguish this message type on the wire.
  ///
  /// In the framework's biological metaphor, this is the **Signal Label**.
  /// It tells the **Skin Membrane** exactly what kind of **Discovery Impulse**
  /// is inside the envelope so the system can initiate a somatic scan rather
  /// than a state transition.
  ///
  /// ### When to use
  /// - **Polymorphic Decoding**: The [WireMessage.fromJson] factory uses
  ///   this value to recognize that a discovery process is being requested.
  /// - **Network Routing**: Used by transport bridges (like MCP or SSE) to
  ///   route this impulse to the manifest provider.
  ///
  /// ### How it works
  /// This getter always returns the string `'manifestRequest'`. When [toJson]
  /// is called, this label is stamped into the JSON payload.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Omission**: Unlike a `request` or `response`, a signal
  ///   labeled as a `manifestRequest` is ignored by the **Forensic Ledger**.
  ///   It is a read-only probe of the membrane's surface.
  /// - **Strict Value**: This value is fixed. The signaling protocol
  ///   relies on this specific string to distinguish discovery impulses from
  ///   authoritative commands.
  ///
  /// ### See also
  /// - [WireMessage.kind]: The base definition for all message labels.
  /// - [WireManifestResponse.kind]: The label for the resulting somatic index.
  @override
  String get kind => 'manifestRequest';

  /// Converts the request into a JSON-safe map for transport.
  ///
  /// In the framework's biological metaphor, this method creates the
  /// **Skin Form** of the discovery signal. It prepares the
  /// **Discovery Impulse** to cross the **Skin Membrane** so it can
  /// initiate a scan of the system's exposed capabilities.
  ///
  /// ### When to use
  /// - **Egress**: Use this when a client-side bridge needs to serialize
  ///   a discovery probe to send it to a remote cell system.
  /// - **Testing**: Used to verify that the discovery signal is correctly
  ///   labeled for the transport layer.
  ///
  /// ### How it works
  /// This method produces a minimal map containing only the [kind]
  /// ('manifestRequest'). Because discovery is a global, stateless
  /// operation, no somatic addresses or correlation IDs are required
  /// in the payload.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Omission**: The resulting JSON is never stored in the
  ///   **Forensic Ledger**. It represents a transient query about the
  ///   system's current "DNA" that does not alter state.
  /// - **Zero Nutrients**: Unlike a `notification` or a `request`, this
  ///   signal carries no parameters. It is a pure impulse that triggers
  ///   a full manifest generation on the receiver side.
  ///
  /// ### See also
  /// - [WireManifestRequest.kind]: The label used to identify this impulse.
  /// - [WireManifestResponse.toJson]: The method that serializes the resulting catalog.
  @override
  Map<String, Object?> toJson() => withWire({
        'kind': kind,
        if (correlationId != null) 'correlationId': correlationId,
      });

  /// Decodes a raw JSON map into a [WireManifestRequest]. A missing
  /// `correlationId` decodes as `null`, like every other optional key.
  factory WireManifestRequest.fromJson(Map<String, Object?> json) =>
      WireManifestRequest(correlationId: json['correlationId'] as String?);
}

/// The envelope carrying the system's somatic catalog back to a discovery client.
///
/// In the framework's biological metaphor, [WireManifestResponse] is the
/// **Somatic Index**. It is the authoritative reply to a **Discovery Impulse**
/// ([WireManifestRequest]), providing a map of the cells and tools physically
/// exposed at the **Skin Membrane**.
///
/// ### When to use
/// - **Capability Resolution**: Used by the system to inform a client (like
///   an AI agent) what functionality is available for interaction.
/// - **Handshake Completion**: The final step of the discovery phase in
///   protocols like MCP or SSE.
///
/// ### How it works
/// 1. **Discovery Processing**: The system identifies all exposed tools and
///    cells within the somatic graph.
/// 2. **Index Assembly**: A [SkinManifest] is generated, detailing the
///    "DNA" (schemas and IDs) of the exposed surface.
/// 3. **Impulse Return**: The manifest is wrapped in this envelope and
///    pushed back through the membrane to the caller.
///
/// ### Non‑obvious behavior
/// - **Forensic Omission**: Because this is a read-only discovery result,
///   it is not recorded in the **Forensic Ledger**. It describes the
///   system's potential for state change, rather than a change itself.
/// - **Stateless Envelope**: Unlike a standard [WireResponse], this
///   does not require a `correlationId` because it is a global snapshot of
///   the membrane's current capabilities.
///
/// ### See also
/// - [WireManifestRequest]: The impulse that triggers this response.
/// - [SkinManifest]: The actual catalog data being carried.
///
/// ### AI Agent Guide
/// **Layer:** Skin — the catalogue answer.
/// **When to use:** replying to a [WireManifestRequest]; the optional
/// `correlationId` echoes the query when present.
/// **When NOT to use:** commands or state — [WireResponse] and
/// [WireStateChange] own those.
/// **Live signature:** `const WireManifestResponse({required SkinManifest manifest, String? correlationId})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
final class WireManifestResponse extends WireMessage {

  /// The catalog of exposed tools and cells available for interaction.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Index**.
  /// It serves as the physical map of the system's "DNA," detailing the
  /// structure and location of every cell and tool physically exposed at the
  /// **Skin Membrane**.
  ///
  /// ### When to use
  /// - **Tool Discovery**: Used by AI agents to understand which **Nervous
  ///   Signals** (requests) the system is capable of processing.
  /// - **Schema Validation**: Provides the JSON schemas required to correctly
  ///   format arguments for a **Command Journey**.
  ///
  /// ### How it works
  /// 1. **Signal Response**: When a **Discovery Impulse** ([WireManifestRequest])
  ///    is received, the system generates this index.
  /// 2. **Structure Mapping**: It enumerates all cells and tools that have
  ///    passed through an **Integrity Gate** for public exposure.
  /// 3. **Payload Delivery**: The manifest is serialized into the **Skin Form**
  ///    and delivered to the client.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Omission**: The data within this manifest is observational.
  ///   It does not represent a **Somatic State Transition** and is therefore
  ///   never recorded in the **Forensic Ledger**.
  /// - **Strict Exposure**: If a cell or tool is missing from this index, it
  ///   is effectively invisible to the outside world, regardless of its
  ///   existence in the core somatic graph.
  /// - **Snapshot Nature**: This manifest represents a point-in-time view of
  ///   the system's capabilities. If the system's "DNA" changes (e.g., dynamic
  ///   tool registration), a new **Discovery Impulse** must be sent.
  ///
  /// ### See also
  /// - [SkinManifest]: The internal data structure being carried.
  /// - [WireManifestRequest]: The impulse that requested this index.
  final SkinManifest manifest;

  /// The optional correlation id echoed from the requesting impulse.
  /// Omitted on the wire when `null`.
  final String? correlationId;

  /// Creates a new [WireManifestResponse] envelope.
  ///
  /// In the framework's biological metaphor, this constructor assembles the
  /// **Somatic Index**. It packages the system's "DNA" (available tools and cells)
  /// into a **Skin Form** so it can be transmitted back through the
  /// **Skin Membrane** in response to a **Discovery Impulse**.
  ///
  /// ### When to use
  /// - **Discovery Completion**: Use this when the system has finished
  ///   scanning its internal graph and is ready to tell a client (like an
  ///   AI agent) what functionality is exposed.
  /// - **Handshake Finalization**: The final step in a connection sequence
  ///   where the client needs the somatic map to begin sending commands.
  ///
  /// ### How it works
  /// This constructor wraps a [SkinManifest], which contains the technical
  /// schemas and addresses of the system's surface. Unlike a standard
  /// [WireResponse], this does not conclude a specific **Command Journey**
  /// and therefore does not require a correlation ID.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Omission**: The envelope created here is purely
  ///   observational. It is not recorded in the **Forensic Ledger** because
  ///   providing the index does not trigger a **Somatic State Transition**.
  /// - **Global Snapshot**: The manifest provided should represent the
  ///   entirety of the physically exposed surface at the moment the
  ///   **Discovery Impulse** was processed.
  ///
  /// ### See also
  /// - [WireManifestRequest]: The discovery signal that triggers this response.
  /// - [SkinManifest]: The actual catalog of cells and tools being carried.
  const WireManifestResponse({required this.manifest, this.correlationId});

  /// The stable identifier used to distinguish this message type on the wire.
  ///
  /// In the framework's biological metaphor, this is the **Signal Label**.
  /// It tells the receiver that the envelope contains a **Somatic Index**
  /// (a capability map) rather than a state update or a direct result of a
  /// **Command Journey**.
  ///
  /// ### When to use
  /// - **Polymorphic Decoding**: The [WireMessage.fromJson] factory uses
  ///   this value to recognize that a discovery response has arrived from
  ///   the **Skin Membrane**.
  /// - **Network Routing**: Used by transport bridges (like MCP or SSE) to
  ///   correctly handle the incoming capability payload.
  ///
  /// ### How it works
  /// This getter always returns the string `'manifestResponse'`. When [toJson]
  /// is called, this label is stamped into the JSON payload, identifying
  /// the packet as the official response to a **Discovery Impulse**.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Omission**: Unlike a `request` or `response`, a signal
  ///   labeled as a `manifestResponse` is ignored by the **Forensic Ledger**.
  ///   It describes the system's potential for state change, rather than a
  ///   change itself.
  /// - **Strict Value**: This value is fixed. The signaling protocol
  ///   relies on this specific string to distinguish discovery metadata
  ///   from authoritative state transitions.
  ///
  /// ### See also
  /// - [WireMessage.kind]: The base definition for all message labels.
  /// - [WireManifestRequest.kind]: The label for the initial discovery query.
  @override
  String get kind => 'manifestResponse';

  /// Converts the manifest response into a JSON-safe map for transport.
  ///
  /// In the framework's biological metaphor, this method creates the
  /// **Skin Form** of the **Somatic Index**. It prepares the catalog of
  /// available tools and cells to cross the **Skin Membrane** so a
  /// discovery client can understand the system's "DNA."
  ///
  /// ### When to use
  /// - **Egress**: Use this when the system needs to serialize the result
  ///   of a **Discovery Impulse** ([WireManifestRequest]) to send it
  ///   to a remote client or AI agent.
  /// - **Handshake Finalization**: Used during the initial connection
  ///   phase to provide the caller with a technical map of the surface.
  ///
  /// ### How it works
  /// 1. **Signal Labeling**: It includes the [kind] ('manifestResponse')
  ///    so the receiver knows this is a capability index.
  /// 2. **Somatic Serialization**: It calls `toJson()` on the [manifest],
  ///    transforming the internal cell/tool definitions into a
  ///    wire-safe format.
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Omission**: The resulting JSON is strictly observational.
  ///   Because discovery does not trigger a **Somatic State Transition**,
  ///   this payload is never recorded in the **Forensic Ledger**.
  /// - **Statelessness**: Unlike a standard `WireResponse.toJson`, this
  ///   map does not contain a `correlationId`. It is a global snapshot
  ///   of the membrane's surface at a specific point in time.
  ///
  /// ### See also
  /// - [WireManifestResponse.kind]: The label used to identify this index.
  /// - [SkinManifest.toJson]: The method that serializes the actual
  ///   cell and tool metadata.
  @override
  Map<String, Object?> toJson() => withWire({
        'kind': kind,
        'manifest': manifest.toJson(),
        if (correlationId != null) 'correlationId': correlationId,
      });

  /// Decodes a raw JSON map into a [WireManifestResponse].
  ///
  /// In the framework's biological metaphor, this factory acts as a
  /// **Signal Decoder** at the **Skin Membrane**. It translates the
  /// **Skin Form** of the system's catalog back into a structured
  /// **Somatic Index** that the client can use to navigate the graph.
  ///
  /// ### When to use
  /// - **Egress Processing**: Use this when a client (like an AI agent or
  ///   a remote dashboard) receives a discovery response and needs to
  ///   reconstruct the available toolset.
  /// - **Initialization**: The final step for a client to understand the
  ///   "DNA" of the system it just connected to.
  ///
  /// ### How it works
  /// 1. **Index Extraction**: It identifies the `manifest` key in the
  ///    payload.
  /// 2. **Recursive Decoding**: It delegates the reconstruction of the
  ///    technical schemas and addresses to [SkinManifest.fromJson].
  ///
  /// ### Non‑obvious behavior
  /// - **Forensic Omission**: Unlike [WireResponse.fromJson], this factory
  ///   does not look for correlation IDs or forensic receipts. The
  ///   resulting object is a stateless snapshot of the system's potential,
  ///   not a record of a state change.
  /// - **Strict Mapping**: The factory expects the `manifest` field to be
  ///   present and valid; if the **Skin Form** is corrupted, the decoding
  ///   process will fail, protecting the client from malformed discovery data.
  ///
  /// ### See also
  /// - [WireManifestResponse.toJson]: The reverse process for preparing
  ///   the index for the wire.
  /// - [SkinManifest.fromJson]: The decoder for the actual catalog content.
  factory WireManifestResponse.fromJson(Map<String, Object?> json) =>
      WireManifestResponse(
        manifest: SkinManifest.fromJson(
            (json['manifest'] as Map).cast<String, Object?>()),
        correlationId: json['correlationId'] as String?,
      );
}

/// A wrapper for an authoritative audit record from the system's permanent history.
///
/// In the framework's biological metaphor, [WireLedgerEntry] is a
/// **Forensic Ledger Row**. It represents a finalized **Somatic State Transition**
/// that has been physically written into the system's "DNA." Unlike a
/// [WireStateChange], which can be volatile or pending, this signal is the
/// legal proof of a committed event.
///
/// ### When to use
/// - **Audit Streaming**: Use this to push a real-time feed of the
///   **Forensic Ledger** to an external auditor or a long-term storage service.
/// - **Causal Synchronization**: Essential for clients that need to reconstruct
///   the exact, sequence-perfect history of the somatic graph.
/// - **Legal Traceability**: The primary message type for identifying who
///   triggered a change and exactly when it was physically anchored.
///
/// ### How it works
/// 1. **Persistence**: A change occurs and is accepted by an **Integrity Gate**.
/// 2. **Anchoring**: The **Forensic Ledger** assigns a global sequence
///    number and timestamp.
/// 3. **Egress**: The system emits this envelope through the
///    **Skin Membrane** as an authoritative confirmation of the transition.
///
/// ### Non‑obvious behavior
/// - **Authoritative Only**: This signal is never "pending." If it exists
///   on the wire, it means the **Command Journey** has been successfully
///   anchored in the ledger.
/// - **Global Ordering**: The sequence numbers within these entries are
///   the only valid way to determine the absolute order of events across
///   all cells in the body.
///
/// ### See also
/// - [LedgerEntry]: The internal forensic record being carried.
/// - [WireStateChange]: For live observations that may still be pending.
/// - [WireResponse]: For the immediate result of a specific command.
///
/// ### AI Agent Guide
/// **Layer:** Skin — one audit entry, encoded by `LedgerEntry.toJson`.
/// **When to use:** the ledger SSE and the audit tail — the sequence
/// numbers here are the only global order across all cells.
/// **When NOT to use:** hand-built receipts — the framework's own codec,
/// never a fork.
/// **Live signature:** `const WireLedgerEntry({required LedgerEntry entry})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
final class WireLedgerEntry extends WireMessage {

  /// The technical forensic record containing the audit data.
  ///
  /// In the framework's biological metaphor, this is the **Forensic Record**.
  /// It serves as a permanent segment of the system's "DNA," containing the
  /// sequence number, timestamp, and the **Causal Link** (correlation ID)
  /// that anchors a **Somatic State Transition** to the ledger.
  ///
  /// ### When to use
  /// - **History Reconstruction**: Use this to build a sequence-perfect
  ///   chronology of the system's state for auditing or time-travel debugging.
  /// - **Verification**: Use this to prove that a specific **Command Journey**
  ///   was physically committed and to identify its global order relative to
  ///   other impulses.
  ///
  /// ### How it works
  /// 1. **Anchoring**: After a cell passes an **Integrity Gate**, the
  ///    **Forensic Ledger** assigns this record a unique global sequence number.
  /// 2. **Serialization**: The ledgered data is converted into this record
  ///    structure, preserving the metadata required for forensic analysis.
  /// 3. **Egress**: The record is wrapped in a [WireLedgerEntry] and
  ///    pushed through the **Skin Membrane**.
  ///
  /// ### Non‑obvious behavior
  /// - **Authoritative Truth**: This is the only legal proof of a state change.
  ///   Unlike the `payload` in a [WireStateChange], the data here is
  ///   guaranteed to be anchored in permanent storage.
  /// - **Information Loss**: As this is the **Skin Form** of the record,
  ///   it does not contain live Dart object references. It contains only
  ///   the values as they were physically encoded in the ledger.
  /// - **Causal Linkage**: The `correlationId` inside this entry allows
  ///   auditors to map the resulting state change back to the original
  ///   **Nervous Signal** ([WireRequest]) that triggered it.
  ///
  /// ### See also
  /// - [LedgerEntry]: The internal forensic structure being carried.
  /// - [WireLedgerEntry.kind]: The label identifying this as a ledger signal.
  final LedgerEntry entry;

  const WireLedgerEntry({required this.entry});

  @override
  String get kind => 'ledgerEntry';

  @override
  Map<String, Object?> toJson() =>
      withWire({'kind': kind, 'entry': entry.toJson()});

  /// Decodes a [WireLedgerEntry] encoded by [toJson].
  ///
  /// The decoded entry carries its stored receipt JSON; its live
  /// `receipt.cell` cannot be reconstructed without the graph.
  factory WireLedgerEntry.fromJson(Map<String, Object?> json) =>
      WireLedgerEntry(
        entry: LedgerEntry.fromJson(
            (json['entry'] as Map).cast<String, Object?>()),
      );
}

/// A failure signal indicating that a request was rejected before reaching the core graph.
///
/// In the framework's biological metaphor, [WireError] is a **Membrane Rejection**.
/// It represents a **Nervous Signal** that was stopped at the **Skin Membrane** or
/// blocked by an **Integrity Gate** before a **Command Journey** could begin.
///
/// Because the signal never reached a cell's `apply` logic, no **Forensic Receipt**
/// is generated, and no **Somatic State Transition** occurs. If this error is not
/// reported to the caller, it creates a **Forensic Hole** in the system's external
/// observability, as there is no entry in the **Forensic Ledger** to explain the
/// missing state change.
///
/// ### When to use
/// - **Transport Failures**: Use this for network errors or protocol violations
///   (`transport_error`).
/// - **Exposure Rejections**: Use this when a tool is unknown (`unknown_tool`) or
///   arguments fail basic schema validation at the membrane (`bad_arguments`).
/// - **Conflict/Cursor Errors**: Use this when a request is rejected due to
///   concurrency or missing prerequisites (`conflict`, `cursor_required`).
///
/// ### How it works
/// 1. **Signal Ingress**: A request hits the **Skin Membrane**.
/// 2. **Validation Failure**: The router or adapter identifies a problem
///    before the command can be dispatched to a cell.
/// 3. **Rejection**: Instead of a [WireResponse], this envelope is returned
///    to explain why the ledger remains unchanged.
///
/// ### Non‑obvious behavior
/// - **Forensic Omission**: This error is not written to the **Forensic Ledger**.
///   It is a transient signal about a failed attempt to change state.
/// - **Receipt Absence**: Unlike domain-level rejections (which produce an
///   `ApplyRejected` outcome in a [WireResponse]), this variant exists
///   specifically to signal that no receipt was ever created.
/// - **Security**: The [message] field is sanitized to avoid echoing raw
///   internal exception details, preventing information leaks about the system "DNA."
///
/// ### See also
/// - [WireResponse]: For rejections that happen *inside* the cell's logic.
/// - [SkinRouter]: The component usually responsible for generating these errors.
///
/// ### AI Agent Guide
/// **Layer:** Skin — a pre-apply rejection with a stable code.
/// **When to use:** the frozen codes in
/// [skinErrorStatus] — `unknown_tool`, `bad_arguments`,
/// `cursor_required`, `conflict`, `idempotency_conflict`, `forbidden`,
/// `queue_timeout`, `outcome_unknown`, `queue_full`, `verify_failed`,
/// `host_not_allowed`, `origin_not_allowed`, `transport_error`.
/// **When NOT to use:** domain rejections — those are `ApplyRejected`
/// outcomes in a [WireResponse].
/// **Live signature:** `const WireError({required String correlationId, String? clientCorrelationId, required String code, required String message})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// {@category Wire Messages}
final class WireError extends WireMessage {
  /// The authoritative identifier for the failed impulse.
  ///
  /// In the framework's biological metaphor, this is the **Causal Link**.
  /// Even though the **Command Journey** failed to start, this ID allows
  /// the system to track the attempt and link the rejection back to the
  /// original **Nervous Signal**.
  final String correlationId;

  /// The optional ID provided by the caller, echoed verbatim.
  ///
  /// In the framework's biological metaphor, this is the **External Echo**.
  /// It allows the caller to match this **Membrane Rejection** to their
  /// specific local action or UI state.
  final String? clientCorrelationId;

  /// A stable identifier for the type of failure.
  ///
  /// In the framework's biological metaphor, this is the **Rejection Label**.
  /// It maps the failure to a standard category (e.g., `unknown_tool`, `conflict`)
  /// that can be translated into transport-specific codes like HTTP 404 or 409.
  final String code;

  /// A human and AI-readable description of why the signal was rejected.
  ///
  /// This provides the context needed to fix the request, ensuring the
  /// **Skin Membrane** provides clear feedback without leaking internal
  /// implementation details.
  final String message;

  /// Creates a new [WireError] envelope.
  ///
  /// In the framework's biological metaphor, this constructor assembles the
  /// **Membrane Rejection**. It packages the failure metadata into a
  /// **Skin Form** to inform the caller that their **Nervous Signal**
  /// was discarded before affecting the somatic graph.
  const WireError({
    required this.correlationId,
    this.clientCorrelationId,
    required this.code,
    required this.message,
  });

  /// The stable identifier used to distinguish this message type on the wire.
  ///
  /// In the framework's biological metaphor, this is the **Signal Label**.
  /// It tells the receiver that the envelope contains a failure report
  /// rather than a state observation or a successful result.
  @override
  String get kind => 'error';

  /// Converts the error into a JSON-safe map for transport.
  ///
  /// In the framework's biological metaphor, this method creates the
  /// **Skin Form** of the rejection. It stamps the envelope with the
  /// necessary causal links so the caller can identify which impulse failed.
  @override
  Map<String, Object?> toJson() => withWire({
    'kind': kind,
    'correlationId': correlationId,
    if (clientCorrelationId != null)
      'clientCorrelationId': clientCorrelationId,
    'code': code,
    'message': message,
  });

  /// Decodes a raw JSON map into a [WireError].
  ///
  /// In the framework's biological metaphor, this factory acts as a
  /// **Signal Decoder** at the **Skin Membrane**. It translates the
  /// **Skin Form** of a rejection back into a structured error that
  /// the client can use to react to a failed request.
  factory WireError.fromJson(Map<String, Object?> json) => WireError(
    correlationId: json['correlationId'] as String,
    clientCorrelationId: json['clientCorrelationId'] as String?,
    code: json['code'] as String,
    message: json['message'] as String,
  );
}
