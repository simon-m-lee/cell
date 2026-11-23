// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The skin's client-facing exception.
///
/// Thrown when the membrane answers with a [WireError], when it is
/// closed while a request is pending, or when an unexpected wire
/// message arrives.
/// {@category Features}
library;

/// A wire-level failure surfaced to a skin client.
final class SkinError implements Exception {
  /// The stable error code (`unknown_tool`, `conflict`,
  /// `cursor_required`, `bad_arguments`, `closed`, …).
  final String code;

  /// A human-readable description (never raw remote internals).
  final String message;

  const SkinError(this.code, this.message);

  @override
  String toString() => 'SkinError($code): $message';
}
