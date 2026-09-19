// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

// ignore_for_file: unused_element
// ignore_for_file: hash_and_equals
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: unused_field
// ignore_for_file: prefer_final_fields

class RelationOneNucleus<H extends One, E extends One,
        R extends RelationOne<H, E, R>> extends RelationNucleusBase<H, E, R>
    implements TissueValueNucleusBase<E, R> {
  RelationOneNucleus({
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<E, R> receptor = RelatableReceptor.passThrough,
    TestRelation<H, E, R> testRule = TestRelation.allowAll,
    Synapses synapses = Synapses.enabled,
    Record? user,
    super.field,
    super.containerInit,
  }) : super(
            base: TissueValueNucleus.create<E, R>(
          bind: bind,
          context: context,
          receptor: receptor,
          testRule: testRule,
          synapses: synapses,
          container: Container.finalValue,
          forceLock: false,
          user: user,
        ));

  RelationOneNucleus.evolve(
      {Cell? bind,
      Context? context,
      RelatableReceptor<E, R>? receptor,
      TestRelation<H, E, R>? testRule,
      super.override,
      required RelationOneNucleus<H, E, R> super.principal})
      : super.evolve();

  @override
  RelationOneNucleus<H, E, R>? get principal =>
      super.principal as RelationOneNucleus<H, E, R>?;

  @override
  TissueContainer<E, ValueContainer<E>> get container =>
      get<TissueContainer<E, ValueContainer<E>>>(() => record.mask.container,
          fallback: () => principal?.container);

  @override
  Container get containerType {
    return get<Container>(() => record.mask.inheritable.container,
        fallback: () => principal?.containerType, orElse: Container.finalValue);
  }

  @override
  RelationOneNucleus<H, E, R> get clone {
    final receptor = get<RelatableReceptor<E, R>?>(
        () => record.mask.inheritable.receptor,
        orElse: null);
    final testRule = get<TestRelation<H, E, R>?>(
        () => record.mask.inheritable.testRule,
        orElse: null);
    final context =
        get<Context?>(() => record.mask.inheritable.context, orElse: null);
    return RelationOneNucleus._fromRecord(record: (
      mask: TissueNucleusBase.local(
        context: context,
        receptor: receptor != RelatableReceptor.passThrough ? receptor : null,
        testRule: testRule != TestRelation.allowAll ? testRule : null,
        synapses: synapses == Synapses.disabled
            ? Synapses.disabled
            : Synapses.enabled,
        container:
            containerType == Container.finalValue ? Container.finalValue : null,
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

  RelationOneNucleus._fromRecord({super.record}) : super.fromRecord();
}

abstract class BelongsTo<H extends One, E extends One>
    extends UnmodifiableRelationOne<H, E, BelongsTo<H, E>> {
  BelongsTo(
    RelationField<H, E, BelongsTo<H, E>> field, {
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<E, BelongsTo<H, E>> receptor =
        RelatableReceptor.passThrough,
    TestRelation<H, E, BelongsTo<H, E>> testRule = TestRelation.allowAll,
    Synapses synapses = Synapses.enabled,
  }) : this.fromNucleus(
            RelationOneNucleus<H, E, BelongsTo<H, E>>(
                bind: bind,
                context: context,
                receptor: receptor,
                testRule: testRule,
                synapses: synapses),
            field: field);

  BelongsTo.fromNucleus(
    super.properties, {
    RelationField<H, E, BelongsTo<H, E>>? field,
  });

  @override
  H get has => field.has.unmodifiable as H;

  @override
  @override
  BelongsTo<H, E> get unmodifiable => this;

  @override
  Map<RelatablePulse, Iterable<ElementValueChange>> _set(E? e,
      {bool notification = true}) {
    return _nucleus.testRule.element(e, host: this)
        ? super._set(e, notification: notification)
        : <RelatablePulse, Iterable<ElementValueChange>>{};
  }

  // @override
  // TestRelation<H,E,BelongsTo<H,E>> _testRelation(TestRelatable? testRule) {
  //   return testRule != null && testRule != TestRelatable.allowAll ? TestRelation<H,E,BelongsTo<H,E>>.fromTestRelatable(testRule) : TestRelation.allowAll;
  // }
}

///     Assigning a new value to this relation triggers a ripple through the
///     host's [synapses], notifying [Blend] and [Cascade] observers of the
///     structural shift.
/// 4.  **Homeostatic Gating**: Governed by a [TestRelation] (Immune System).
///     This authority verifies that any proposed change to the relationship—
///     such as replacing one child with another—satisfies the genomic
///     invariants and security contexts of the host.
///
/// ### Design Patterns & Mechanics:
/// *   **The Aggregate Root Pattern**: Positions the host [H] as the
///     definitive owner. In many architectures, the lifecycle of the element [E]
///     is managed or dictated by the state of its [HasOne] owner.
/// *   **The Deputy Pattern**: Supports the creation of specialized "Projections"
///     via the nucleus. This allows a [HasOne] link to be observed through
///     different governing lenses (e.g., a read-only view) without severing
///     the underlying physical connection.
/// *   **Transactional Atomicity**: All mutations to the link (setting or
///     clearing) are synchronized with the host's global [Lock], ensuring
///     that relational shifts are atomic and thread-safe within the
///     reactive-concurrent environment.
///
/// ### Comparison: `HasOne` vs. `BelongsTo`
/// *   **[HasOne]**: The host "owns" the target. (e.g., A `User` **has one**
///     `Profile`). Mutations originate here.
/// *   **[BelongsTo]**: The host "points to" an owner. (e.g., A `Profile`
///     **belongs to** a `User`). This is typically a reactive back-link.
///
/// ### Type Parameters:
/// * [H]: The species of the host organism (extending [One]) that owns
///   the relationship.
/// * [E]: The species of the target organism (extending [One]) being possessed.
abstract class HasOne<H extends One, E extends One>
    extends RelationOne<H, E, HasOne<H, E>> {
  /// Initializes a new **HasOne** relationship, materializing the
  /// **Dominant Synaptic Bridge** (Parental Authority) of a singular,
  /// mutable one-to-one or many-to-one connection.
  ///
  /// Within the **Conactive Model**, this constructor serves as the primary
  /// **Owner Link** for the host organism [H]. It defines a directional
  /// possession where the host acts as the authoritative container or
  /// progenitor for a singular entity of species [E]. Unlike its subordinate
  /// counterpart ([BelongsTo]), a [HasOne] relation created here is the
  /// active driver of the relationship's lifecycle.
  ///
  /// ### Architectural Role: Ownership & Mirror Synchronization
  /// This constructor assembles the functional tissue required for
  /// downward graph navigation and structural integrity:
  ///
  /// 1.  **Somatic Possession**: Establishes that the host [H] "holds" the
  ///     identity of [E]. This link becomes a definitive path for
  ///     **Recursive Somatic Crawls**, allowing observers to discover and
  ///     traverse the organism's hierarchy.
  /// 2.  **Bidirectional Handshaking**: Prepares the framework's **Mirror
  ///     Synchronization** logic. If an initial entity [one] is provided,
  ///     the constructor immediately attempts to locate the reciprocal
  ///     [BelongsTo] field on the target [E]. If found, it "handshakes"
  ///     to ensure the inverted link points back to the host.
  /// 3.  **Metabolic Propulsion**: Serves as a source for **Metabolic Waves**.
  ///     The relationship is wired to the host's [synapses], ensuring that
  ///     any future assignment to this relation triggers ripples through the
  ///     entity mesh.
  /// 4.  **Homeostatic Gating**: Attaches a [testRule] (Immune System) to
  ///     the link. This authority verifies that the proposed initial target
  ///     and any future updates satisfy the genomic invariants and
  ///     security contexts of the host.
  ///
  /// ### Design Patterns & Mechanics:
  /// *   **The Aggregate Root Pattern**: Positions the host [H] as the
  ///     definitive owner. This constructor ensures the host possesses the
  ///     power to evolve the connection and initiate state shifts.
  /// *   **Transactional Atomicity**: All mutations initiated through this
  ///     handle are synchronized with the host's global [Lock], ensuring
  ///     that relational shifts remain atomic in a concurrent environment.
  /// *   **Flyweight Materialization**: Leverages the [RelationOneNucleus]
  ///     to store instructional DNA, minimizing memory overhead while
  ///     retaining high-fidelity governance rules.
  ///
  /// ### Parameters:
  /// - [field]: The [RelationField] defining the structural identity and
  ///   ontological signature of this link within the host [H].
  /// - [one]: An optional initial entity instance of type [E] to relate to.
  /// - [bind]: Optional. A physical [Cell] to which this relationship's
  ///   lifecycle is tethered.
  /// - [context]: The operational [Context] (defaults to [Context.system])
  ///   determining the security tier and priority for relational signals.
  /// - [receptor]: The [RelatableReceptor] (Nervous Center) that handles
  ///   incoming signals or side-effects when the link is updated.
  /// - [testRule]: The [TestRelation] (Immune System) used to validate
  ///   the eligibility of a target organism [E].
  /// - [synapses]: Configuration governing pulse propagation, ensuring
  ///   this link is discoverable by [Cascade] and [Blend] observers.
  HasOne(
    RelationField<H, E, HasOne<H, E>> field, {
    E? one,
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<E, HasOne<H, E>> receptor = RelatableReceptor.passThrough,
    TestRelation<H, E, HasOne<H, E>> testRule = TestRelation.allowAll,
    Synapses synapses = Synapses.enabled,
  }) : this.fromNucleus(
            RelationOneNucleus<H, E, HasOne<H, E>>(
                bind: bind,
                context: context,
                receptor: receptor,
                testRule: testRule,
                synapses: synapses),
            field: field,
            one: one);

  /// The internal **Metabolic Re-hydration** (Prototypical) constructor
  /// that materializes a [HasOne] instance from an existing
  /// [RelationOneNucleus] (Genomic Blueprint).
  ///
  /// Within the **Conactive Model**, this constructor serves as the primary
  /// mechanism for **Somatic Restoration** and **Deputy Projection**. It
  /// initializes the relational tissue using a pre-configured properties
  /// record, allowing the framework to restore state during deserialization
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
  ///     the relation propagates correctly through the host's [synapses].
  /// 2.  **Mirror Synchronization (The Handshake)**: When an initial
  ///     target [one] is provided, the constructor initiates a **Recursive
  ///     Somatic Handshake**. It traverses the genomic fields of the target
  ///     organism [E] to identify a reciprocal [BelongsTo] link.
  /// 3.  **Immune Validation**: Before finalizing the reciprocal link,
  ///     it invokes the target field's **Immune System** ([validate]).
  ///     Only if the current host [has] satisfies the target's membership
  ///     criteria is the back-link atomically committed to the target's
  ///     physical storage.
  /// 4.  **Transactional Consistency**: Guarantees that the initial
  ///     bidirectional connection is established as an atomic unit of
  ///     work, preventing the "Orphan State" where one side of a
  ///     relationship points to a target that does not recognize the link.
  ///
  /// ### Design Patterns & Mechanics:
  /// *   **The Prototype Pattern**: Utilizes the [properties] record as
  ///     the definitive genomic source, ensuring the new instance inherits
  ///     all regulatory rules, contexts, and receptors.
  /// *   **Flyweight Restoration**: Optimized for high-performance mesh
  ///     reconstruction, utilizing the record-based nucleus to minimize
  ///     allocation overhead.
  /// *   **Epigenetic Continuity**: Ensures that if this constructor is
  ///     used for a Deputy, the deputy remains tethered to the principal's
  ///     physical [Cell] storage while applying its own localized
  ///     governance.
  ///
  /// ### Parameters:
  /// - [properties]: The underlying [RelationOneNucleus] record holding
  ///   the genomic metadata and transactional state.
  /// - [field]: The [RelationField] defining the relationship's structural
  ///   slot on the host organism [H].
  /// - [one]: An optional initial entity of species [E] to be
  ///   incorporated into the link.
  HasOne.fromNucleus(super.properties,
      {RelationField<H, E, HasOne<H, E>>? field, E? one})
      : super(field: field, value: one) {
    if (field != null) {
      _nucleus.synapses.link(this, downstreamCell: field);
    }

    if (one != null) {
      for (var f in one.fields) {
        if (f is RelationField && f.value is BelongsTo<E, H>) {
          if (f.validate(has, host: f)) {
            (f.value as BelongsTo<E, H>)._nucleus.container.store.value = has;
          }
          break;
        }
      }
    }
  }

  // HasOne.deputy(super.bind, {
  //   super.context,
  //   super.receptor,
  //   super.testRule,
  //   super.synapses
  // }) : super.deputy();

  /// Initiates a **Metabolic Wave** to update the singular target of this
  /// relationship.
  ///
  /// Within the **Conactive Model**, this method serves as the primary
  /// **Authoritative Actuator** for shifting the relationship's state. It
  /// attempts to transition the link from its current organism to a new target
  /// [one], triggering the full suite of relational governance, including
  /// **Immune Validation**, **Mirror Synchronization**, and **Synaptic
  /// Pulsing**.
  ///
  /// ### Architectural Role: Governed Mutation & Lifecycle Control
  /// The `set` operation is not a simple pointer assignment; it is a
  /// transactional event that manages the structural integrity of the
  /// entity mesh:
  ///
  /// 1.  **Homeostatic Gating**: Before any change occurs, the method invokes
  ///     the [testRule] (Immune System) defined in the nucleus. It verifies
  ///     that the host [H] is authorized to relate to the target [E]
  ///     within the current [context].
  /// 2.  **Somatic Consistency**: If the relationship is currently projected
  ///     through an [Unmodifiable] deputy (e.g., [UnmodifiableHasOne]),
  ///     the mutation is immediately aborted. This ensures that read-only
  ///     lenses cannot be used as vectors for "Pathogenic State" changes.
  /// 3.  **Atomic Handshaking**: Triggers the internal [_set] pipeline, which
  ///     coordinates the **Reciprocal Handshake**. If the new target [one]
  ///     has a matching [BelongsTo] field, that field is atomically updated
  ///     to point back to this host, preventing "Orphaned Nodes."
  /// 4.  **Pulse Induction**: Upon a successful transition, the method
  ///     finalizes the **Metabolic Wave**, notifying all attached [synapses],
  ///     [Blend] observers, and [Cascade] listeners that the graph topology
  ///     has shifted.
  ///
  /// ### Design Patterns & Mechanics:
  /// *   **The Command Pattern**: Encapsulates the request to change the
  ///     relationship as a governed operation that can be intercepted,
  ///     validated, or rejected by the host's nervous system.
  /// *   **Transactional Guarding**: Operates under the host's global
  ///     [Lock], ensuring that if multiple concurrent waves attempt to
  ///     modify the same link, they are processed sequentially to maintain
  ///     determinism.
  /// *   **Identity Comparison**: The underlying engine typically performs
  ///     a "Self-Correction" check; if the new target [one] is identical
  ///     to the current target, no wave is induced, and the method returns
  ///     early to preserve metabolic resources.
  ///
  /// ### Parameters:
  /// - [one]: The new target organism instance of species [E] to incorporate
  ///   into the relationship, or `null` to sever the existing link.
  ///
  /// ### Returns:
  /// `true` if the relationship was successfully evolved and the
  /// metabolic wave was committed; `false` if the transition was
  /// disallowed by the immune system or if the relation is unmodifiable.
  @override
  bool set(E? one) {
    if (this is! Unmodifiable) {
      return _set(one).isNotEmpty;
    }
    return false;
  }

  /// The internal implementation for changing the relation value and
  /// maintaining graph integrity.
  ///
  /// Workflow:
  /// 1. **Validation:** Executes the [testRule] to see if the assignment is allowed.
  /// 2. **Mirror Discovery:** Looks for a [BelongsTo<E,H>] relation on the new
  ///    element [e].
  /// 3. **Primary Update:** Calls [super._set] to update the local store and
  ///    handle basic synapses.
  /// 4. **Mirror Update:** If successful, sets the inverse [BelongsTo] on the
  ///    new element to point back to [has].
  /// 5. **Cleanup:** If there was a previous value ([before]), it notifies that
  ///    element's [BelongsTo] that it no longer points to this host.
  /// 6. **Notification:** Triggers the receptor with a [RelatablePost] if enabled.
  ///
  /// Returns a map of change events.
  @override
  Map<RelatablePulse, Iterable<ElementValueChange>> _set(E? e,
      {bool notification = true}) {
    if (_nucleus.testRule.element(e, host: this, action: set)) {
      final before = one;
      BelongsTo<E, H>? belongsTo;

      // Locate the inverse side on the incoming element
      if (e != null) {
        final rels = e.relations.whereType<BelongsTo<E, H>>();
        if (rels.isNotEmpty) {
          belongsTo = rels.first;
        }
      }

      // Perform the local update
      final map = super._set(e, notification: false);
      if (map.isNotEmpty) {
        // Update the new element's mirror reference
        belongsTo?._set(has.unmodifiable as H, notification: false);

        // Clear the old element's mirror reference
        if (before != null) {
          final rels = before.relations.whereType<BelongsTo<E, H>>();
          if (rels.isNotEmpty && rels.first.isNotEmpty) {
            rels.first._set(null, notification: notification);
          }
        }

        if (notification) {
          final post = RelatablePost._(from: this, body: map);
          _nucleus.receptor(post);
        }
      }
      return map;
    }
    return {};
  }

  /// Intercepts function calls to apply the [testRule] before execution.
  ///
  /// This allows the relation to guard specific domain actions or methods
  /// by checking permissions/validity within the current [context].
  @override
  dynamic apply(Function function, List? positionalArguments,
      [Map<Symbol, dynamic>? namedArguments]) {
    if (_nucleus.testRule.action(function, host: this, arguments: (
      positionalArguments: positionalArguments,
      namedArguments: namedArguments
    ))) {
      return Function.apply(function, positionalArguments, namedArguments);
    }
  }

  /// Returns an unmodifiable view of this [HasOne] relation.
  ///
  /// Subclasses or implementations must provide the specific unmodifiable
  /// variant to prevent mutation while still allowing read access to [one].
  @override
  HasOne<H, E> get unmodifiable;

  // bool get isExclusive {
  //   return Reference.instance.model<E>().isBelongsTo<H>();
  // }

  // @override
  // late final HasOne<H,E> unmodifiable = UnmodifiableHasOne<H,E>(this);

  // static HasOne<H,E> fromMap<H extends One, E extends One>(Map<String, dynamic> map, {int cascade = 0, Set<One>? lookup}) {
  //   if (lookup != null) {
  //     lookup = Reference.instance._toModels(lookup);
  //   }
  //
  //   final types = Reference.instance.modelTypes;
  //   if (H != One && types.contains(H) && E != One && types.contains(H)) {
  //     if (map.containsKey('_\$Has') && map['_\$Has'] is Map) {
  //       return Reference.instance.fromMap<HasOne<H,E>>(map, cascade: cascade, lookup: lookup);
  //     }
  //   }
  //
  //   if (['_\$Has', '_\$HasType', '_\$ElementType'].every((s) => map.containsKey(s))) {
  //     if (types.any((e) => e.toString() == map['_\$HasType'].toString() && types.any((e) => e.toString() == map['_\$ElementType'].toString()))) {
  //       return Reference.instance.fromMap<HasOne<H,E>>(map, cascade: cascade, lookup: lookup);
  //     }
  //   }
  //   throw ArgumentError.value(map, 'Model Type(s) not available');
  // }

  // @override
  // TestRelation<H,E,HasOne<H,E>> _testRelation(TestRelatable? testRule) {
  //   return testRule != null && testRule != TestRelatable.allowAll ? TestRelation<H,E,HasOne<H,E>>.fromTestRelatable(testRule) : TestRelation.allowAll;
  // }
}
