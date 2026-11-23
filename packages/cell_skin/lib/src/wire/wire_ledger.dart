// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// `LedgerEntry` ⇄ wire JSON.
///
/// The framework already ships the canonical ledger JSON
/// (`LedgerEntry.toJson` / `LedgerEntry.fromJson`); this library is a
/// thin facade so the skin's wire layer has a single vocabulary for the
/// ledger stream (`skin.ledger.entry` pulses).
library;

import 'package:cell/cell.dart';

/// The canonical ledger JSON form — identical to [LedgerEntry.toJson].
Map<String, Object?> wireLedgerEntryJson(LedgerEntry entry) => entry.toJson();

/// Decodes a ledger entry from its canonical JSON form.
LedgerEntry wireLedgerEntryFromJson(Map<String, Object?> json) =>
    LedgerEntry.fromJson(json);

/// The recorded cell id of [entry] — the value captured when the entry
/// was appended, immune to later registry resets.
String wireLedgerEntryCellId(LedgerEntry entry) => entry.receiptCellId;
