// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../cell.dart';

/// A system for managing reactive connections between [Cell] instances.
///
/// [Synapses] manages connections between [Cell] objects in the reactive framework,
/// enabling signal propagation across a network of reactive components. It handles
/// both synchronous and asynchronous communication while ensuring proper validation
/// through [TestObject].
///
/// --** Core Features **--
///
/// Signal Propagation: Propagates signals from one [Cell] to linked cells
/// Dynamic Linking/Unlinking: Cells can be connected [link]/disconnected [unlink] at runtime
/// Validation Support: Checks [TestObject] rules before propagation
/// Thread-Safe Async: Supports [async] operations via [Synapses].async()
/// Bidirectional: Control	Can be enabled/disabled [Synapses.enabled]/[Synapses.disabled]
/// Error Handling: Gracefully handle errors during signal processing
///
/// Example:
/// ```dart
/// final cell1 = Cell();
/// final cell2 = Cell(synapses: Synapses([cell1])); // cell2 links to cell1
/// ```
abstract interface class Synapses<S extends Signal, L extends Cell> {

  /// Predefined constant for disabled synapses that ignore all operations.
  ///
  /// Using this will prevent any signal propagation through these synapses.
  /// Useful for creating inert or isolated cells.
  static const disabled = _SynapsesNever();

  /// Predefined constant for enabled synapses that will actively propagate signals.
  ///
  /// Creates a new empty synapse set that can have links added later.
  static const enabled = _SynapsesNever();

  /// Factory constructor for creating synapses with optional initial links.
  ///
  /// [links] - Optional initial set of cells to link to. If null, creates empty synapses.
  factory Synapses([Iterable<L>? links]) = _Synapses<S,L>;

  /// Propagates a signal through all linked cells.
  ///
  /// [signal] - The signal to propagate
  /// [notified] - Optional set to track which cells have already been notified
  ///              to prevent duplicate notifications in complex graphs
  void call(covariant S signal, {Set<Cell>? notified});

  /// Asynchronously propagates a signal through all linked cells.
  ///
  /// [signal] - The signal to propagate
  /// [notified] - Optional set to track notified cells
  Future<void> async(covariant S signal, {Set<Cell>? notified});

  /// Establishes a new connection from host to target cell.
  ///
  /// Parameters:
  /// - [link]: The cell to link to
  /// - [host]: The cell that owns these synapses (used for validation)
  ///
  /// Returns true if:
  /// 1. Host's test rules pass ([TestObject.link])
  /// 2. Connection didn't already exist
  bool link(L link, {required Cell host});

  /// Removes a link to another cell.
  ///
  /// [link] - The cell to unlink
  ///
  /// Returns true if the link existed and was removed, false otherwise
  bool unlink(L link);

}

base class _Synapses<S extends Signal, L extends Cell> implements Synapses<S,L>, Sync {

  final Set<L> _links;

  /// Creates a Linkable instance with optional initial links
  _Synapses([Iterable<L>? links])
      : _links = links != null ? (Set<L>.identity()..addAll(links)) : Set<L>.identity();


  @override
  bool link(L link, {required Cell host}) {
    return host.test.link(link, cell: host) && _links.add(link);
  }

  @override
  bool unlink(L link) => _links.remove(link);

  @override
  void call(covariant S signal, {Set<Cell>? notified}) {
    notified ??= Set<Cell>.identity();

    for (Cell c in _links) {
      if (notified.add(c) && c.test.signal(signal, cell: c)) {
        final receptor = c._properties.receptor;
        try {
          receptor(cell: c, signal: signal, notified: notified);
        } catch(_) {}
      }
    }
  }

  @override
  Future<void> async(covariant S signal, {Set<Cell>? notified}) async {
    return Future<void>(() {
      notified ??= Set<Cell>.identity();

      final futures = _links
          .where((c) => notified!.add(c) && c.test.signal(signal, cell: c))
          .map<Future>((c) => c._properties.receptor.async(cell: c, signal: signal, notified: notified));
      return Future.wait(futures).then((_) => null);
    });
  }
}



final class _SynapsesNever<S extends Signal, L extends Cell> implements Synapses<S,L> {

  const _SynapsesNever();

  @override
  bool link(L link, {required Cell host}) => false;

  @override
  bool unlink(L link) => false;

  @override
  void call(covariant S signal, {Set<Cell>? notified}) {}

  @override
  Future<void> async(covariant S signal, {Set<Cell>? notified}) {
    return Future<void>(() => null);
  }

}