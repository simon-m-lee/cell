// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// When an accepted pulse schedules its store write.
enum MemoryWriteMode {
  /// Persist on every accepted pulse.
  immediate,

  /// Coalesce bursts. Default quiet period: 300 ms (shorter than the
  /// Flutter package's 1 s default; the two packages must not be confused).
  debounced,

  /// Only `save()` and `unload()` write. Link still delivers pulses into
  /// the memory cell's in-memory value.
  explicit,
}

/// The write-through configuration of a memory cell.
final class MemoryWritePolicy {
  /// Creates a write policy.
  const MemoryWritePolicy({
    this.mode = MemoryWriteMode.debounced,
    this.debounce = const Duration(milliseconds: 300),
    this.enabled = true,
  });

  /// The write mode. Defaults to [MemoryWriteMode.debounced].
  final MemoryWriteMode mode;

  /// The quiet period for [MemoryWriteMode.debounced].
  final Duration debounce;

  /// When `false`, no write is ever scheduled — including `unload`. Pass
  /// this during Causal Replay. Replay must not write historical pulses
  /// back to the store.
  final bool enabled;

  /// A policy that performs zero writes. Use with
  /// `MemoryCell.open(loadOnOpen: false, policy: MemoryWritePolicy.replay)`.
  static const MemoryWritePolicy replay = MemoryWritePolicy(enabled: false);
}
