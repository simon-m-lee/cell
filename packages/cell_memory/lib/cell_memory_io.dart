// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The **Local Disk Sub-cortex** of `cell_memory` — the `dart:io` backend
/// that turns a memory id into a JSON file on the host filesystem.
///
/// Import this library in addition to `package:cell_memory/cell_memory.dart`
/// when you want the file store; the core library stays web-safe. The split
/// is structural, not stylistic: `cell_memory.dart` must compile for Flutter
/// Web, and `dart:io` does not. Separating the backend into its own library
/// is what lets one package serve mobile, desktop, and web without a
/// conditional-import dance at every call site.
///
/// In the framework's biological metaphor, this is the **Local Disk
/// Sub-cortex**: the part of Memory that writes to a physical substrate
/// (files under a root directory) rather than living purely in the
/// process's working set.
///
/// ### Why it is used
/// - **Web-safe by structure**: A web build that imports only
///   `package:cell_memory/cell_memory.dart` never sees `dart:io`. Nothing
///   is tree-shaken to make this true — the import graph simply does not
///   contain it.
/// - **Explicit opt-in**: Adding `import 'package:cell_memory/cell_memory_io.dart';`
///   is a one-line declaration that this build targets a filesystem and
///   knows it. No hidden IO on a platform that cannot do IO.
/// - **Single symbol surface**: Exactly one public type ([FileMemoryStore])
///   is exported here. Everything else a caller needs — [MemoryStore],
///   [MemoryEnvelope], [MemoryCell], [MemoryIdGrammar] — comes from the
///   web-safe library, so the two imports never overlap.
///
/// ### How it works
/// 1. A caller imports `cell_memory.dart` for the cell, envelope, and store
///    contract, and `cell_memory_io.dart` for the file backend.
/// 2. `FileMemoryStore.directory(root)` or `FileMemoryStore.file(file)`
///    constructs a [FileMemoryStore] bound to a path on the host.
/// 3. That instance is passed wherever a [MemoryStore] is expected —
///    `MemoryCell.open(store: ...)`, `remember(store: ...)`, or a
///    Firestore-style swap for a different backend. No call site knows or
///    cares that the store is file-backed.
/// 4. The `dart:io` import lives entirely inside
///    `src/stores/file_store.dart`; this barrel merely re-exports the
///    public type.
///
/// ### Technical Details
/// - **No conditional imports**: The split is deliberate. `dart:io` cannot
///   be loaded on the web at all, and conditional imports would push the
///   decision into every file that touches a store. One extra import in
///   the app's composition root is the cost; one conditional-import
///   helper per call site is the alternative, and it is worse.
/// - **Single-symbol export**: Only [FileMemoryStore] is exported. Internal
///   helpers in `src/stores/file_store.dart` (path construction, tmp-file
///   cleanup, case-collision checks) are not part of the public surface and
///   can change without a breaking version.
/// - **Backend-neutral contract**: Every method this type implements is
///   declared on [MemoryStore] in the web-safe library. Nothing here adds
///   IO-specific surface — a Firestore backend satisfies the same
///   interface with the same semantics.
///
/// See also:
/// - [FileMemoryStore] — the only public type in this library.
/// - [MemoryStore] — the backend contract [FileMemoryStore] implements.
/// - [MemoryCell] — the durable cell that consumes a store.
/// - `package:cell_memory/cell_memory.dart` — the web-safe core library
///   this one extends.
///
/// ### AI Agent Guide
/// **Layer:** Memory — this is the `dart:io` backend split. Not a `Cell`
/// factory, not a `Flow` operator, not a `Tissue` book.
/// **When to use:** a server or desktop app that wants durable memory
/// backed by the local filesystem.
/// **When NOT to use:**
///   - in a Flutter Web build (this library does not compile for web —
///     that is its purpose);
///   - when a cloud backend (Firestore) is the target — this barrel
///     exports only the file store;
///   - when in-memory persistence is enough for the lifetime of one
///     process (use [InMemoryMemoryStore] from the web-safe library).
/// **Live signature:** `library cell_memory_io;` — pinned at
/// `cell_memory: 0.1.0`.
/// **Do NOT confuse with:** `package:cell_memory/cell_memory.dart` (the
/// web-safe core this library extends) — the two imports are meant to be
/// used together, not interchangeably. Do not import `cell_memory_io.dart`
/// when the target does not have `dart:io`.
/// **Guide:** see the memory HowTo for "choosing a store backend".
/// **Example:** `example/memory_file_example.dart`.
/// **Cross-layer:** [FileMemoryStore] satisfies the same [MemoryStore]
/// contract as [InMemoryMemoryStore] and a future Firestore backend; the
/// choice of backend is a composition-root decision, not a call-site one.
/// **Minimal compilable example**
/// ```dart
/// import 'dart:io';
///
/// import 'package:cell_memory/cell_memory.dart';
/// import 'package:cell_memory/cell_memory_io.dart';
///
/// Future<void> main() async {
///   final store =
///       FileMemoryStore.directory(Directory.systemTemp.createTempSync().path
///           as dynamic);
///   final counter = await MemoryCell.open<int>(
///     id: 'counter',
///     store: store,
///     codec: JsonMemoryCodec<int>.identity(),
///     initial: 0,
///   );
///   print(counter.loaded); // true
///   await counter.close();
///   await store.close();
/// }
/// ```
library;

export 'src/stores/file_store.dart' show FileMemoryStore;