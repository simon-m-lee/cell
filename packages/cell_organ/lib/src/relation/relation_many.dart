// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

// ignore_for_file: prefer_mixin
// ignore_for_file: hash_and_equals
// ignore_for_file: unused_field
// ignore_for_file: unused_element

class RelationManyNucleus<H extends One, E extends One,
        R extends RelationMany<H, E, R>> extends RelationNucleusBase<H, E, R>
    implements ManyNucleusBase<E, R> {
  RelationManyNucleus({
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<E, R> receptor = RelatableReceptor.passThrough,
    TestRelation<H, E, R> testRule = TestRelation.allowAll,
    Synapses synapses = Synapses.enabled,
    Record? user,
    super.field,
    super.containerInit,
  }) : super(
            base: ManyNucleus.create<E, R>(
                bind: bind,
                context: context,
                receptor: receptor,
                testRule: testRule,
                synapses: synapses,
                identitySet: false));

  RelationManyNucleus.evolve(
      {super.bind,
      super.context,
      super.receptor,
      super.testRule,
      super.override,
      required RelationManyNucleus<H, E, R> super.principal})
      : super.evolve();

  @override
  TissueContainer<E, Set<E>> get container =>
      get<TissueContainer<E, Set<E>>>(() => record.container,
          fallback: () => principal?.container);

  @override
  RelationManyNucleus<H, E, R>? get principal {
    return super.principal as RelationManyNucleus<H, E, R>?;
  }

  @override
  Container get containerType {
    return get<Container>(() => record.mask.inheritable.container,
        fallback: () => principal?.containerType, orElse: Container.set);
  }

  @override
  RelationManyNucleus<H, E, R> get clone {
    final receptor = get<RelatableReceptor<E, R>?>(
        () => record.mask.inheritable.receptor,
        orElse: null);
    final testRule = get<TestRelation<H, E, R>?>(
        () => record.mask.inheritable.testRule,
        orElse: null);
    final context =
        get<Context?>(() => record.mask.inheritable.context, orElse: null);
    return RelationManyNucleus._fromRecord(record: (
      mask: TissueNucleusBase.local<E, Set<E>, RelationMany<H, E, R>>(
        context: context,
        receptor: receptor != RelatableReceptor.passThrough ? receptor : null,
        testRule: testRule != TestRelation.allowAll ? testRule : null,
        synapses: synapses == Synapses.disabled
            ? Synapses.disabled
            : Synapses.enabled,
        container: containerType == Container.identitySet
            ? Container.identitySet
            : null,
        forceLock: false,
        user: user,
      ),
      relatable: (
        fields: FinalBox<Tissue<Field>>(),
        relations: FinalBox<Tissue<Relation>>(),
        descendants: FinalBox<Tissue<One>>()
      ),
      relation: (field: FinalBox<RelationField<H, E, R>>())
    ));
  }

  RelationManyNucleus._fromRecord({super.record}) : super.fromRecord();
}

