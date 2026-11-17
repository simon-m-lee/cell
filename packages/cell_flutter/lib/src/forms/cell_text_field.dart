// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
// Flutter >=3.47 deprecates the material library in favour of
// material_ui; kept for compatibility with the stable SDK used here.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'cell_editing_controller.dart';

/// A [TextFormField] whose value is bound two-way to a [ValueCell<String>].
///
/// [CellTextField] is the **Cell-Bound Text Field** — the one-line answer
/// to \"bind a text field to a cell\": typing updates the cell, cell
/// updates re-render the field, and the enclosing [Form]'s validation
/// works unchanged because the widget is a `TextFormField` underneath.
///
/// ### How it works
/// 1. A [CellEditingController] binds the field's text to [cell] with the
///    equality-guarded two-way sync (typing → cell; cell → field with
///    cursor preservation).
/// 2. [validator] and [autovalidateMode] are forwarded to the inner
///    `TextFormField`, so `Form.validate()` reports this field's errors
///    through the standard `FormFieldState` mechanism.
/// 3. A cell swap in `didUpdateWidget` rebinds the controller; the field
///    keeps focus because the controller is replaced, not the element.
///
/// ### Focus and cursor
/// Focus is preserved across cell updates (the controller is never
/// disposed on update). The cursor's offset from the end is preserved on
/// cell-driven updates; see [CellEditingController] for the exact rule.
///
/// ### Example
/// ```dart
/// CellTextField(
///   cell: email.cell,
///   decoration: const InputDecoration(labelText: 'Email'),
///   validator: (v) => v?.contains('@') == true ? null : 'Invalid email',
/// );
/// ```
///
/// ### See Also:
/// - [CellEditingController] / [cellEditingController] — the underlying
///   adapter, for direct controller access.
/// - [CellFormField] — the generic non-text field.
/// - [TextFormField] — the Flutter widget this composes.
class CellTextField extends StatefulWidget {
  /// Creates a text field bound to [cell].
  const CellTextField({
    required this.cell,
    this.decoration,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    super.key,
  });

  /// The cell bound to the field's text.
  final ValueCell<String> cell;

  /// Forwarded to the inner [TextFormField].
  final InputDecoration? decoration;

  /// Forwarded to the inner [TextFormField].
  final TextInputType? keyboardType;

  /// Forwarded to the inner [TextFormField]; hides the entered text for
  /// password fields.
  final bool obscureText;

  /// Forwarded to the inner [TextFormField]; runs on `Form.validate()`.
  final String? Function(String?)? validator;

  /// Forwarded to the inner [TextFormField].
  final AutovalidateMode? autovalidateMode;

  /// Called with the new text whenever the field's value changes.
  final void Function(String value)? onChanged;

  @override
  State<CellTextField> createState() => _CellTextFieldState();
}

class _CellTextFieldState extends State<CellTextField> {
  late CellEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CellEditingController(widget.cell);
    _controller.addListener(_notifyOnChanged);
  }

  void _notifyOnChanged() => widget.onChanged?.call(_controller.text);

  @override
  void didUpdateWidget(CellTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cell, widget.cell)) {
      _controller.dispose();
      _controller = CellEditingController(widget.cell);
      _controller.addListener(_notifyOnChanged);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      decoration: widget.decoration,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
    );
  }
}
