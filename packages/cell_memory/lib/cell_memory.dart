// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Durable memory cells for the Cell framework — web-safe core.
///
/// Memory retains the latest value; the ledger retains causality. A
/// [MemoryCell] is itself a `Cell` — it loads stored data, receives pulses
/// through the framework, and emits [MemoryPulse]s downstream. Backends
/// implement [MemoryStore]; this library ships the pure-Dart surface plus
/// [InMemoryMemoryStore]. The `dart:io`-based [FileMemoryStore] lives in
/// `package:cell_memory/cell_memory_io.dart`, so importing this library
/// never pulls `dart:io` into a web build.
library;

export 'src/codec.dart'
    show MemoryCodec, MemoryNotSerializable, JsonMemoryCodec;
export 'src/envelope.dart' show JsonPayloadKey, MemoryEnvelope;
export 'src/id.dart' show MemoryIdGrammar;
export 'src/memory_cell.dart' show MemoryCell;
export 'src/memory_pulse.dart'
    show
        CollectiveMemoryPulse,
        MemoryEvent,
        MemoryPulse,
        memoryApplied,
        memoryLoaded,
        memoryRemoved,
        memoryStored,
        memoryUnloaded;
export 'src/policy.dart' show MemoryWriteMode, MemoryWritePolicy;
export 'src/remember.dart' show remember;
export 'src/scheduler.dart'
    show ManualScheduler, MemoryScheduler, TimerScheduler;
export 'src/store.dart'
    show
        MemoryConflict,
        MemoryCorrupt,
        MemoryIoException,
        MemoryStore,
        MemoryStoreCas,
        MemoryStoreException;
export 'src/stores/in_memory_store.dart' show InMemoryMemoryStore;

// ci: memory workflow trigger marker (remove in a later cleanup).
