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

/// Converts a forensic record into its wire-safe **Skin Form**.
///
/// In the framework's biological metaphor, this function stamps a
/// **Forensic Ledger Row** for egress. It ensures that the sequence,
/// timestamp, and causal metadata of a **Somatic State Transition** are
/// preserved in a JSON-safe format.
///
/// ### See also
/// - [LedgerEntry.toJson]: The underlying canonical serialization.
Map<String, Object?> wireLedgerEntryJson(LedgerEntry entry) => entry.toJson();

/// Decodes a **Skin Form** JSON map back into a forensic record.
///
/// In the framework's biological metaphor, this acts as the
/// **Forensic Decoder**. It reconstructs the technical audit row from a
/// signal received at the membrane, typically used by remote auditors or
/// synchronization deputies.
///
/// ### See also
/// - [LedgerEntry.fromJson]: The underlying canonical reconstruction.
LedgerEntry wireLedgerEntryFromJson(Map<String, Object?> json) =>
    LedgerEntry.fromJson(json);

/// Extracts the permanent **Somatic Address** captured within the forensic record.
///
/// This returns the [cellId] as it existed at the exact moment the
/// **Somatic State Transition** was physically anchored. Unlike looking
/// up a cell in a live registry, this value is immune to later renames or
/// registry resets, providing absolute forensic integrity for the audit trail.
String wireLedgerEntryCellId(LedgerEntry entry) => entry.receiptCellId;
