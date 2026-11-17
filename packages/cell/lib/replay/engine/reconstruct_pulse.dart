// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Reconstructs the input [Pulse] that produced a [LedgerEntry].
///
/// ### What is stored, honestly
///
/// The ledger stores `pulseDigest` — a hash of the pulse's full JSON,
/// including its wall-clock timestamp. A hash is one-way: the exact
/// recorded pulse can never be rebuilt byte-for-byte. What the ledger
/// *does* store in recoverable form is the mutation's observable
/// payload:
///
/// * the receipt's positional arguments (for `apply`/`emit` entries the
///   first argument is the value the caller passed), and
/// * each `StateDelta.after` (the exact committed value).
///
/// The reconstruction therefore rebuilds a *semantically equivalent*
/// pulse from those values, not the byte-identical recorded one. The
/// authoritative state check is the delta comparison (see
/// `ReplayEngine._verifyDeltas`), which compares committed values
/// against `delta.after` — not a pulse digest, which can never match.
///
/// ### How it works
/// Two paths:
///
/// * **Arguments path** — the receipt carries positional arguments. The
///   first argument is the payload the caller submitted (ingress emits
///   store the emitted value; `ValueCell` emit receipts store the
///   emitted value as their single positional argument).
/// * **Delta path** — no positional arguments, but the entry recorded
///   the committed `after` value. The pulse is rebuilt from the cell's
///   own delta (matched by cell id), falling back to the last delta.
///
/// A hand-crafted entry with neither produces `null`, which the engine
/// reports as a divergence — an entry that cannot be interpreted is not
/// a record of a mutation.
///
/// ### Non-obvious: the pulse body is the primary path
///
/// Entries appended by `Ledger.appendInternal` now store the materialised
/// pulse JSON (`entry.pulseJson`), and `Ledger.verify` checks it against
/// `pulseDigest`. [reconstruct] decodes that body with
/// `PulseCodec.fromJson` — payload, type, context, priority, parent
/// chain, and trace all round-trip. Parent pulses resolve by digest
/// through [parentsByDigest] (see below).
///
/// Older entries that carry no stored body fall back to the heuristic:
/// the first
/// positional receipt argument as the payload (exact for the emit/ingress
/// path; the *apply* path stores the command's argument, not the pulse
/// the receptor saw), then the entry's own delta `after`. Context,
/// priority, parent, trace, named arguments, and positional arguments
/// beyond the first are dropped on that path.
///
/// See also:
/// * [PulseCodec] — the codec that decodes the stored pulse body.
/// * [LedgerEntry.pulseJson] — the stored body itself.
/// {@category Replay}
abstract final class PulseReconstructor {
  /// Reconstructs the input pulse for [entry], or returns `null` if the
  /// entry cannot be reconstructed.
  ///
  /// ### Parameters:
  /// - [entry]: The ledger entry to reconstruct the pulse from.
  /// - [cell]: The resolved target cell; used to populate the pulse's
  ///   `source` field on the heuristic fallback path, which matters for
  ///   `TestPulseRule` validation.
  /// - [parentsByDigest]: Reconstructed parent pulses, keyed by digest;
  ///   the engine populates it as it replays earlier entries so stored
  ///   parent digests resolve.
  ///
  /// ### Returns:
  /// The reconstructed pulse, or `null` when the entry carries no
  /// recoverable pulse information.
  static Pulse<dynamic>? reconstruct({
    required LedgerEntry entry,
    required Cell cell,
    Map<String, Pulse<dynamic>>? parentsByDigest,
  }) {
    final storedBody = entry.pulseJson;
    if (storedBody != null) {
      final parentDigest = storedBody['parentDigest'] as String?;
      Pulse<dynamic>? parent;
      if (parentDigest != null) {
        parent = parentsByDigest?[parentDigest];
        if (parent == null) {
          // The chain prefix this pulse evolved from was not replayed
          // (partial replay); the body cannot be decoded alone.
          return null;
        }
      }
      try {
        final decoded = PulseCodec.fromJson(storedBody, parent: parent);
        parentsByDigest?[fingerprint(storedBody)] = decoded;
        return decoded;
      } catch (_) {
        // Malformed body: verify() already validated the digest; a
        // decode failure is a format error and reads as unreconstructable.
        return null;
      }
    }

    final args = entry.receipt.arguments.positionalArguments;
    if (args != null && args.isNotEmpty) {
      return Pulse<dynamic>(
        args.first,
        source: cell,
      );
    }

    StateDelta? delta;
    final cellId = entry.receiptCellId;
    for (final d in entry.deltas) {
      if (d.cellId == cellId) {
        delta = d;
        break;
      }
    }
    delta ??= entry.deltas.isEmpty ? null : entry.deltas.last;
    if (delta == null) return null;

    return Pulse<dynamic>(
      delta.after,
      source: cell,
    );
  }
}
