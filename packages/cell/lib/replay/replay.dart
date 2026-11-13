// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Causal Replay for the Cell framework.
///
/// Import `package:cell/replay.dart` to bring the replay module into
/// scope. Nothing in the core `package:cell/cell.dart` surface is
/// duplicated here; the two libraries are complementary. In practice the
/// core library already exports most replay types (they are parts of the
/// `cell` library), so a program may import either or both — this barrel
/// exists as the focused, stable surface for replay consumers.
///
/// ### Cross-process identity requirement
///
/// A ledger recorded in one process can only be replayed in another if
/// every cell in the graph was **registered** with a `CellGraph`
/// (`register`/`registerState`). An unregistered cell's id is a
/// process-local identity hash and cannot be addressed from a ledger
/// file — registration is what makes identity stable (Phase 2).
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
        // Phase 2 — registry + identity.
        Purity,
        CellGraph,
        CellGraphBuilder,
        RegisteredCell,
        CellGraphRegistry,
        // Phase 3 — journal.
        EffectJournal,
        EffectRecord,
        ClockEffect,
        UuidEffect,
        IoEffect,
        StreamEffect,
        TimerEffect,
        // Phase 7 — governance effect kinds.
        VerdictEffect,
        PolicyTickEffect,
        NullJournal,
        RecordingJournal,
        ReplayJournal,
        ReplayDivergenceException,
        JournalScope,
        Effectful,
        EffectfulReadOnly,
        // Phase 4 — ledger.
        StateDelta,
        Ledger,
        LedgerEntry,
        LedgerStore,
        InMemoryLedgerStore,
        LedgerIntegrityException,
        LedgerScope,
        // Phase 5 — replay engine.
        ReplayEngine,
        ReplayOptions,
        ReplayResult,
        DivergenceReport,
        PulseReconstructor,
        // Phase 6 — what-if branching.
        ForkHandle,
        ForkRecord,
        ForkPolicy,
        Mutation,
        ForkLedgerStore,
        ForkIntegrityException,
        CellGraphFork,
        ReplayEngineFork,
        ForkVerify,
        ForkParentLookup,
        // Phase 7 — governance replay.
        VersionRegistry,
        ContextTranslator,
        ContextTranslatorRegistry,
        CellGraphVersions,
        CellGraphTranslators,
        TestCellReplay,
        PolicyReplay,
        // Phase 8 — tooling (visualisation; the CLI itself is a
        // standalone dart:io library at lib/replay/cli/cli.dart, see
        // its file header for why it cannot be exported here).
        CellGraphVisualise,
        LedgerVisualise;
// FileLedgerStore is a standalone library (it imports dart:io, which
// must not leak into the web-safe core).
export 'ledger/file_store.dart' show FileLedgerStore;
// Phase 5+ grows this list: ReplayEngine, … — see
// research/Causal-Replay/Plan.md.
