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
// The pulse/snapshot codecs and the graph types are parts of the core
// `cell` library (they reach into private pulse/context/cell records), so
// the barrel re-exports them from there.
export '../cell.dart'
    show
        // Phase 1 — serialisation.
        PulseCodec,
        PulseContextCodec,
        CellSnapshot,
        CellGraphSnapshot,
        // Phase 2 — registry + identity (grows in the next commit).
        Purity,
        RegisteredCell;
// Phase 3+ grows this list: EffectJournal, … — see
// research/Causal-Replay/Plan.md.
