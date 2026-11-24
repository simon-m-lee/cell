// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The egress skin cells.
///
/// Egress is **not a reply**: a [WireStateChange] carries no correlation
/// id and can never complete a pending `request()`. The authoritative
/// receipt arrives with the ledger entry itself.
///
/// * **Ledgered membranes** drive egress from `Ledger.tail`: every
///   entry carries its own receipt, so a state change is always paired
///   with *its* receipt — never an earlier one.
/// * **Unledgered membranes** observe the targets directly; every
///   egress pulse is `pendingReceipt` because no receipt exists to
///   attach — nothing is ever fabricated.
/// {@category Architecture}
library;

import 'package:cell/cell.dart';

import '../wire/wire_message.dart';
import '../wire/wire_receipt.dart';

/// Sets up observers to send signals out of the system for cells that do not
/// use a forensic ledger.
///
/// In the framework's biological metaphor, this function builds the
/// **Exiting Signal Path**. It watches specific cells and packages their
/// changes into "Wire Signals" so they can be sent to other parts of
/// the network.
///
/// ### When to use
/// - **Outbound Communication**: Use this when you need to notify external
///   systems about state changes.
/// - **Simple Membranes**: Use this for "Unledgered Membranes"—systems
///   that need to send data out but don't need a permanent history log.
///
/// ### How it works
/// 1. **Target Lookup**: It loops through a list of IDs and finds the
///    matching cell in the system.
/// 2. **Observation**: It starts a [Cell.observe] to listen for any
///    new [Pulse] (Nervous Signal) from that cell.
/// 3. **Wrapping**: When a change happens, it wraps the data into a
///    [WireStateChange] message.
/// 4. **Forwarding**: It triggers the [onEgressPulse] callback to
///    actually send the data out.
///
/// ### Parameters
/// - **cellIds**: A list of unique names for the cells you want to watch.
/// - **resolveTarget**: A function that finds the actual [Cell] object
///   based on its name.
/// - **onEgressPulse**: The final gateway function that handles the
///   message once it is ready to exit the system.
///
/// ### Non‑obvious behavior
/// - **Pending Receipts**: Because these cells do not have a forensic ledger,
///   every message is marked as `pendingReceipt: true`. This tells the
///   receiver that there is no official "Forensic ID" for this specific
///   change yet.
/// - **Causal Preservation**: The exiting signal keeps the original
///   [context] of the change, so you can still tell what triggered the
///   action even after it leaves the cell.
///
/// ### Example
/// ```dart
/// final handles = buildEgressCells(
///   cellIds: ['user_profile', 'settings'],
///   resolveTarget: (id) => myRegistry.find(id),
///   onEgressPulse: (id, pulse) {
///     networkAdapter.send(pulse.payload.toJson());
///   },
/// );
/// ```
Map<String, EgressHandle<Pulse>> buildEgressCells({
  required Iterable<String> cellIds,
  required Cell? Function(String cellId) resolveTarget,
  required void Function(String cellId, Pulse<WireStateChange> pulse)
      onEgressPulse,
}) {
  final handles = <String, EgressHandle<Pulse>>{};
  for (final cellId in cellIds) {
    final target = resolveTarget(cellId);
    if (target == null) continue;
    handles[cellId] = Cell.observe<Pulse>(
      source: target,
      effect: (pulse) {
        onEgressPulse(
          cellId,
          Pulse<WireStateChange>.governed(
            payload: WireStateChange(
              cellId: cellId,
              payload: pulse.payload,
              pendingReceipt: true,
            ),
            type: '${SkinPulseTypes.egressPrefix}$cellId',
            source: target,
            context: pulse.context,
          ),
        );
      },
    );
  }
  return handles;
}

/// Converts a [LedgerEntry] into an authoritative [WireStateChange] signal.
///
/// In the framework's biological metaphor, this is a **Forensic Export**.
/// It takes a confirmed record from the **Forensic Ledger** and packages it
/// as an official message to be sent outside the cell membrane.
///
/// Unlike "Unledgered" signals, this message carries its official
/// **Forensic Receipt**, proving that the change was successfully
/// committed to the system's DNA.
///
/// ### When to use
/// - **Ledgered Communication**: Use this when your system uses a
///   [Ledger] and you need to notify external systems of a confirmed
///   somatic change.
/// - **Audit Syncing**: Use this to provide other systems with an
///   identical copy of your internal audit trail.
///
/// ### How it works
/// 1. **Receipt Extraction**: It pulls the official [WireReceipt] directly
///    from the ledger entry's stored JSON.
/// 2. **Payload Retrieval**: It extracts the [Pulse] data that caused
///    the change.
/// 3. **Authoritative Pairing**: It combines the receipt and data into a
///    [WireStateChange] where `pendingReceipt` is set to `false`.
///
/// ### Parameters
/// - **entry**: The official [LedgerEntry] record representing a
///   completed **Somatic State Transition**.
///
/// ### Non‑obvious behavior
/// - **Authoritative Link**: Because the receipt and the data come from
///   the same ledger entry, they are guaranteed to be perfectly paired.
///   The receiver can trust this is a finalized "Source of Truth."
/// - **Encoding Consistency**: This function uses the same canonical
///   JSON format as the audit trail itself, ensuring the data looks the
///   same in the ledger as it does on the wire.
/// - **Causal Completeness**: Unlike temporary signals, this export
///   represents a journey that is already finished and recorded.
///
/// ### Example
/// ```dart
/// // Listening to the tail of the Forensic Ledger
/// myLedger.stream.listen((entry) {
///   final officialSignal = wireStateChangeForEntry(entry);
///
///   // Send the confirmed change to a remote server
///   dispatcher.send(officialSignal);
/// });
/// ```
///
/// See also:
/// - [LedgerEntry]: The stored record of a nervous signal.
/// - [WireStateChange]: The container used for signals exiting the system.
/// - [buildEgressCells]: For sending signals from systems without a ledger.
WireStateChange wireStateChangeForEntry(
  LedgerEntry entry, {
  String? functionLabel,
}) {
  final storedReceipt = entry.toJson()['receipt'];
  final receipt = storedReceipt is Map
      ? WireReceipt.fromJson(storedReceipt.cast<String, Object?>())
      : WireReceipt.fromJson(wireReceiptJson(entry.receipt));
  final labeled = functionLabel == null
      ? receipt
      : WireReceipt(
          id: receipt.id,
          cellId: receipt.cellId,
          functionLabel: functionLabel,
          positional: receipt.positional,
          named: receipt.named,
          timestamp: receipt.timestamp,
          txSequence: receipt.txSequence,
          vetted: receipt.vetted,
          ledgerSeq: receipt.ledgerSeq,
          pulseDigest: receipt.pulseDigest,
          receptorVersion: receipt.receptorVersion,
          ruleVersion: receipt.ruleVersion,
          contextVersion: receipt.contextVersion,
        );
  return WireStateChange(
    cellId: entry.receiptCellId,
    payload: entry.pulseJson?['payload'],
    receipt: labeled,
    pendingReceipt: false,
  );
}
