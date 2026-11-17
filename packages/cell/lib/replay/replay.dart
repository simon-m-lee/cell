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
/// ### Non-obvious: cross-process identity requirement
///
/// A ledger recorded in one process can only be replayed in another if
/// every cell in the graph was **registered** with a [CellGraph]
/// (`register`/`registerState`). An unregistered cell's id is a
/// process-local identity hash and cannot be addressed from a ledger
/// file — registration is what makes identity stable.
///
/// ### When to use
/// The replay module spans several concerns — serialisation, identity,
/// journaling, the ledger, the replay engine, fork branching, governance
/// replay, and visualisation tooling. This barrel groups them behind one
/// import so callers do not chase individual part files, while keeping
/// `dart:io`-dependent pieces (`FileLedgerStore`) explicitly separate.
///
/// ### How it works
/// Re-exports the replay types from the core `cell` library (they are
/// parts of that library and reach into private pulse/context/cell
/// records), plus the web-safe codec helpers ([canonicalJsonEncode],
/// [canonicalJsonDecode], [fingerprint]) and the `dart:io`-backed
/// `FileLedgerStore` from its standalone library.
///
/// ### Non-obvious: web-safe core
/// - **Web-safe core**: the barrel itself does not import `dart:io`;
///   only the `FileLedgerStore` export does, and that file is a
///   standalone library.
/// - **Stable surface**: later layers grow the export list, not the
///   callers' import statements.
///
/// See also:
/// - [CellGraph] — the registry that makes identity stable.
/// - [Ledger] — the hash-chained record replayed by [ReplayEngine].
/// - [CellGraphVisualise], [LedgerVisualise] — the tooling exports.
/// {@category Replay}
library;

export 'codec/canonical_json.dart'
    show canonicalJsonEncode, canonicalJsonDecode;
export 'codec/fingerprint.dart' show fingerprint;
// The pulse/snapshot codecs and the graph types are parts of the core
// `cell` library (they reach into private pulse/context/cell records), so
// the barrel re-exports them from there.
export '../cell.dart'
    show
    // Serialisation.
    PulseCodec,
    PulseContextCodec,
    CellSnapshot,
    CellGraphSnapshot,
    // Registry + identity.
    Purity,
    CellGraph,
    CellGraphBuilder,
    RegisteredCell,
    CellGraphRegistry,
    // Journal.
    EffectJournal,
    EffectRecord,
    ClockEffect,
    UuidEffect,
    IoEffect,
    StreamEffect,
    TimerEffect,
    // Governance effect kinds.
    VerdictEffect,
    PolicyTickEffect,
    NullJournal,
    RecordingJournal,
    ReplayJournal,
    ReplayDivergenceException,
    JournalScope,
    Effectful,
    EffectfulReadOnly,
    // Ledger.
    StateDelta,
    Ledger,
    LedgerEntry,
    LedgerStore,
    InMemoryLedgerStore,
    LedgerIntegrityException,
    LedgerScope,
    // Replay engine.
    ReplayEngine,
    ReplayOptions,
    ReplayResult,
    DivergenceReport,
    PulseReconstructor,
    // What-if branching.
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
    // Governance replay.
    VersionRegistry,
    ContextTranslator,
    ContextTranslatorRegistry,
    CellGraphVersions,
    CellGraphTranslators,
    TestCellReplay,
    PolicyReplay,
    // Tooling (visualisation; the CLI itself is a
    // standalone dart:io library at lib/replay/cli/cli.dart, see
    // its file header for why it cannot be exported here).
    CellGraphVisualise,
    LedgerVisualise;
// FileLedgerStore is a standalone library (it imports dart:io, which
// must not leak into the web-safe core).
export 'ledger/file_store.dart' show FileLedgerStore;
// Later layers grow this list: ReplayEngine, … — see the
// individual library docs.