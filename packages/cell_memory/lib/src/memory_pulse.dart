// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';

import 'memory_cell.dart';

/// What a [MemoryCell] just did. One event per emitted pulse.
///
/// Not a bitmask: memory operations do not combine the way `TissueEvent`
/// flags do (`elementAdded | elementUpdated`).
enum MemoryEvent {
  /// `load()` restored an envelope and is notifying listeners.
  loaded,

  /// A pulse was accepted and became the retained value.
  applied,

  /// `save()` wrote an envelope. Emitted only after the write succeeds.
  stored,

  /// `unload()` flushed and is about to stop emitting.
  unloaded,

  /// `remove()` deleted the durable record.
  removed,
}

/// The structural signal emitted by a [MemoryCell].
///
/// A [MemoryPulse] is a [Pulse]: downstream cells linked on the memory
/// cell's synapses observe it as an ordinary signal. [payload] carries the
/// retained value [T], exactly like [Pulse.payload]. The envelope is not
/// the payload — a listener on a counter receives `Pulse<int>`, not a
/// document with `schema` and `codec`.
abstract interface class MemoryPulse<T> implements Pulse<T> {
  /// The durability event this pulse reports.
  MemoryEvent get event;

  /// The stable memory id of the emitting cell.
  String get memoryId;

  /// The store revision at the moment of emission. For [MemoryEvent.loaded]
  /// and [MemoryEvent.stored] it is the envelope's revision; for
  /// [MemoryEvent.applied] and [MemoryEvent.unloaded] it is the last
  /// successful store revision; for [MemoryEvent.removed] it is 0.
  int get revision;

  @override
  MemoryCell<T>? get source;

  @override
  MemoryPulse<T> withStep(String step);

  @override
  MemoryPulse evolve({Pulse? pulse, String? step, PulseContext? context});

  @override
  MemoryPulse<T> get unmodifiable;
}

/// A bundle of memory pulses travelling as one wave.
///
/// The `+` operator is inherited from [Pulse] unchanged: at cell 2.1.0 a
/// cross-library interface cannot narrow `operator +` while also
/// implementing [CollectivePulse] — the two inherited `+` signatures form
/// an unsatisfiable diamond. `memoryPulse1 + memoryPulse2` still yields a
/// framework [CollectivePulse].
abstract interface class CollectiveMemoryPulse<T>
    implements MemoryPulse<Iterable<Pulse<T>>>, CollectivePulse<T> {
  /// Bundles [pulses] into one collective.
  factory CollectiveMemoryPulse.from(Iterable<MemoryPulse<T>> pulses) =
      _CollectiveMemoryPulse<T>;
}

/// The concrete base of the memory pulse family: extends the framework's
/// [PulseBase] so `Synapses.call` can broadcast it, and implements the
/// [MemoryPulse] narrowing. Application code does not build these directly.
abstract class MemoryPulseBase<T> extends PulseBase<T>
    implements MemoryPulse<T> {
  /// Creates a memory pulse.
  MemoryPulseBase({
    required this.event,
    required this.memoryId,
    required this.revision,
    super.payload,
    MemoryCell<T>? source,
    super.context,
    super.timestamp,
    super.step,
    super.parent,
    super.pulse,
    super.priority,
  }) : super(source: source, type: event);

  @override
  final MemoryEvent event;

  @override
  final String memoryId;

  @override
  final int revision;

  @override
  MemoryCell<T>? get source => super.source as MemoryCell<T>?;

  @override
  Iterator<PulseBase> get iterator => [this].iterator;

  /// Appends [step] to the trace as a new memory pulse whose parent is this
  /// one.
  @override
  MemoryPulseBase<T> withStep(String step) => _MemoryPulse<T>(
        event: event,
        memoryId: memoryId,
        revision: revision,
        step: step,
        parent: this,
      );

  /// Evolves this pulse into a new memory pulse linked to it as parent.
  @override
  MemoryPulseBase evolve({Pulse? pulse, String? step, PulseContext? context}) =>
      _MemoryPulse<T>(
        event: event,
        memoryId: memoryId,
        revision: revision,
        pulse: pulse,
        step: step,
        context: context,
        parent: this,
      );

  /// A read-only projection of this pulse.
  @override
  MemoryPulseBase<T> get unmodifiable => _UnmodifiableMemoryPulse<T>(this);
}

/// The concrete memory pulse. Constructed by the memory cell; application
/// code does not build it except in tests.
class _MemoryPulse<T> extends MemoryPulseBase<T> {
  _MemoryPulse({
    required super.event,
    required super.memoryId,
    required super.revision,
    super.payload,
    super.source,
    super.context,
    super.timestamp,
    super.step,
    super.parent,
    super.pulse,
  });
}

