// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell_organ.dart';

abstract class RelationOne<H extends One, E extends One,
        R extends RelationOne<H, E, R>> extends TissueValueBase<E, R>
    with RelatableMixin
    implements Relation<H, E> {
  RelationOne(RelationOneNucleus<H, E, R> properties,
      {RelationField<H, E, R>? field, E? value})
      : _nucleus = properties,
        super(properties) {
    if (value != null) {
      properties.record.mask.container.init(value);
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

  @override
  final RelationOneNucleus<H, E, R> _nucleus;

  bool get isFinal => false;

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

  E? get one => _nucleus.container.store.value;

  @override
  Type get elementType => E;

  @override
  R get unmodifiable;

  Map<RelatablePulse, Iterable<ElementValueChange>> _set(E? e,
      {bool notification = true}) {
    final map =
        <RelatablePulse, Iterable<ElementValueChange<TissueValue<E>, E?>>>{};

    final before = one;
    if (_nucleus.container.store.value != e) {
      _nucleus.container.store.value = e;

      before?._nucleus.synapses.unlink(this, before);

      e?._nucleus.synapses.link(e, downstreamCell: this);

      map[Relatable.relationChanged] = {
        ElementValueChange<TissueValue<E>, E?>(
            element: this as TissueValue<E>, after: e, before: before)
      };
      if (notification) {
        final post = RelatablePost._(from: this, body: map);
        _nucleus.receptor(post);
      }
    }

    return map;
  }

  @override
  String toString() =>
      '${runtimeType.toString()}: {one: ${one != null ? one.toString() : 'null'}}';

  @override
  int get hashCode {
    var hash = 13;
    hash = 31 * hash + runtimeType.hashCode;
    hash = 31 * hash + has.hashCode;
    if (isNotEmpty) {
      hash = 31 * hash + one!.hashCode;
    }
    return hash;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is R) {
      return has == other.has && one == other.one;
    } else if (other is E) {
      if (one != null) {
        if (identical(one, other)) {
          return true;
        }
        if (one!.id == other.id) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Map<String, dynamic> toMap({int cascade = 0}) {
    final map = <String, dynamic>{
      '_\$HasType': H,
      '_\$ElementType': E,
      '_\$Has': has.toMap(cascade: 0)
    };
    if (isNotEmpty) {
      map.addEntries(one!.toMap(cascade: cascade).entries);
    }
    return map;
  }

  @override
  String toJson(
      {int cascade = 0, String? Function(Object? nonEncodable)? toEncodable}) {
    // ignore: prefer_typing_uninitialized_variables
    var vv;
    final map = toMap(cascade: cascade);
    return jsonEncode(map, toEncodable: (v) {
      if (toEncodable != null) {
        vv = toEncodable(v);
        if (vv != null) {
          return vv;
        }
      }
      return Field.valueAs<String>(v);
    });
  }

  @override
  Many<Relatable> operator +(Object other) {
    if (other is One) {
      return Many<Relatable>([this, other]);
    } else if (other is Many) {
      return other + this;
    }
    return Many<One>.empty();
  }
}

abstract class UnmodifiableHasOne<H extends One, E extends One>
    extends UnmodifiableRelationOne<H, E, HasOne<H, E>>
    implements HasOne<H, E> {
  UnmodifiableHasOne(HasOne<H, E> bind)
      : super(RelationOneNucleus<H, E, HasOne<H, E>>.evolve(
            override: Nucleus.create<HasOne<H, E>>(bind: bind, forceLock: true),
            principal: bind._nucleus));

  @override
  RelationField<H, E, HasOne<H, E>> get field =>
      (_nucleus.bind as HasOne<H, E>).field.unmodifiable;

  @override
  TestRelation<H, E, HasOne<H, E>> get validate => _nucleus.testRule;

  @override
  HasOne<H, E> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelation<H, E, HasOne<H, E>> testRule = TestRelation.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) =>
      this;

  @override
  HasOne<H, E> get unmodifiable => this;
}

/// 3.  **Recursive Protection (Anti-Leakage)**: Overrides key accessors—
///     such as [field] and [has]—to ensure they return their respective
///     `.unmodifiable` counterparts. This prevents "mutability leakage,"
///     where an observer could navigate the graph through a read-only
///     handle but regain write access by stepping into a principal organism
///     or a metadata object.
/// 4.  **Transactional Peeking**: Participates in the host's global [Lock].
///     Observers reading through this deputy are guaranteed to see an
///     **Atomic Snapshot**, synchronized with any concurrent mutations
///     occurring on the primary entity, preventing "Pathogenic Flux"
///     during traversal.
///
/// ### Design Patterns & Mechanics:
/// *   **The Shadow Pattern**: It functions as a behavioral shadow of the
///     principal relation. It shares the same **Ontological Signature**
///     ([name]) and physical storage but lacks the "Nervous System"
///     ([receptor]) authority to commit new values.
/// *   **Epigenetic Gating**: Utilizes a specialized [RelationOneNucleus]
///     that omits a local lock (delegating synchronization back to the
///     progenitor) and enforces read-only traversal logic.
/// *   **Flyweight Projection**: As a deputy handle, it consumes minimal
///     memory by referencing the progenitor's somatic container rather
///     than duplicating the relational tissue.
///
/// ### Type Parameters:
/// * [H]: The species of the host organism (extending [One]) that owns
///   the relation.
/// * [E]: The species of the target organism (extending [One]) being
///   observed.
/// * [R]: The recursive type signature of the concrete relationship
///   implementation (e.g., `HasOne<H, E>`).
abstract class UnmodifiableRelationOne<H extends One, E extends One,
    R extends RelationOne<H, E, R>> extends RelationOne<H, E, R> {
  /// Initializes a new [UnmodifiableRelationOne] instance using the provided
  /// properties record.
  ///
  /// This constructor is the primary internal mechanism for creating
  /// immutable, read-only projections of a single-target relationship
  /// ([RelationOne]). It is typically invoked by the `.unmodifiable`
  /// getter on a mutable relation instance.
  ///
  /// ### Lifecycle and Implementation:
  /// 1. **Property Binding**: It accepts a [RelationOneNucleus] instance
  ///    which contains the metadata, operational rules, and—crucially—a
  ///    reference to the source [Relatable] or [Cell] it is projecting.
  /// 2. **Recursive Immutability**: By passing these properties to the
  ///    [RelationOne] base constructor, it ensures the instance is
  ///    integrated into the reactive graph while the [UnmodifiableRelationOne]
  ///    class logic overrides all mutation vectors (such as the `set` method).
  /// 3. **Reactive Linkage**: Even as an unmodifiable view, the constructor
  ///    ensures the instance remains "live." It continues to observe
  ///    the underlying data container, so any changes made to the
  ///    original relationship are reflected here in real-time.
  ///
  /// ### Functional Role:
  /// This constructor facilitates the "Data Encapsulation" pattern within
  /// the entity graph. It allows a model to share its internal relations
  /// with external consumers (like a UI layer) without the risk of those
  /// consumers accidentally reassigning the relationship or breaking
  /// graph integrity.
  ///
  /// ### Parameters:
  /// * [properties]: The specialized [RelationOneNucleus] record that
  ///   holds the identity, context, and the shared data store for this
  ///   relationship view.
  UnmodifiableRelationOne(super.properties) : super();

  /// Standard constructor for initializing an unmodifiable relation.
  ///
  /// * [field]: The [RelationField] definition belonging to the host [H].
  /// * [context]: The operational scope.
  /// * [receptor]: A callback for events (though mutation is disabled).
  /// * [testRule]: Validation rules for the relation.
  /// * [synapses]: Configuration for graph synchronization.
  // UnmodifiableRelationOne(super.field, {
  //
  //   super.context,
  //   super.receptor,
  //   super.testRule,
  //   super.synapses,
  // }) : super();

  // UnmodifiableRelationOne.fromNucleus(RelationOneNucleus<H,E,R> properties, {
  //   RelationField<H,E,R>? field,
  //   E? value
  // }) : super.fromNucleus(field != null
  //     ? RelationOneNucleus<H,E,R>(
  //     field: field,
  //     containerInit: value,
  //
  //     bind: properties.bind,
  //     context: properties.context,
  //     receptor: properties.receptor,
  //     testRule: properties.testRule,
  //     synapses: properties.synapses
  // ) : properties
  // );

  /// Creates a deputy version of the unmodifiable relation, binding it to an
  /// existing relation instance.
  ///
  /// This is commonly used to create a read-only "view" of a mutable relation.
  // UnmodifiableRelationOne.deputy(super.bind, {
  //   super.context,
  //   super.receptor,
  //   super.testRule,
  //   super.synapses
  // }) : super.deputy();

  /// Returns an unmodifiable version of the [RelationField] defining this relation.
  @override
  RelationField<H, E, R> get field => super.field.unmodifiable;

  /// Returns the host model instance ([H]) in its unmodifiable state.
  @override
  H get has => super.has.unmodifiable as H;

  /// Returns the current instance.
  ///
  /// Since this class is already unmodifiable, creating a deputy with
  /// new rules typically returns itself to maintain the read-only invariant.
  @override
  R deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelation<H, E, R> testRule = TestRelation.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) =>
      this as R;

  /// Accesses the current related model instance [E] from the underlying bound relation.
  ///
  /// This implementation delegates to the internal `_nucleus.bind` to retrieve
  /// the value currently held by the source relation.
  @override
  E? get one => (_nucleus.bind as HasOne<H, E>).one?.unmodifiable as E?;

  /// Returns this instance, as it is already unmodifiable.
  @override
  R get unmodifiable => this as R;

  /// Prevents modification of the relation.
  ///
  /// Always returns `false` and performs no action, ensuring that
  /// [UnmodifiableRelationOne] cannot be changed via the standard [set] API.
  @override
  bool set(E? one) => false;

  // @override
  // TestRelation<H,E,HasOne<H,E>> _testRelation(TestRelatable? testRule) {
  //   return testRule != null && testRule != TestRelatable.allowAll ? TestRelation<H,E,HasOne<H,E>>.fromTestRelatable(testRule) : TestRelation.allowAll;
  // }
}