abstract class ManyToMany<H extends One, E extends One>
    extends RelationMany<H, E, ManyToMany<H, E>> {
  ManyToMany(
    super.field, {
    Iterable<E>? elements,
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<E, ManyToMany<H, E>> receptor =
        RelatableReceptor.passThrough,
    TestRelation<H, E, ManyToMany<H, E>> testRule = TestRelation.allowAll,
    Synapses synapses = Synapses.enabled,
  }) : super() {
    _nucleus.synapses.link(this, downstreamCell: field);

    if (elements != null) {
      for (var e in elements) {
        for (var f in e.fields) {
          if (f is RelationField && f.value is BelongsTo<E, H>) {
            if (f.validate(has, host: f)) {
              (f.value as BelongsTo<E, H>)._nucleus.container.store.value = has;
            }
            break;
          }
        }
      }
    }
  }

  ManyToMany.fromNucleus(
    super.properties, {
    RelationField<H, E, ManyToMany<H, E>>? field,
    Iterable<E>? elements,
  }) {
    if (field != null) {
      _nucleus.synapses.link(this, downstreamCell: field);
    }

    if (elements != null) {
      for (var e in elements) {
        final rels = e.relations.whereType<ManyToMany<E, H>>();
        if (rels.isNotEmpty) {
          final m2m = rels.first;
          if (m2m.validate(has, host: m2m) && !m2m.contains(has)) {
            m2m._nucleus.container.add(m2m, has);
          }
        }
      }
    }
  }

  bool _mutualTestAdd(One e) {
    if (e is E &&
        !contains(e) &&
        _nucleus.testRule.element(e, host: this, action: add)) {
      final rels = e.relations.whereType<ManyToMany<E, H>>();
      if (rels.isNotEmpty) {
        final m2m = rels.first;
        if (!m2m.contains(has) &&
            m2m._nucleus.testRule.element(has, host: m2m, action: add)) {
          return true;
        }
      }
    }
    return false;
  }

  Map<RelatablePulse, Iterable<E>> _mutualAdd(E model,
      {ManyToMany<E, H>? m2m, bool notification = true}) {
    final result = <RelatablePulse, Iterable<E>>{};

    if ((_nucleus.container as Set<E>).add(model)) {
      model._nucleus.synapses.link(model, downstreamCell: this);
      result[Relatable.oneAdded] = <E>{model};

      if (m2m != null) {
        m2m._mutualAdd(has, notification: notification);
      }

      if (notification) {
        final post = RelatablePost._(from: this, body: result);
        _nucleus.receptor(post);
      }
    }
    return result;
  }

  Map<RelatablePulse, Iterable<E>> _mutualRemove(E model,
      {ManyToMany<E, H>? m2m, bool notification = true}) {
    final result = <RelatablePulse, Iterable<E>>{};

    if ((_nucleus.container as Set<E>).remove(model)) {
      model._nucleus.synapses.link(model, downstreamCell: this);
      result[Relatable.oneRemoved] = <E>{model};

      if (m2m != null) {
        m2m._mutualRemove(has, notification: true);
      }

      if (notification) {
        final post = RelatablePost._(from: this, body: result);
        _nucleus.receptor(post);
      }
    }
    return result;
  }

  @override
  Map<RelatablePulse, Iterable<E>> _add(E model, {bool notification = true}) {
    if (!contains(model) && modifiable.contains(add)) {
      if (_nucleus.testRule.element(model, host: this, action: add)) {
        final rels = model.relations.whereType<ManyToMany<E, H>>();
        if (rels.isNotEmpty) {
          final m2m = rels.first;
          return _mutualAdd(model, m2m: m2m, notification: notification);
        }
      }
    }
    return {};
  }

  @override
  Map<RelatablePulse, Iterable<E>> _remove(Object? object,
      {bool notification = true}) {
    final model = object is E ? object : lookup(object) as E;

    if (this is! Unmodifiable && modifiable.contains(remove)) {
      final rels = model.relations.whereType<ManyToMany<E, H>>();
      if (rels.isNotEmpty) {
        final m2m = rels.first;
        if (!contains(model) && !m2m.contains(has)) {
          if (_nucleus.testRule.element(model, host: this, action: remove) &&
              model._nucleus.testRule.element(has, host: model, action: add)) {
            return _mutualRemove(model, m2m: m2m, notification: notification);
          }
        }
      }
    }
    return <RelatablePulse, Iterable<E>>{};
  }
}

