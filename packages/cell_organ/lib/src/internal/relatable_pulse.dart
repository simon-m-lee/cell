// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_organ.dart';

// ignore_for_file: non_constant_identifier_names
// int get _RANDOM_PRIME => _$RANDOM_PRIME ??= <int>[2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97][Random().nextInt(24)];

class _CollectiveRelatablePulse<E> extends CollectiveRelatablePulseBase<E> {
  _CollectiveRelatablePulse(
    Iterable<RelatablePulse<E>> events, {
    super.policy,
    super.type,
    super.context,
    super.timestamp,
    super.source,
    super.step,
    void Function(RelatablePulse event)? super.onComplete,
    void Function(RelatablePulse event, Object error, {StackTrace? stackTrace})?
        super.onError,
    void Function(RelatablePulse event, Cell cell, {String? message})?
        super.onProgress,
    super.pulse,
    super.parent,
    super.priority,
    FutureOr<RelatablePulse?> Function(RelatableReceptor receptor)?
        super.scrutinize,
  }) : super(pulses: events);
}

abstract class CollectiveRelatablePulseBase<E>
    extends RelatablePulseBase<Iterable<Pulse<E>>>
    implements CollectiveRelatablePulse<E>, CollectivePulse<E> {
  CollectiveRelatablePulseBase(
      {Iterable<RelatablePulse<E>>? pulses,
      super.policy,
      super.type,
      super.context,
      super.timestamp,
      super.source,
      super.step,
      super.onComplete,
      super.onError,
      super.onProgress,
      super.pulse,
      super.parent,
      super.scrutinize,
      super.user,
      super.priority})
      : super(payload: pulses) {
    final branches = _branches;
    if (branches != null) {
      branches.value = branches.value! + 1;
    }
  }

  @override
  Iterable<RelatablePulse<E>> get payload =>
      super.payload as Iterable<RelatablePulse<E>>;

  @override
  Iterator<RelatablePulse<E>> get iterator => payload.iterator;

  @override
  CollectiveRelatablePulse operator +(covariant RelatablePulse other) {
    return other is RelatablePulse<E>
        ? other is CollectivePulse<E>
            ? _CollectiveRelatablePulse<E>([
                this as RelatablePulse<E>,
                ...(other.payload as Iterable<RelatablePulse<E>>)
              ])
            : _CollectiveRelatablePulse<E>([this as RelatablePulse<E>, other])
        : other is CollectivePulse
            ? _CollectiveRelatablePulse([this, ...other.payload])
            : _CollectiveRelatablePulse([this, other]);
  }
}

class _EvolvedRelatablePulse<E> extends EvolvedRelatablePulseBase<E> {
  _EvolvedRelatablePulse({
    super.policy,
    super.payload,
    super.type,
    super.context,
    super.timestamp,
    super.source,
    super.step,
    void Function(RelatablePulse event)? super.onComplete,
    void Function(RelatablePulse event, Object error, {StackTrace? stackTrace})?
        super.onError,
    void Function(RelatablePulse event, Cell cell, {String? message})?
        super.onProgress,
    super.pulse,
    super.parent,
    super.scrutinize,
    super.user,
  }) : super();
}

abstract class EvolvedRelatablePulseBase<E> extends _RelatablePulse<E>
    with _RelatablePulseMixin<E>
    implements EvolvedPulse<E> {
  EvolvedRelatablePulseBase({
    super.policy,
    super.context,
    super.payload,
    super.type,
    super.timestamp,
    super.source,
    super.step,
    super.priority,
    super.onComplete,
    super.onError,
    super.onProgress,
    super.pulse,
    super.parent,
    super.scrutinize,
    super.user,
  }) : super();

  @override
  RelatablePulseBase<E> get parent => _parent!;

  @override
  CollectiveRelatablePulse operator +(covariant RelatablePulse other) {
    return other is RelatablePulse<E>
        ? other is CollectivePulse<E>
            ? _CollectiveRelatablePulse<E>(
                [this, ...(other.payload as Iterable<RelatablePulse<E>>)])
            : _CollectiveRelatablePulse<E>([this, other])
        : other is CollectivePulse
            ? _CollectiveRelatablePulse([this, ...other.payload])
            : _CollectiveRelatablePulse([this, other]);
  }
}

class _RelatablePulse<E> extends RelatablePulseBase<E> {
  _RelatablePulse({
    super.policy,
    super.context,
    super.payload,
    super.type,
    super.timestamp,
    super.source,
    super.step,
    super.priority,
    super.onComplete,
    super.onError,
    super.onProgress,
    super.pulse,
    super.parent,
    FutureOr<RelatablePulse?> Function(RelatableReceptor receptor)?
        super.scrutinize,
    super.user,
  }) : super();

