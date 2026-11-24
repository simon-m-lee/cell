// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The frozen wire version and the shared error-status table.
///
/// Every encoded [WireMessage] body and every SSE `data` object carries
/// `wire: "1"`. A missing field decodes as version 1, so a 0.2 peer
/// still parses; a server always sends the field. Any other value is
/// `unsupported wire version` — a `FormatException` on the shared
/// decoder and `400 bad_json` on REST, with the fixed text never copied
/// into an HTTP body.
///
/// [skinErrorStatus] is the same table as `test/goldens/wire/errors/`:
/// code, HTTP status, and whether a receipt exists. New codes may be
/// added; old codes do not move.
/// {@category Features}
library;

/// The wire version every encoded body carries.
///
/// ### AI Agent Guide
/// **Layer:** Skin — the wire version every encoded body carries.
/// **When to use:** checking `wire` at decode time through
/// [requireSkinWireVersion], or stamping an encoded body with [withWire].
/// **When NOT to use:** inventing a second version — the freeze table
/// lives in `HowTo-WireStability.md`.
/// **Live signature:** `const String skinWireVersion = '1'` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
const String skinWireVersion = '1';

/// Stamps [fields] with `wire: "1"`. Encode-time only: no
/// [WireMessage] subclass keeps the field, so no constructor changed.
Map<String, Object?> withWire(Map<String, Object?> fields) => {
      'wire': skinWireVersion,
      ...fields,
    };

/// The version gate for a decoded body.
///
/// A missing field is version 1 (a 0.2 peer did not send it). The
/// value `"1"` passes. Anything else — `"2"`, `2`, `""`, `null`, a
/// missing string type — throws the fixed
/// `FormatException('unsupported wire version')`.
void requireSkinWireVersion(Map<String, Object?> json) {
  if (!json.containsKey('wire')) return;
  if (json['wire'] == skinWireVersion) return;
  throw const FormatException('unsupported wire version');
}

/// Code → HTTP status. The contract twin of
/// `test/goldens/wire/errors/`: the same codes, the same statuses. A
/// row in this table means "no receipt exists" — these are pre-apply or
/// adapter-local codes, never `WireResponse`s.
///
/// `queue_full` is reserved here; the queue cap is the first producer.
const Map<String, int> skinErrorStatus = {
  'unknown_tool': 404,
  'bad_arguments': 422,
  'cursor_required': 428,
  'conflict': 409,
  'idempotency_conflict': 409,
  'forbidden': 403,
  'queue_timeout': 504,
  'outcome_unknown': 504,
  'queue_full': 429,
  'verify_failed': 500,
  'host_not_allowed': 403,
  'origin_not_allowed': 403,
  'transport_error': 500,
};
