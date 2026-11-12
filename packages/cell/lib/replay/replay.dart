// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Causal Replay for the Cell framework.
///
/// Import `package:cell/replay.dart` to bring the replay module into
/// scope. Nothing in the core `package:cell/cell.dart` surface is
/// duplicated here; the two libraries are complementary.
library;

export 'codec/canonical_json.dart'
    show canonicalJsonEncode, canonicalJsonDecode;
export 'codec/fingerprint.dart' show fingerprint;
// Phase 2+ grows this list: PulseCodec, PulseContextCodec, CellSnapshot,
// CellGraphSnapshot, CellGraph, Purity, … — see research/Causal-Replay/Plan.md.
