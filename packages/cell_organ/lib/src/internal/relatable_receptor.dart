// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell_organ.dart';

final class _UnmodifiableRelatablePost extends RelatablePost {
  _UnmodifiableRelatablePost._(RelatablePost source)
      : super._(
            from: source.from,
            body: Map<RelatablePulse, Iterable>.fromEntries(source.body!.entries
                .map<MapEntry<RelatablePulse, Iterable>>((en) {
              return MapEntry<RelatablePulse, Iterable>(en.key,
                  en.value.map((v) {
                if (v is ValueChange) {
                  return v.unmodifiable;
                } else if (v is Tissue) {
                  return v.unmodifiable;
                }
                return v;
              }));
            })));
}

class _RelatableReceptor<E, C extends Tissue<E>>
    extends RelatableReceptorBase<E, C> {
  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  _RelatableReceptor(PulseRule rule)
      : this.fromRecord(record: (cell: FinalBox<C>(), rule: rule));

  _RelatableReceptor.fromRecord({super.record})
      : _record = record,
        super.fromRecord();

  @override
  RelatableReceptor<E, C> get clone =>
      _RelatableReceptor.fromRecord(record: _record);
}

abstract class RelatableReceptorBase<E, C extends Tissue<E>>
    extends ReceptorBase<C>
    with _RelatableReceptorBaseStack
    implements RelatableReceptor<E, C> {
  RelatableReceptorBase({super.rule, super.preProcess}) : super();

  RelatableReceptorBase.fromRecord({super.record}) : super.fromRecord();

  @override
  Pulse? call(covariant Pulse pulse, {Set<Cell>? skip}) {
    Pulse? out = pulse;

    if (pulse is TissuePost) {
      out = (_relatableStack<E>(collective: cell, pulse: pulse) ?? pulse)
          as Pulse;
    }

    return super.call(out, skip: skip);
  }
}

class _PassThroughRelatableReceptor
    implements RelatableReceptorBase<Never, Never> {
  const _PassThroughRelatableReceptor();

  @override
  Never get cell => throw UnsupportedError('Inactivated receptor');

  @override
  RelatableReceptor<Never, Never> get clone => this;

  @override
  bool activate(Never cell) => false;

  @override
  SyncReceptor<Never> get async => SyncReceptor<Never>(this);

  @override
  bool get isActivated => false;

  @override
  RelatablePost? _relatableStack<E>(
      {required Tissue<dynamic> collective, required TissuePost pulse}) {
    return null;
  }

  @override
  Pulse<dynamic>? call(covariant Pulse<dynamic> pulse, {Set<Cell>? skip}) {
    return null;
  }
}

mixin _RelatableReceptorBaseStack {
  RelatablePost? _relatableStack<E>(
      {required Tissue collective, required TissuePost pulse}) {
    Map<RelatablePulse, Iterable>? body;

    if (pulse.from is Field) {
      final entries =
          pulse.payload!.entries.where((en) => en.key == Tissue.elementUpdated);
      body = {for (var en in entries) Relatable.fieldChanged: en.value};
    } else if (pulse.from is RelationOne) {
      final entries =
          pulse.payload!.entries.where((en) => en.key == Tissue.elementUpdated);
      body = {for (var en in entries) Relatable.oneChanged: en.value};
    } else if (pulse.from is RelationMany) {
      body = {
        for (var en in pulse.payload!.entries)
          switch (en.key) {
            Tissue.elementAdded || ElementAdded() => Relatable.oneAdded,
            Tissue.elementRemoved || ElementRemoved() => Relatable.oneRemoved,
            Tissue.elementUpdated ||
            ElementUpdatedEvent() =>
              Relatable.oneChanged,
          } as RelatablePulse: en.value
      };
    }

    if (body != null) {
      return RelatablePost._(
          from: collective, body: body as Map<RelatablePulse, Iterable<E>>);
    }

    return null;
  }
}
