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

/// Builds the unledgered egress observers: one `Cell.observe` per
/// exposed target. Every pulse is `pendingReceipt` — without a ledger
/// there is no receipt to attach.
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

/// Wraps one ledger entry as the authoritative `skin.egress.<cellId>`
/// state change: the entry's own receipt pairs with the entry's own
/// pulse payload. The receipt comes from the entry's canonical stored
/// JSON — the same encoding the audit trail itself uses.
WireStateChange wireStateChangeForEntry(LedgerEntry entry) {
  final storedReceipt = entry.toJson()['receipt'];
  return WireStateChange(
    cellId: entry.receiptCellId,
    payload: entry.pulseJson?['payload'],
    receipt: storedReceipt is Map
        ? WireReceipt.fromJson(storedReceipt.cast<String, Object?>())
        : WireReceipt.fromJson(wireReceiptJson(entry.receipt)),
    pendingReceipt: false,
  );
}
