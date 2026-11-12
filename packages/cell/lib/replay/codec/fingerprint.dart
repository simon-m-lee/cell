// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;

import 'canonical_json.dart';

/// Computes the SHA-256 fingerprint of a canonical JSON value, hex-encoded.
///
/// Fingerprints are the unit of identity in the replay ledger:
///
/// * [CellSnapshot.configFingerprint] — identifies a cell's receptor + rule
///   + context configuration. A cell whose fingerprint changed between
///   recording and replay is a hard divergence (Phase 5).
/// * PulseDigest — identifies a pulse's fully expanded lineage. Two pulses
///   with the same digest are byte-identical, which the ledger uses to
///   reconstruct without storing the whole chain per entry.
///
/// Returns the hex string, not the `Digest` object, because every consumer
/// eventually serialises it — returning hex here removes a second encoding
/// step everywhere.
String fingerprint(Object? value) {
  final canonical = canonicalJsonEncode(value);
  final digest = sha256.convert(utf8.encode(canonical));
  return digest.toString();
}
