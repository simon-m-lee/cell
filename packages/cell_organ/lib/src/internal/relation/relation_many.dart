// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell_organ.dart';

abstract class RelationMany<H extends One, E extends One,
        R extends RelationMany<H, E, R>> extends ManyBase<E, R>
    implements Relation<H, E> {
  @override
  RelationManyNucleus<H, E, R> get _nucleus =>
      super._nucleus as RelationManyNucleus<H, E, R>;

  RelationMany(
    RelationManyNucleus<H, E, R> properties, {
    RelationField<H, E, R>? field,
    Iterable<E>? elements,
  }) : super(properties) {
    if (elements != null) {
      properties.record.mask.container.init(elements);
    }
    if (field != null) {
      final fields = RelatableNucleusBase.createFields(field,
          initialFields: field.value.fields);
      properties.record.relatable.fields.value = fields;
      final relations = RelatableNucleusBase.createRelations(fields);
      properties.record.relatable.relations.value = relations;
      properties.record.relatable.descendants.value =
          RelatableNucleusBase.createDescendants(relations);
    }
  }

  // RelationMany(RelationField<H,E,R> field, {
  //   Iterable<E>? elements,
  //
  //   Cell? bind,
  //   Context context = Context.system,
  //   RelatableReceptor<E,R> receptor = RelatableReceptor.passThrough,
  //   TestRelation<H,E,R> testRule = TestRelation.allowAll,
  //   Synapses synapses = Synapses.enabled,
  // }) : super(RelationManyNucleus<H,E,R>(
  //     field: field,
  //     containerInit: elements,
  //
  //     bind: bind,
  //     context: context,
  //     receptor: receptor,
  //     testRule: testRule,
  //     synapses: synapses
  // ));
  //
  // RelationMany.fromNucleus(RelationManyNucleus<H,E,R> properties, {
  //   RelationField<H,E,R>? field,
  //   Iterable<E>? elements,
  // }) : super(field != null
  //     ? RelationManyNucleus<H,E,R>(
  //     field: field,
  //     containerInit: elements,
  //
  //     bind: properties.bind,
  //     context: properties.context,
  //     receptor: properties.receptor,
  //     testRule: properties.testRule,
  //     synapses: properties.synapses
  // ) : properties
  // );

  // RelationMany.deputy(R bind, {
  //   Context context = Context.system,
  //   RelatableReceptor<E,R> receptor = RelatableReceptor.passThrough,
  //   TestRelation<H,E,R> testRule = TestRelation.allowAll,
  //   Synapses synapses = Synapses.enabled,
  // }) : super(RelationManyNucleus<H,E,R>.evolve(
  //     bind: bind,
  //     context: context,
  //     receptor: receptor,
  //     testRule: testRule,
  //     synapses: synapses,
  //
  //     principal: bind._nucleus
  // ));

  @override
  RelationField<H, E, R> get field => _nucleus.field;

  @override
  TestRelation<H, E, R> get validate => _nucleus.testRule;

  @override
  R deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelation<H, E, R> testRule = TestRelation.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  @override
  H get has => field.has;

  @override
  Type get elementType => E;

  @override
  R get unmodifiable;

  @override
  Map<String, dynamic> toMap({int cascade = 0}) {
    final map = <String, dynamic>{
      '_\$HasType': H,
      '_\$ElementType': E,
      '_\$Has': has.toMap(cascade: 0)
    };
    if (isNotEmpty) {
      map.addEntries(super.toMap(cascade: cascade).entries);
    }
    return map;
  }

  Map<RelatablePulse, Iterable<E>> _add(E element, {bool notification = true});

  Map<RelatablePulse, Iterable<E>> _remove(Object? object,
      {bool notification = true});

  @override
  int get hashCode {
    // var hash = RANDOM_PRIME;
    var hash = 13;
    hash = 31 * hash + runtimeType.hashCode;
    hash = 31 * hash + has.hashCode;
    for (var e in this) {
      hash = 31 * hash + e.hashCode;
    }
    return hash;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is RelationMany<H, E, R>) {
      if (other.has == has && other.length == length) {
        return every((e) => other.any((oe) => oe.id == e.id));
      }
    } else if (other is Iterable<E>) {
      if (other.length == length) {
        return every((e) => other.any((oe) => oe.id == e.id));
      }
    }
    return false;
  }

  Map<RelatablePulse, Iterable<E>> _addAll(Iterable<E> elements,
      {bool notification = true}) {
    final result = <RelatablePulse, Set<E>>{};

    if (this is! Unmodifiable && modifiable.contains(addAll)) {
      for (var e in elements) {
        final map = _add(e, notification: false);
        if (map.isNotEmpty) {
          (result[Relatable.oneAdded] ??= <E>{}).add(e);
        }
      }
      if (notification) {
        final post = RelatablePost._(from: this, body: result);
        _nucleus.receptor(post);
      }
    }
    return result;
  }

  Map<RelatablePulse, Iterable<E>> _clear({bool notification = true}) {
    final result = <RelatablePulse, Set<E>>{};
    if (this is! Unmodifiable && modifiable.contains(clear)) {
      for (var e in toList(growable: false)) {
        final map = _remove(e, notification: false);
        if (map.isNotEmpty) {
          (result[Relatable.oneRemoved] ??= <E>{}).add(e);
        }
      }
      if (notification) {
        final post = RelatablePost._(from: this, body: result);
        _nucleus.receptor(post);
      }
    }
    return result;
  }

  Map<RelatablePulse, Iterable<E>> _removeAll(Iterable<Object?> objects,
      {bool notification = true}) {
    final result = <RelatablePulse, Set<E>>{};
    if (this is! Unmodifiable && modifiable.contains(removeAll)) {
      for (var o in objects) {
        final map = _remove(o, notification: false);
        if (map.isNotEmpty) {
          (result[Relatable.oneRemoved] ??= <E>{}).add(map.values.first.first);
        }
      }
      if (notification) {
        final post = RelatablePost._(from: this, body: result);
        _nucleus.receptor(post);
      }
    }
    return result;
  }

  Map<RelatablePulse, Iterable<E>> _removeWhere(bool Function(E element) test,
      {bool notification = true}) {
    final result = <RelatablePulse, Set<E>>{};

    if (this is! Unmodifiable && modifiable.contains(removeWhere)) {
      for (var e in toList(growable: false)) {
        if (test(e)) {
          final map = _remove(e, notification: false);
          if (map.isNotEmpty) {
            (result[Relatable.oneRemoved] ??= <E>{})
                .add(map.values.first.first);
          }
        }
      }
      if (notification) {
        final post = RelatablePost._(from: this, body: result);
        _nucleus.receptor(post);
      }
    }
    return result;
  }

  Map<RelatablePulse, Iterable<E>> _retainAll(Iterable<Object?> objects,
      {bool notification = true}) {
    final result = <RelatablePulse, Set<E>>{};
    if (this is! Unmodifiable && modifiable.contains(retainAll)) {
      final retains = objects.map((o) => lookup(o)).whereType<E>();
      final elements = where((e) => !retains.contains(e));
      for (var e in elements) {
        final map = _remove(e, notification: false);
        if (map.isNotEmpty) {
          (result[Relatable.oneRemoved] ??= <E>{}).add(map.values.first.first);
        }
      }
      if (notification) {
        final post = RelatablePost._(from: this, body: result);
        _nucleus.receptor(post);
      }
    }
    return result;
  }

  Map<RelatablePulse, Iterable<E>> _retainWhere(bool Function(E element) test,
      {bool notification = true}) {
    final result = <RelatablePulse, Set<E>>{};
    if (this is! Unmodifiable && modifiable.contains(retainAll)) {
      for (var e in toList(growable: false)) {
        if (!test(e)) {
          final map = _remove(e, notification: false);
          if (map.isNotEmpty) {
            (result[Relatable.oneRemoved] ??= <E>{})
                .add(map.values.first.first);
          }
        }
      }
      if (notification) {
        final post = RelatablePost._(from: this, body: result);
        _nucleus.receptor(post);
      }
    }
    return result;
  }

  @override
  dynamic apply(Function function, List? positionalArguments,
      [Map<Symbol, dynamic>? namedArguments]) {
    if (modifiable.contains(function)) {
      try {
        if (_nucleus.testRule.action(function, host: this as R, arguments: (
          positionalArguments: positionalArguments,
          namedArguments: namedArguments
        ))) {
          final notification = namedArguments?[#$notification] ?? true;
          final deputy = namedArguments?[#deputy];

          if (function == add) {
            return Function.apply(_add, positionalArguments,
                {#notification: notification, #deputy: deputy});
          } else if (function == addAll) {
            return Function.apply(_addAll, positionalArguments,
                {#notification: notification, #deputy: deputy});
          } else if (function == clear) {
            return Function.apply(
                _clear, null, {#notification: notification, #deputy: deputy});
          } else if (function == remove) {
            return Function.apply(_remove, positionalArguments,
                {#notification: notification, #deputy: deputy});
          } else if (function == removeAll) {
            return Function.apply(_removeAll, positionalArguments,
                {#notification: notification, #deputy: deputy});
          } else if (function == removeWhere) {
            return Function.apply(_removeWhere, positionalArguments,
                {#notification: notification, #deputy: deputy});
          } else if (function == retainAll) {
            return Function.apply(_retainAll, positionalArguments,
                {#notification: notification, #deputy: deputy});
          } else if (function == retainWhere) {
            return Function.apply(_retainWhere, positionalArguments,
                {#notification: notification, #deputy: deputy});
          }
          return;
        }
      } catch (_) {}
    }
    return Function.apply(function, positionalArguments, namedArguments);
  }
}

abstract class UnmodifiableManyToMany<H extends One, E extends One>
    extends UnmodifiableRelationMany<H, E, ManyToMany<H, E>>
    implements ManyToMany<H, E> {
  UnmodifiableManyToMany(ManyToMany<H, E> bind)
      : super(RelationManyNucleus<H, E, ManyToMany<H, E>>.evolve(
            override:
                Nucleus.create<ManyToMany<H, E>>(bind: bind, forceLock: true),
            principal: bind._nucleus));

  @override
  RelationField<H, E, ManyToMany<H, E>> get field =>
      (super.field as ManyToMany<H, E>).field.unmodifiable;

  @override
  TestRelation<H, E, ManyToMany<H, E>> get validate => super.validate;

  @override
  ManyToMany<H, E> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelation<H, E, ManyToMany<H, E>> testRule =
        TestRelation.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) =>
      this;

  @override
  ManyToMany<H, E> get unmodifiable => this;
}

abstract class UnmodifiableHasMany<H extends One, E extends One>
    extends UnmodifiableRelationMany<H, E, HasMany<H, E>>
    implements HasMany<H, E> {
  UnmodifiableHasMany(HasMany<H, E> bind)
      : super(RelationManyNucleus<H, E, HasMany<H, E>>.evolve(
            override:
                Nucleus.create<HasMany<H, E>>(bind: bind, forceLock: true),
            principal: bind._nucleus));

  @override
  RelationField<H, E, HasMany<H, E>> get field =>
      (_nucleus.bind as HasMany<H, E>).field.unmodifiable;

  @override
  TestRelation<H, E, HasMany<H, E>> get validate => _nucleus.testRule;

  @override
  HasMany<H, E> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelation<H, E, HasMany<H, E>> testRule =
        TestRelation.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) =>
      this;

  @override
  HasMany<H, E> get unmodifiable => this;
}

abstract class UnmodifiableRelationMany<H extends One, E extends One,
    R extends RelationMany<H, E, R>> extends RelationMany<H, E, R> {
  UnmodifiableRelationMany(super.properties) : super();

  ///
  /// This ensures that even if a developer navigates from the relationship
  /// back to the owner, they cannot evolve the owner through that reference.
  @override
  H get has => super.has.unmodifiable as H;

  /// Returns an empty set of functions, indicating that no mutation
  /// operations are supported by this instance.
  @override
  Iterable<Function> get modifiable => <Function>{};

  /// The runtime type of the elements [E] contained in this relationship.
  @override
  Type get elementType => E;

  /// Returns an unmodifiable view of the structural field that defines
  /// this relationship's schema.
  @override
  RelationField<H, E, R> get field => super.field.unmodifiable;

  /// Creates a [deputy] of this unmodifiable relationship.
  ///
  /// This must be implemented by concrete subclasses to provide specialized
  /// read-only views (e.g., with different contexts or rules).
  @override
  R deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelation<H, E, R> testRule = TestRelation.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  /// Internal hook for adding elements, overridden to perform no action.
  ///
  /// In an unmodifiable view, this returns an empty map, effectively
  /// ignoring the add request.
  @override
  Map<RelatablePulse, Iterable<E>> _add(E model, {bool notification = true}) {
    return {};
  }

  /// Internal hook for removing elements, overridden to perform no action.
  ///
  /// In an unmodifiable view, this returns an empty map, effectively
  /// ignoring the remove request.
  @override
  Map<RelatablePulse, Iterable<E>> _remove(Object? object,
      {bool notification = true}) {
    return {};
  }
}