  const _RelatablePulse.fromRecord(super.record) : super.fromRecord();

  @override
  RelatablePulse evolve(
      {Pulse? pulse, String? step, covariant PulseContext? context}) {
    return _EvolvedRelatablePulse<E>(
      context: context,
      step: step,
      parent: this,
    );
  }

  @override
  Iterator<Pulse<E>> get iterator {
    final events = super.toList(growable: false).cast<RelatablePulse<E>>();
    return events.iterator;
  }

  @override
  RelatablePulseShell<E> get shell => RelatablePulseShell<E>._(this);

  @override
  RelatablePulseBase<E> get unmodifiable =>
      _UnmodifiableRelatablePulse<E>(this) as RelatablePulseBase<E>;

  @override
  RelatablePulseBase<E> withStep(String step) =>
      _RelatablePulse<E>(step: step, parent: this);
}

mixin _RelatablePulseMixin<E> on Pulse<E> {
  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  get _record;

  @override
  RelatablePulseShell<E> get shell =>
      RelatablePulseShell<E>._(this as RelatablePulseBase<E>);

  @override
  RelatablePulse evolve(
      {Pulse? pulse, String? step, covariant PulseContext? context}) {
    return _EvolvedRelatablePulse(
      context: context,
      step: step,
      pulse: pulse,
      parent: this as RelatablePulseBase<E>,
    );
  }

  @override
  RelatablePulseBase<E> withStep(String step) {
    return _RelatablePulse<E>(
      step: step,
      parent: this as RelatablePulseBase<E>,
    );
  }

  @override
  Relatable? get source => super.source as Relatable?;

  @override
  RelatablePulseBase<E> get root => super.root as RelatablePulseBase<E>;

  @override
  RelatablePulseBase<E> get unmodifiable {
    return _UnmodifiableRelatablePulse<E>(this as RelatablePulseBase<E>)
        as RelatablePulseBase<E>;
  }

  @override
  CollectiveRelatablePulse operator +(covariant RelatablePulse other) {
    return other is RelatablePulse<E>
        ? other is CollectivePulse<E>
            ? _CollectiveRelatablePulse<E>([
                this as RelatablePulse<E>,
                ...(other.payload as Iterable<RelatablePulse<E>>)
              ])
            : _CollectiveRelatablePulse<E>([this as RelatablePulse<E>, other])
        : other is CollectivePulse
            ? _CollectiveRelatablePulse(
                [this as RelatablePulse<E>, ...other.payload])
            : _CollectiveRelatablePulse([this as RelatablePulse<E>, other]);
  }

  RelatablePulseBase<E>? get _parent {
    return get<RelatablePulseBase<E>?>(() => _record._parent, orElse: null);
  }
}

