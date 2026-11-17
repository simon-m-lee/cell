// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Causal Replay for the Cell framework — public barrel.
///
/// Import this library to use the replay module without importing
/// `package:cell/cell.dart` directly:
///
/// ```dart
/// import 'package:cell/replay.dart';
/// ```
///
/// ### When to use
/// The core `cell` library is large and web-safe. The replay module is
/// opt-in: an application that does not need forensic history, hash
/// chains, or fork branching pays nothing for them. This barrel is the
/// focused, stable surface a replay consumer imports, so the public
/// replay API can evolve without broadening the core import.
///
/// ### How it works
/// This library is a pure re-export barrel. It contains no logic: it
/// forwards the replay types (codecs, graph registry, journal, ledger,
/// replay engine, fork branching, governance replay, and visualisation
/// tooling) from their defining parts and from the core `cell` library.
/// `FileLedgerStore` is exported from a standalone `dart:io` library so
/// that the web-safe core never imports `dart:io`.
///
/// ### Non-obvious: complementary to core, cross-process identity
/// - **Complementary to core**: nothing in `package:cell/cell.dart` is
///   duplicated here; the two libraries share the same types.
/// - **Cross-process identity**: a ledger recorded in one process can
///   only be replayed in another if every cell was registered with a
///   [CellGraph] — registration is what makes identity stable.
///
/// See also:
/// - `package:cell/cell.dart` — the core library this barrel complements.
/// - `lib/replay/cli/cli.dart` — the standalone CLI (`dart:io`, cannot be
///   exported from a web-safe barrel).
/// {@category Replay}
library;

export 'replay/replay.dart';