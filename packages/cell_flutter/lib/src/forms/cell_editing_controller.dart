// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/widgets.dart';

import '../cell_notifier.dart';

/// A [TextEditingController] bound **two-way** to a [ValueCell<String>].
///
/// [CellEditingController] is the **Cell-Bound Text Adapter** — the
/// foundation under [CellTextField]. Writes to the controller's [text]
/// update the cell; writes to the cell update the controller. The
/// feedback loop is broken by equality guards on both directions: a
/// controller update that mirrors the current cell value does not write
/// back, and a cell update that mirrors the current controller text does
/// not touch the controller.
///
/// ### Cursor preservation
/// A cell-driven update preserves the cursor **offset from the end** of
/// the text. Typing at the end of a field therefore keeps the cursor at
/// the end even when the cell echoes the same text back (for example
/// through a debounced pipeline). A length-changing replacement moves the
/// cursor to the clamped equivalent offset — a full replacement lands the
/// cursor at the end, which is the natural expectation for an external
/// write.
///
/// ### Lifecycle
/// Call [dispose] when the controller is no longer needed — it releases
/// the internal cell observation. [CellTextField] does this for you; only
/// manual users of [cellEditingController] need to.
///
/// ### See Also:
/// - [cellEditingController] — the factory.
/// - [CellTextField] — the widget that owns this controller's lifecycle.
/// - [CellNotifier] — the internal cell observation.
class CellEditingController extends TextEditingController {
  /// Binds [cell] to this controller, seeding [text] from the cell's
  /// current value.
  CellEditingController(this._cell) : super(text: _cell.value ?? '') {
    _notifier = CellNotifier<String>(_cell)..addListener(_syncFromCell);
    addListener(_syncToCell);
  }

  final ValueCell<String> _cell;

  CellNotifier<String>? _notifier;

  bool _syncing = false;

  /// The cell this controller is bound to.
  ValueCell<String> get cell => _cell;

  /// Controller → cell: a user edit (or any controller write) commits the
  /// new text to the cell, unless the cell already holds it.
  void _syncToCell() {
    if (_syncing) return;
    if (_cell.value == text) return;
    _syncing = true;
    try {
      _cell.value = text;
    } finally {
      _syncing = false;
    }
  }

  /// Cell → controller: a cell write updates [text], preserving the
  /// cursor's offset from the end where feasible.
  void _syncFromCell() {
    if (_syncing) return;
    final incoming = _notifier!.value ?? '';
    if (text == incoming) return;
    _syncing = true;
    try {
      final offsetFromEnd = text.length - selection.baseOffset;
      value = value.copyWith(
        text: incoming,
        selection: TextSelection.collapsed(
          offset: (incoming.length - offsetFromEnd).clamp(0, incoming.length),
        ),
      );
    } finally {
      _syncing = false;
    }
  }

  @override
  void dispose() {
    removeListener(_syncToCell);
    final notifier = _notifier;
    _notifier = null;
    if (notifier != null) {
      notifier.removeListener(_syncFromCell);
      notifier.dispose();
    }
    super.dispose();
  }
}

/// Creates a [CellEditingController] bound to [cell].
///
/// ```dart
/// final controller = cellEditingController(email.cell);
/// // Use anywhere TextEditingController is accepted.
/// ```
///
/// The returned controller must be [TextEditingController.dispose]d by
/// the caller when no longer needed.
CellEditingController cellEditingController(ValueCell<String> cell) =>
    CellEditingController(cell);
