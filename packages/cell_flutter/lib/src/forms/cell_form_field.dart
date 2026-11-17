// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/widgets.dart';

import '../cell_notifier.dart';

/// A [FormField] whose value is bound two-way to a [ValueCell<T>].
///
/// [CellFormField] is the **Cell-Bound Generic Field** — the non-text
/// counterpart of [CellTextField]. Dropdowns, sliders, checkboxes, date
/// pickers: any input that reports its value through
/// `FormFieldState.didChange` binds to a cell with one widget.
///
/// ### How it works
/// 1. The widget is a real [FormField], so [builder] receives a standard
///    [FormFieldState] and `Form.validate()` runs [validator] through the
///    standard mechanism.
/// 2. `didChange` (called by the input inside [builder]) commits the value
///    to the cell.
/// 3. A cell write (from anywhere in the graph) calls
///    `FormFieldState.didChange` on the field, so the input re-renders and
///    re-validates.
/// 4. Both directions are equality-guarded, so the two-way sync cannot
///    loop.
///
/// ### Example
/// ```dart
/// CellFormField<DateTime>(
///   cell: dueDate.cell,
///   validator: (d) => d == null ? 'Required' : null,
///   builder: (state) => InkWell(
///     onTap: () async {
///       final picked = await showDatePicker(/* ... */);
///       if (picked != null) state.didChange(picked);
///     },
///     child: Text(state.value?.toString() ?? 'Select'),
///   ),
/// );
/// ```
///
/// ### See Also:
/// - [CellTextField] — the text-field counterpart.
/// - [FormField] — the Flutter widget this extends; the state contract is
///   identical.
class CellFormField<T> extends FormField<T> {
  /// Creates a form field bound to [cell].
  CellFormField({
    required ValueCell<T> cell,
    required super.builder,
    super.validator,
    super.autovalidateMode,
    super.enabled = true,
    super.key,
  })  : _cell = cell,
        super(initialValue: cell.value);

  final ValueCell<T> _cell;

  /// The cell bound to this field's value.
  ValueCell<T> get cell => _cell;

  @override
  FormFieldState<T> createState() => _CellFormFieldState<T>();
}

class _CellFormFieldState<T> extends FormFieldState<T> {
  CellNotifier<T>? _notifier;
  bool _syncing = false;

  CellFormField<T> get _field => widget as CellFormField<T>;

  @override
  void initState() {
    super.initState();
    _notifier = CellNotifier<T>(_field.cell)..addListener(_syncFromCell);
  }

  @override
  void didUpdateWidget(CellFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cell, _field.cell)) {
      _notifier?.removeListener(_syncFromCell);
      _notifier?.dispose();
      _notifier = CellNotifier<T>(_field.cell)..addListener(_syncFromCell);
      // Deferred: didChange marks the enclosing Form dirty, which must not
      // happen while that Form is being built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncFromCell();
      });
    }
  }

  /// Cell → field: adopt the cell's current value through the standard
  /// `FormFieldState.didChange` path (validation + rebuild included).
  void _syncFromCell() {
    if (_syncing || !mounted) return;
    final incoming = _notifier!.value;
    if (value == incoming) return;
    _syncing = true;
    try {
      didChange(incoming);
    } finally {
      _syncing = false;
    }
  }

  /// Field → cell: commits values reported by the input widget.
  @override
  void didChange(T? newValue) {
    super.didChange(newValue);
    if (_syncing) return;
    if (_field.cell.value == newValue) return;
    _syncing = true;
    try {
      _field.cell.value = newValue;
    } finally {
      _syncing = false;
    }
  }

  @override
  void dispose() {
    final notifier = _notifier;
    _notifier = null;
    if (notifier != null) {
      notifier.removeListener(_syncFromCell);
      notifier.dispose();
    }
    super.dispose();
  }
}
