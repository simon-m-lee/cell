// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert';

/// The current route, as an immutable value.
///
/// [CellRouterStateMirror] writes one of these into its state cell on
/// every route change, so widgets can observe navigation reactively
/// (`CellBuilder`, `CellSelector`, `useCellRouter`).
///
/// ### What is (and is not) restored
/// [toJson] / [fromJson] persist [location] and [queryParams]; [extra]
/// is deliberately excluded — extras are live Dart objects that cannot
/// survive a process boundary. Restoration restores the location and
/// query parameters; extras must be re-supplied by the app.
class CellRouterState {
  /// Creates a route state.
  const CellRouterState({
    required this.location,
    this.queryParams = const {},
    this.extra,
  });

  /// The full location string (path + query), e.g. `/detail/42?tab=info`.
  final String location;

  /// The decoded query parameters.
  final Map<String, String> queryParams;

  /// The optional extra object passed to `go`/`push`/`replace`.
  final Object? extra;

  /// Decodes from the persisted JSON form ([toJson]).
  factory CellRouterState.fromJson(Map<Object?, Object?> json) {
    return CellRouterState(
      location: json['location'] as String? ?? '/',
      queryParams: {
        for (final entry in (json['queryParams'] as Map<Object?, Object?>? ??
                const <Object?, Object?>{})
            .entries)
          '${entry.key}': '${entry.value}',
      },
    );
  }

  /// The persisted form (no [extra]).
  Map<String, Object?> toJson() => {
        'location': location,
        'queryParams': queryParams,
      };

  /// True when [extra] survives a JSON round-trip; used by tests to
  /// prove [extra] is intentionally excluded from persistence.
  bool get extraIsJsonSafe {
    try {
      final decoded = jsonDecode(jsonEncode(extra));
      return decoded == extra || extra == null;
    } catch (_) {
      return false;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CellRouterState &&
      other.location == location &&
      other.queryParams.length == queryParams.length &&
      other.queryParams.entries
          .every((entry) => other.queryParams[entry.key] == entry.value) &&
      other.extra == extra;

  @override
  int get hashCode => Object.hash(
      location,
      Object.hashAllUnordered(
          queryParams.entries.map((e) => Object.hash(e.key, e.value))),
      extra);

  @override
  String toString() => 'CellRouterState($location, '
      'query=${queryParams.isEmpty ? '{}' : queryParams}, extra=$extra)';
}
