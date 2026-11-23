// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The grammar every backend's memory ids share.
///
/// One path segment, `^[A-Za-z0-9._-]{1,128}$`, neither `.` nor `..`.
/// Backends that map ids to file names additionally reject Windows device
/// names; backends that map ids to Firestore document ids do not (Firestore
/// accepts `CON`), so the stricter check is opt-in.
final class MemoryIdGrammar {
  /// The shared grammar.
  static final RegExp pattern = RegExp(r'^[A-Za-z0-9._-]{1,128}$');

  /// Windows device names are reserved for every extension, so `CON.json`
  /// can never be created even though it passes the path grammar.
  static final RegExp windowsReserved =
      RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$', caseSensitive: false);

  /// Whether [id] satisfies the grammar (without throwing), for callers
  /// that filter collections of ids.
  static bool isValid(String id) =>
      id != '.' && id != '..' && pattern.hasMatch(id);

  /// Validates [id], throwing an [ArgumentError] before any IO.
  ///
  /// With [rejectWindowsReservedNames] the validator additionally rejects
  /// the device names Windows reserves; the file store uses this, the
  /// Firestore store does not.
  static void check(String id, {bool rejectWindowsReservedNames = false}) {
    if (!isValid(id)) {
      throw ArgumentError.value(
        id,
        'id',
        'memory id must match ^[A-Za-z0-9._-]{1,128}\$ and be one path '
            'segment (no separators, not "." or "..")',
      );
    }
    if (rejectWindowsReservedNames && windowsReserved.hasMatch(id)) {
      throw ArgumentError.value(
        id,
        'id',
        'memory id is a reserved device name on Windows',
      );
    }
  }
}