abstract class HasMany<H extends One, E extends One>
    extends RelationMany<H, E, HasMany<H, E>> {
  HasMany(
    RelationField<H, E, HasMany<H, E>>? field, {
    Iterable<E>? elements,
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<E, HasMany<H, E>> receptor =
        RelatableReceptor.passThrough,
    TestRelation<H, E, HasMany<H, E>> testRule = TestRelation.allowAll,
    Synapses synapses = Synapses.enabled,
  }) : this.fromNucleus(
            RelationManyNucleus(
              bind: bind,
              context: context,
              receptor: receptor,
              testRule: testRule,
              synapses: synapses,
            ),
            field: field,
            elements: elements);

  /// or to create specialized behavioral lenses (Deputies) from a
  /// progenitor nucleus.
  ///
  /// ### Architectural Role: Structural Binding & Relational Handshaking
  /// This constructor performs the critical initialization of the
  /// relationship's signaling and connectivity logic:
  ///
  /// 1.  **Synaptic Mapping**: If a [field] (Ontological Signature) is
  ///     provided, the constructor immediately establishes the **Pulse
  ///     Path**. It links the relationship's internal synchronization to
  ///     the host's somatic field, ensuring that any state shift within
  ///     the population propagates correctly through the host's [synapses].
  /// 2.  **Inverse Mirror Synchronization (The Handshake)**: When initial
  ///     [elements] are provided, the constructor initiates a **Recursive
  ///     Somatic Handshake**. It traverses the genomic fields of each
  ///     target organism [E] to identify a reciprocal [BelongsTo] link
  ///     pointing back to the species of host [H].
  /// 3.  **Immune Validation**: Before finalizing the reciprocal link,
  ///     it invokes the target field's **Immune System** ([validate]).
  ///     Only if the current host [has] satisfies the target's membership
  ///     criteria is the back-link atomically committed to the target's
  ///     physical storage.
  /// 4.  **Transactional Consistency**: Guarantees that the initial
  ///     bidirectional connection between the principal and its population
  ///     is established as an atomic unit of work, preventing the
  ///     "Orphan State" where a child recognizes a principal that has not
  ///     yet acknowledged the child's membership.
  ///
  /// ### Design Patterns & Mechanics:
  /// *   **The Prototype Pattern**: Utilizes the [properties] record as
  ///     the definitive genomic source, ensuring the new instance inherits
  ///     all regulatory rules, contexts, and receptors.
  /// *   **Flyweight Restoration**: Optimized for high-performance mesh
  ///     reconstruction, utilizing the record-based nucleus to minimize
  ///     allocation overhead for plural metadata.
  /// *   **Epigenetic Continuity**: Ensures that if this constructor is
  ///     used for a Deputy, the deputy remains tethered to the principal's
  ///     physical [TissueContainer] (the [Set]) while applying its
  ///     own localized governance.
  ///
  /// ### Parameters:
  /// - [properties]: The underlying [RelationManyNucleus] record holding
  ///   the genomic metadata and transactional state.
  /// - [field]: The [RelationField] defining the relationship's structural
  ///   slot on the host organism [H].
  /// - [elements]: An optional initial collection of entities of species [E]
  ///   to be incorporated and symmetrically linked during initialization.
  HasMany.fromNucleus(
    super.properties, {
    RelationField<H, E, HasMany<H, E>>? field,
    Iterable<E>? elements,
  }) {
    if (field != null) {
      _nucleus.synapses.link(this, downstreamCell: field);
    }

    if (elements != null) {
      for (var e in elements) {
        for (var f in e.fields) {
          if (f is RelationField && f.value is BelongsTo<E, H>) {
            if (f.validate(has, host: f)) {
              (f.value as BelongsTo<E, H>)._nucleus.container.store.value = has;
            }
            break;
          }
        }
      }
    }
  }

  @override
  Map<RelatablePulse, Iterable<E>> _add(E model, {bool notification = true}) {
    final result = <RelatablePulse, Iterable<E>>{};

    if (_nucleus.testRule.element(model, host: this, action: add)) {
      BelongsTo<E, H>? belongsTo;
      final rels = model.relations.whereType<BelongsTo<E, H>>();
      if (rels.isNotEmpty) {
        belongsTo = rels.first;
      }

      if ((_nucleus.container as Set<E>).add(model)) {
        model._nucleus.synapses.link(model, downstreamCell: this);
        result[Relatable.oneAdded] = <E>{model};

        belongsTo?._set(has, notification: notification);

        if (notification) {
          final post = RelatablePost._(from: this, body: result);
          _nucleus.receptor(post);
        }
      }
    }

    return result;
  }

  @override
  Map<RelatablePulse, Iterable<E>> _remove(Object? object,
      {bool notification = true}) {
    final model = object is E ? object : lookup(object) as E;
    final result = <RelatablePulse, Iterable<E>>{};

    if (contains(model) &&
        this is! Unmodifiable &&
        modifiable.contains(remove)) {
      if (_nucleus.testRule.element(model, host: this, action: remove)) {
        BelongsTo<E, H>? belongsTo;
        final rels = model.relations.whereType<BelongsTo<E, H>>();
        if (rels.isNotEmpty) {
          belongsTo = rels.first;
          if (!rels.contains(has) ||
              belongsTo._nucleus.testRule
                  .element(has, host: belongsTo, action: remove)) {
            return {};
          }
        }

        if ((_nucleus.container as Set<E>).remove(model)) {
          model._nucleus.synapses.unlink(this, model);
          result[Relatable.oneAdded] = <E>{model};

          belongsTo?._set(null, notification: true);

          if (notification) {
            final post = RelatablePost._(from: this, body: result);
            _nucleus.receptor(post);
          }
        }
      }
    }
    return result;
  }
}
