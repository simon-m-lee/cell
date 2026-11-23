// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Cloud Firestore backend for `cell_memory`.
///
/// Import `package:cell_memory/cell_memory.dart` for the cell, the
/// envelope, and the MemoryStore contract; this library exports only the
/// store and the Firestore-tuned write policy. It does not re-export
/// `cell` or `cell_memory`.
library;

export 'src/firebase_store.dart'
    show
        FirebaseMemoryStore,
        decodeDocument,
        encodeDocument,
        firestoreWritePolicy;
