// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../cell.dart';

// ignore_for_file: prefer_typing_uninitialized_variables

/// Encapsulates the core characteristics of a Cell, including its receptor, linkage state, and validation tests.
class Properties {

  /// A storage record for the properties of a cell
  final record;

  /// Constructs a [Properties] object with optional parameters.
  ///
  /// Parameters:
  /// - [bind]: Optional [Cell] to bind to (creates parent-child relationship)
  /// - [receptor]: How this cell processes incoming signals (default: Receptor.unchanged)
  /// - [test]: TestObject that validates operations (default: TestObject.passed)
  /// - [synapses]: Whether this cell can be linked to others (default: Linkable.enabled)
  Properties({
    Cell? bind,
    Receptor receptor = Receptor.unchanged,
    TestObject test = TestObject.passed,
    MapObject? mapObject,
    Synapses synapses = Synapses.enabled
  }) : record = (bind: bind, receptor: receptor, test: test, mapObject: mapObject, synapses: synapses);

  /// Creates Properties from a record
  Properties.fromRecord([Record this.record = ()]);

  /// The link manager for cell relationships
  late final Synapses synapses = _synapses();

  Synapses _synapses() {
    try {
      return record.synapses ?? Synapses();
    } catch(_) {}
    return Synapses();
  }

  /// The cell this cell is bound to (if any)
  Cell? get bind => record.bind;

  /// The receptor handling signal processing
  Receptor get receptor => record.receptor ?? Receptor.unchanged;

  /// The test rules for validation
  TestObject get test => record.test ?? TestObject.passed;

}