abstract class RelatablePulseBase<E> extends PulseBase<E>
    with _RelatablePulseMixin<E>
    implements RelatablePulse<E> {
  @override
  // ignore: prefer_typing_uninitialized_variables
  final _record;

  RelatablePulseBase(
      {PulseEphemeralPolicy? policy,
      PulseContext? context,
      E? payload,
      String? type,
      Relatable? source,
      DateTime? timestamp,
      String? step,
      int? priority,
      Function? onComplete, // void Function(RelatablePulse event)? onComplete,
      Function?
          onError, // void Function(RelatablePulse event, Object error, {StackTrace? stackTrace})? onError,
      Function?
          onProgress, // void Function(RelatablePulse event, Cell cell, {String? message})? onProgress,

      Pulse<E>? pulse,
      RelatablePulse<E>? parent,
      Function?
          scrutinize, // FutureOr<Pulse?> Function(RelatableReceptor receptor)? scrutinize,
      dynamic user})
      : this.fromRecord(PulseBase.mask(
          policy: policy,
          context: context,
          payload: payload,
          type: type,
          timestamp: timestamp,
          source: source,
          step: step,
          priority: priority,
          onComplete: onComplete,
          onError: onError,
          onProgress: onProgress,
          pulse: pulse,
          parent: parent,
          scrutinize: scrutinize,
          user: user,
        ));

  const RelatablePulseBase.type(String type)
      : this.fromRecord((root: (secondary: (type: type))));

  const RelatablePulseBase.fromRecord(super.record)
      : _record = record,
        super.fromRecord();

  Box<int>? get _branches {
    return get<Box<int>?>(() => _record.root.callbacks.branches, orElse: null);
  }

  @override
  RelatablePulseShell<E> get shell => RelatablePulseShell<E>._(this);

  @override
  RelatablePulse evolve(
      {Pulse? pulse, String? step, covariant PulseContext? context}) {
    return _EvolvedRelatablePulse(
      context: context,
      step: step,
      pulse: pulse,
      parent: this,
    );
  }

  @override
  RelatablePulseBase<E> withStep(String step) {
    return _RelatablePulse<E>(
      step: step,
      parent: this,
    );
  }

  @override
  Relatable? get source => super.source;

  @override
  RelatablePulseBase<E> get root => super.root;

  @override
  RelatablePulseBase<E> get unmodifiable {
    return _UnmodifiableRelatablePulse<E>(this) as RelatablePulseBase<E>;
  }

  @override
  CollectiveRelatablePulse operator +(covariant RelatablePulse other) {
    return other is RelatablePulse<E>
        ? other is CollectivePulse<E>
            ? _CollectiveRelatablePulse<E>([
                this as RelatablePulse<E>,
                ...(other.payload as Iterable<RelatablePulse<E>>)
              ])
            : _CollectiveRelatablePulse<E>([this as RelatablePulse<E>, other])
        : other is CollectivePulse
            ? _CollectiveRelatablePulse(
                [this as RelatablePulse<E>, ...other.payload])
            : _CollectiveRelatablePulse([this as RelatablePulse<E>, other]);
  }

  @override
  RelatablePulseBase<E>? get _parent {
    return get<RelatablePulseBase<E>?>(() => _record._parent, orElse: null);
  }

  // ───── Internal Callbacks (stored on the root) ─────

  void Function(RelatablePulse event)? get _onComplete {
    return get<void Function(RelatablePulse event)?>(
        () => _record.root.callbacks.onComplete,
        fallback: () => _parent?._onComplete,
        orElse: null);
  }

  void Function(RelatablePulse event, Object error, {StackTrace? stackTrace})?
      get _onError {
    return get<
            void Function(RelatablePulse event, Object error,
                {StackTrace? stackTrace})?>(
        () => _record.root.callbacks.onError,
        fallback: () => _parent?._onError,
        orElse: null);
  }

  void Function(RelatablePulse event, Cell cell, {String? message})?
      get _onProgress {
    return get<
            void Function(RelatablePulse event, Cell cell, {String? message})?>(
        () => _record.root.callbacks.onProgress,
        fallback: () => _parent?._onProgress,
        orElse: null);
  }

  void _complete() {
    root._onComplete?.call(this);
  }

  void _fail(Object error, {StackTrace? stackTrace}) {
    root._onError?.call(this, error, stackTrace: stackTrace);
  }

  void _progress(Cell cell, {String? message}) {
    root._onProgress?.call(this, cell, message: message);
  }
}

class _UnmodifiableRelatablePulse<E> extends UnmodifiableRelatablePulseBase<E> {
  _UnmodifiableRelatablePulse(RelatablePulse<E> source)
      : super(source as RelatablePulseBase<E>);
}

abstract class UnmodifiableRelatablePulseBase<E>
    extends UnmodifiablePulseBase<E>
    implements UnmodifiableRelatablePulse<E>, RelatablePulseBase<E> {
  final RelatablePulseBase<E> _source;

  UnmodifiableRelatablePulseBase(RelatablePulseBase<E> super.source)
      : _source = source;

  @override
  RelatablePulseShell<E> get shell => RelatablePulseShell<E>._(this);

  @override
  RelatablePulseBase<E> withStep(String step) {
    return _source.withStep(step);
  }

  @override
  Relatable? get source => super.source as Relatable?;

  @override
  RelatablePulseBase<E> get root => super.root as RelatablePulseBase<E>;

  @override
  RelatablePulse evolve(
      {Pulse? pulse, String? step, covariant PulseContext? context}) {
    return _source.evolve(pulse: pulse, step: step, context: context);
  }

  @override
  RelatablePulseBase<E> get unmodifiable => this;

  @override
  CollectiveRelatablePulse operator +(covariant RelatablePulse other) {
    return _source + other;
  }

  @override
  RelatablePulseBase<E>? get _parent => _source._parent;

  @override
  get _record => _source._record;

  @override
  Box<int>? get _branches => _source._branches;

  // ───── Internal Callback Forwarding ─────

  @override
  void _complete() {
    _source._complete();
  }

  @override
  void _fail(Object error, {StackTrace? stackTrace}) {
    _source._fail(error, stackTrace: stackTrace);
  }

  @override
  void _progress(Cell cell, {String? message}) {
    _source._progress(cell, message: message);
  }

  @override
  void Function(RelatablePulse<dynamic> event)? get _onComplete {
    return _source._onComplete;
  }

  @override
  void Function(RelatablePulse<dynamic> event, Object error,
      {StackTrace? stackTrace})? get _onError {
    return _source._onError;
  }

  @override
  void Function(RelatablePulse event, Cell cell, {String? message})?
      get _onProgress {
    return _source._onProgress;
  }
}