class _CollectiveMemoryPulse<T> extends MemoryPulseBase<Iterable<Pulse<T>>>
    implements CollectiveMemoryPulse<T> {
  _CollectiveMemoryPulse(Iterable<MemoryPulse<T>> pulses)
      : _pulses = List<MemoryPulse<T>>.unmodifiable(pulses),
        super(
          event: _collectiveEvent(pulses),
          memoryId: _collectiveMemoryId(pulses),
          revision: _collectiveRevision(pulses),
          payload: pulses.toList(growable: false),
          context: pulses.isEmpty ? null : pulses.first.context,
          timestamp: pulses.isEmpty ? null : pulses.first.timestamp,
          priority: pulses.isEmpty ? null : pulses.first.priority,
        );

  static MemoryEvent _collectiveEvent(Iterable<MemoryPulse> pulses) {
    final events = pulses.map((pulse) => pulse.event).toSet();
    return events.length == 1 ? events.first : MemoryEvent.applied;
  }

  static String _collectiveMemoryId(Iterable<MemoryPulse> pulses) {
    final ids = pulses.map((pulse) => pulse.memoryId).toSet();
    return ids.length == 1 ? ids.first : '';
  }

  static int _collectiveRevision(Iterable<MemoryPulse> pulses) {
    final revisions = pulses.map((pulse) => pulse.revision).toSet();
    return revisions.length == 1 ? revisions.first : 0;
  }

  final List<MemoryPulse<T>> _pulses;

  @override
  bool get isComposite => true;

  @override
  Iterable<Pulse<T>> get payload => _pulses.cast<Pulse<T>>();

  @override
  Iterator<PulseBase> get iterator =>
      _pulses.map((pulse) => pulse as PulseBase).iterator;

  @override
  MemoryCell<Iterable<Pulse<T>>>? get source => null;
}

/// A read-only projection of a memory pulse.
class _UnmodifiableMemoryPulse<T> extends MemoryPulseBase<T> {
  _UnmodifiableMemoryPulse(MemoryPulse<T> source)
      : _source = source,
        super(
          event: source.event,
          memoryId: source.memoryId,
          revision: source.revision,
          payload: source.payload,
          source: source.source,
          context: source.context,
          timestamp: source.timestamp,
          priority: source.priority,
          parent: source is PulseBase ? source : null,
        );

  final MemoryPulse<T> _source;

  @override
  MemoryEvent get event => _source.event;

  @override
  String get memoryId => _source.memoryId;

  @override
  int get revision => _source.revision;

  @override
  MemoryCell<T>? get source => _source.source;

  @override
  MemoryPulseBase<T> withStep(String step) =>
      _source.withStep(step) as MemoryPulseBase<T>;

  @override
  MemoryPulseBase evolve({Pulse? pulse, String? step, PulseContext? context}) =>
      throw UnsupportedError(
          'cannot evolve an unmodifiable memory pulse; evolve the source');

  @override
  _UnmodifiableMemoryPulse<T> get unmodifiable => this;
}

/// Builds a [MemoryEvent.loaded] pulse for [source] carrying [value].
MemoryPulse<T> memoryLoaded<T>({
  required MemoryCell<T> source,
  required T? value,
  required int revision,
  DateTime? timestamp,
}) =>
    _MemoryPulse<T>(
      event: MemoryEvent.loaded,
      memoryId: source.memoryId,
      revision: revision,
      payload: value,
      source: source,
      timestamp: timestamp,
    );

/// Builds a [MemoryEvent.applied] pulse for [source] carrying [value].
MemoryPulse<T> memoryApplied<T>({
  required MemoryCell<T> source,
  required T? value,
  required int revision,
  DateTime? timestamp,
}) =>
    _MemoryPulse<T>(
      event: MemoryEvent.applied,
      memoryId: source.memoryId,
      revision: revision,
      payload: value,
      source: source,
      timestamp: timestamp,
    );

/// Builds a [MemoryEvent.stored] pulse for [source] carrying [value].
MemoryPulse<T> memoryStored<T>({
  required MemoryCell<T> source,
  required T? value,
  required int revision,
  DateTime? timestamp,
}) =>
    _MemoryPulse<T>(
      event: MemoryEvent.stored,
      memoryId: source.memoryId,
      revision: revision,
      payload: value,
      source: source,
      timestamp: timestamp,
    );

/// Builds a [MemoryEvent.unloaded] pulse for [source] carrying [value].
MemoryPulse<T> memoryUnloaded<T>({
  required MemoryCell<T> source,
  required T? value,
  required int revision,
  DateTime? timestamp,
}) =>
    _MemoryPulse<T>(
      event: MemoryEvent.unloaded,
      memoryId: source.memoryId,
      revision: revision,
      payload: value,
      source: source,
      timestamp: timestamp,
    );

/// Builds a [MemoryEvent.removed] pulse for [source] carrying [value].
MemoryPulse<T> memoryRemoved<T>({
  required MemoryCell<T> source,
  required T? value,
  DateTime? timestamp,
}) =>
    _MemoryPulse<T>(
      event: MemoryEvent.removed,
      memoryId: source.memoryId,
      revision: 0,
      payload: value,
      source: source,
      timestamp: timestamp,
    );
