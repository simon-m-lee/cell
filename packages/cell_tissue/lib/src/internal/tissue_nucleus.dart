// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

/// Internal implementation of [TissueNucleus] for generic tissues.
///
/// This class is not intended for direct use. It is the concrete nucleus
/// that powers `_Tissue` and its subclasses. It extends [TissueNucleusBase]
/// and provides the specific logic for cloning and evolution.
class _TissueNucleus<E,I extends Iterable<E>, C extends Tissue<E>> extends TissueNucleusBase<E,I,C> {

  _TissueNucleus({
    super.bind,
    super.context = Context.system,
    super.receptor = TissueReceptor.passThrough,
    super.testRule = TestTissue.allowAll,
    super.synapses = Synapses.enabled,

    super.forceLock,
    super.user,
    Container? container,
  }) : super(container: container ?? Container.create<E,I>());

  _TissueNucleus.evolve({
    Container? container,

    Cell? bind,
    Context? context,
    TissueReceptor<E,C>? receptor,
    TestTissue<E,C>? testRule,
    Synapses? synapses,

    bool forceLock = true,

    TissueNucleus<E>? override,
    required super.principal
  }) : super.evolve(
      override: override ?? _TissueNucleus<E,I,C>.fromRecord(
          TissueNucleusBase.local(
              container: container,
              bind: bind, context: context, receptor: receptor, testRule: testRule, synapses: synapses,
              forceLock: forceLock
          ))
  );

  _TissueNucleus.fromRecord(super.record) : super.fromRecord();

  @override
  TissueNucleusBase<E,I,C> get clone {
    return TissueNucleus.create<E,I,C>(
      container: containerType,
      context: context,
      receptor: receptor,
      testRule: testRule,
      synapses: synapses != Synapses.disabled ? Synapses.enabled : Synapses.disabled,
      user: user,
      forceLock: false
    );
  }

}

/// The foundational blueprint that defines the behaviour, storage strategy,
/// and governance of a reactive collection.
///
/// [TissueNucleusBase] holds the immutable configuration – the receptor,
/// validation rule, context, synapses, and the physical container strategy –
/// that governs how a [Tissue] reacts to mutations. It is the **DNA** of
/// every reactive collection.
///
/// ### Where to start
/// You never extend this class directly. The framework provides concrete
/// implementations via [TissueNucleus.create] and the [Tissue] factories.
/// This class is the base that powers the internal `_TissueNucleus`.
///
/// ### When to use
/// Only if you are building a custom collection type that needs to override
/// the default nucleus behaviour. For standard use, the provided factories
/// are sufficient.
///
/// ### How it works
/// - It extends [NucleusBase] to inherit the core property resolution engine
///   (bitmask records, principal chain, lock management).
/// - It specialises the storage type to [I] (e.g., `List<E>`, `Set<E>`) and
///   forces the container strategy via the [container] parameter.
/// - It implements the [containerType] resolution by walking up the
///   `principal` chain, defaulting to a strategy inferred from [I].
/// - It provides the `clone` getter to create an independent copy of the
///   nucleus with a fresh lock and synapses, essential for creating new
///   collection instances from a template.
///
/// ### Non‑obvious
/// - The [container] is **structural** – its type (List, Set, Map, Queue, etc.)
///   is fixed at creation and inherited by all deputies. A deputy cannot
///   change a List into a Set.
/// - The nucleus is a **flyweight** – many collections can share the same
///   nucleus without duplicating memory.
/// - The [clone] getter creates a root nucleus (no principal) with its own
///   lock, making it safe to use for independent collection instances.
/// - The [principal] chain enables **prototype inheritance** – a deputy
///   can override only specific properties (like `testRule`) while inheriting
///   the rest from its principal.
/// - The static [local] method is the engine behind the framework's
///   **record‑based bitmask optimisation** – it stores only non‑default
///   properties, eliminating the "nullable field tax."
///
/// ### Example: Reusing a validated nucleus
/// ```dart
/// final validNucleus = TissueNucleus.create<int, List<int>, TissueList<int>>(
///   testRule: TestTissue<int>((v) => v >= 0),
///   container: Container.list,
/// );
/// final list1 = Tissue.fromNucleus(validNucleus);
/// final list2 = Tissue.fromNucleus(validNucleus); // shares logic, not data
/// ```
///
/// ### Type Parameters:
/// - [E]: The type of elements held within the collection.
/// - [I]: The specific [Iterable] implementation used for internal storage
///   (e.g., `List<E>`, `Set<E>`, `Queue<E>`).
/// - [C]: The target [Tissue] interface (e.g., `TissueList<E>`), used
///   to ensure that receptors and validation rules are strictly type‑safe.
///
/// See also:
/// - [TissueNucleus] – the public interface for collection configurations.
/// - [NucleusBase] – the foundational class for all flyweight property sets.
/// - [TissueContainer] – the physical storage mediator managed by this class.
abstract class TissueNucleusBase<E, I extends Iterable<E>, C extends Tissue<E>>
    extends NucleusBase implements TissueNucleus<E> {

  /// **Primary Constructor** – defines the immutable behaviour and storage
  /// strategy for a reactive collection.
  ///
  /// ### Who should call this
  /// **Internal framework use only.** This constructor is `public` only so
  /// that concrete subclasses (like `_TissueNucleus`) can invoke it via
  /// `super()`. **Application code should never call this directly.**
  ///
  /// If you need a nucleus, use [TissueNucleus.create] to create one
  /// from scratch, or [TissueNucleus.evolve] to derive one from an
  /// existing principal.
  ///
  /// ### When to use (as a framework extender)
  /// You are writing a custom collection implementation that extends
  /// `TissueNucleusBase` and need to pass configuration up to the base.
  ///
  /// ### How it works
  /// 1. The [container] parameter defines the physical storage strategy.
  ///    If omitted, the framework infers a default from the iterable type [I].
  /// 2. All other parameters are passed to the super‑constructor, which
  ///    stores them in a memory‑optimised record using bitmasking.
  /// 3. The resulting nucleus is immutable – you cannot change its
  ///    configuration after creation.
  ///
  /// ### Non‑obvious
  /// - The [receptor] is automatically cloned if it is already activated
  ///   (bound to another cell), ensuring that each nucleus starts with a
  ///   clean logic instance.
  /// - If [synapses] is [Synapses.enabled], a fresh, empty registry is
  ///   created for the new collection. If you pass [Synapses.disabled],
  ///   the collection will be terminal (no broadcasts).
  /// - The [forceLock] flag controls whether a new synchronization lock is
  ///   allocated. `false` (default) creates a new lock; `true` shares the
  ///   principal's lock (used for deputies).
  ///
  /// ### Example (Internal – how the framework uses it)
  /// ```dart
  /// class _MyCustomNucleus<E> extends TissueNucleusBase<E, List<E>, TissueList<E>> {
  ///   _MyCustomNucleus({super.container = Container.list, ...}) : super();
  /// }
  /// ```
  ///
  /// ### Parameters:
  /// - [ephemeralPolicy]: Optional lifecycle policy (TTL/event limit).
  /// - [container]: The physical storage template. If `null`, a default
  ///   container for type [I] is resolved.
  /// - [bind]: Optional upstream [Cell] – the collection will automatically
  ///   mirror changes from this source (deputy pattern).
  /// - [context]: Security tier and execution domain (default: [Context.system]).
  /// - [receptor]: Mutation processor – defaults to [TissueReceptor.passThrough].
  /// - [testRule]: Validation gate – defaults to [TestTissue.allowAll].
  /// - [synapses]: Distribution configuration – defaults to [Synapses.enabled].
  /// - [forceLock]: If `true`, shares the principal's lock (optimisation
  ///   for deputies); if `false` (default), allocates a new lock.
  /// - [user]: Optional custom metadata (e.g., UI hints, serialisation tags).
  /// - [others]: A specialised extension point for injecting collection‑
  ///   specific metadata (e.g., `capacity` for queues) into the record.
  TissueNucleusBase({
    EphemeralPolicy? ephemeralPolicy,

    Container? container,

    Cell? bind,
    Context context = Context.system,
    TissueReceptor<E,C> receptor = TissueReceptor.passThrough,
    TestTissue<E,C> testRule = TestTissue.allowAll,
    Synapses synapses = Synapses.enabled,

    bool forceLock = false,
    Record? user,
    Record? others

  }) : super.fromRecord(
      (local<E,I,C>(
          container: container,
          bind: bind,
          context: context,
          receptor: receptor,
          testRule: testRule,
          synapses: synapses,
          forceLock: forceLock,
          user: user,
          others: others
      ))
  );

  /// **Low‑level Record Constructor** – instantiates a nucleus from a
  /// pre‑packed property record.
  ///
  /// ### Who should call this
  /// **Strictly internal framework use only.** This constructor bypasses
  /// all parameter validation and default‑value logic. It is designed for
  /// performance‑critical paths like cloning and state restoration.
  /// **Application code must never call this.**
  ///
  /// ### When to use (as a framework extender)
  /// - When implementing `clone` or `evolve` in a custom nucleus subclass.
  /// - When restoring a nucleus from a serialised state where the record
  ///   shape is already guaranteed.
  ///
  /// ### How it works
  /// - The provided [record] is directly assigned to the internal storage.
  /// - No validation or default‑value logic is performed – the record is
  ///   assumed to be correct and complete.
  /// - This bypasses the bitmask optimisation of the primary constructor,
  ///   which is why it is only safe to use when the record shape is
  ///   guaranteed.
  ///
  /// ### Non‑obvious
  /// - The record must contain all necessary fields for a collection nucleus,
  ///   including the `container` (of type [Container<I>]) and a
  ///   synchronisation [Lock] (unless sharing one via a principal).
  /// - If the record is malformed, the resulting nucleus may behave
  ///   unpredictably – use with extreme caution.
  /// - This constructor is `const`‑friendly, enabling compile‑time
  ///   instantiation of static nuclei for zero‑cost default configurations.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final record = (mask: (container: Container.list, ...), principal: null);
  /// final nucleus = TissueNucleusBase.fromRecord(record: record);
  /// ```
  ///
  /// ### Parameters:
  /// - [record]: The internal property record – an implementation‑specific
  ///   Dart `Record` containing all nucleus fields.
  const TissueNucleusBase.fromRecord(super.record) : super.fromRecord();

  /// **Evolution Constructor** – creates a specialised deputy nucleus by
  /// extending an existing [principal].
  ///
  /// ### Who should call this
  /// This constructor is part of the **internal deputy machinery**. While it
  /// is `public`, it is intended to be called only by the framework when
  /// you invoke `deputy()` on a [Tissue]. **Application code should use
  /// `Tissue.deputy()` or [TissueNucleus.evolve] instead.**
  ///
  /// ### When to use (as a framework extender)
  /// You are building a custom deputy implementation and need to control
  /// exactly how a child nucleus inherits from its principal.
  ///
  /// ### How it works
  /// 1. The [principal] provides the baseline configuration (including the
  ///    container type and all structural properties).
  /// 2. If [override] is provided, its entire record is used as the local
  ///    base – any individual parameters (bind, context, etc.) are ignored.
  /// 3. If [override] is `null`, a new local record is built from the
  ///    individual parameters, falling back to the principal's values for
  ///    any omitted property.
  /// 4. The new nucleus links to the [principal] via its `principal` chain,
  ///    so property lookups walk up the chain.
  /// 5. The resulting nucleus shares the same [Lock] as the principal
  ///    (unless [override] introduces its own lock).
  ///
  /// ### Non‑obvious
  /// - The [container] type is **always inherited** from the principal.
  ///   You cannot change a List into a Set through a deputy.
  /// - If you override the [synapses], the deputy gets its own observer
  ///   registry – observers attached to the deputy are separate from
  ///   those on the principal.
  /// - The [testRule] passed here is **layered on top** of the principal's
  ///   testRule (via `+`). You can only narrow permissions, never widen.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final principal = TissueNucleus.create<int, List<int>, TissueList<int>>(
  ///   container: Container.list,
  /// );
  /// final readOnlyNucleus = TissueNucleusBase.evolve(
  ///   principal: principal,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlyList = Tissue.fromNucleus(readOnlyNucleus);
  /// ```
  ///
  /// ### Parameters:
  /// - [principal]: **Required**. The source nucleus to inherit from.
  /// - [override]: Optional. A complete nucleus whose record will replace
  ///   the local base. If provided, individual parameters are ignored.
  /// - [bind]: Optional override for the upstream cell.
  /// - [context]: Optional override for the execution context.
  /// - [receptor]: Optional override for the mutation processor.
  /// - [testRule]: Optional override for the validation rule (layered
  ///   on top of the principal's).
  /// - [synapses]: Optional override for propagation behaviour.
  /// - (Other parameters like [forceLock] and [user] are typically
  ///   inherited from the principal or taken from [override]).
  TissueNucleusBase.evolve({
    super.override,
    required TissueNucleus<E> super.principal
  }) : super.evolve();

  /// Generates a memory‑optimised [Record] containing the structural "local"
  /// property state of a reactive tissue's [Nucleus].
  ///
  /// This internal static method is the foundational engine for the framework's
  /// **Flyweight Record Pattern**. Instead of allocating a traditional class
  /// instance with numerous nullable fields—which incurs significant memory
  /// overhead in large‑scale reactive graphs—this method calculates the exact
  /// data "shape" required using a tiered bitmasking technique.
  ///
  /// ### Who should call this
  /// **Strictly internal framework use only.** This method is the engine
  /// behind the primary constructor and the `evolve` mechanism. Application
  /// code never needs to call this directly.
  ///
  /// ### How it works
  /// 1. **Inheritable Tier (4‑bit)**: Bundles [context], [receptor],
  ///    [testRule], and [container] if they deviate from defaults.
  /// 2. **Global Tier (6‑bit)**: Creates a master mask for the presence of
  ///    the inheritable bundle, [user] metadata, [Lock] (unless [forceLock]),
  ///    [synapses], [bind], and the physical [container] storage.
  /// 3. **Record Mapping**: A comprehensive `switch` expression maps the
  ///    calculated mask states to a specific **Named Record** shape,
  ///    allowing the Dart compiler to allocate the smallest possible memory
  ///    segment.
  ///
  /// ### Non‑obvious
  /// - The [receptor] is automatically cloned if it is already activated.
  /// - If [synapses] is [Synapses.enabled], a fresh, empty registry is created.
  /// - The [forceLock] flag determines whether a new [Lock] is allocated.
  /// - The [others] parameter allows tissue‑specific metadata (e.g., `capacity`
  ///   for queues) to be injected into the unified record shape.
  ///
  /// ### Parameters:
  /// - [container]: The physical storage template defining the collection type.
  /// - [bind]: Optional upstream [Cell] for reactive lifecycle tethering.
  /// - [context]: The operational environment (e.g., [Context.system]).
  /// - [receptor]: The command engine for processing mutation signals.
  /// - [testRule]: The security gatekeeper for structural validation.
  /// - [synapses]: Configuration for managing observers and pulse bubbling.
  /// - [forceLock]: If `true`, avoids allocating a new synchronization primitive.
  /// - [user]: Optional record for ad‑hoc developer metadata.
  /// - [others]: A specialised parameter for injecting tissue‑specific
  ///   logic (e.g., `capacity` for queues) into the unified record shape.
  ///
  /// ### Returns:
  /// A specialised [Record] containing the minimal set of non‑default
  /// properties required to initialize a [TissueNucleusBase].
  static Record local<E,I extends Iterable<E>,C extends Tissue<E>>({
    Container? container,

    Cell? bind,
    Context? context,
    TissueReceptor<E,C>? receptor,
    TestTissue<E,C>? testRule,
    Synapses? synapses,

    bool forceLock = false,

    Record? user,
    dynamic others
  }) {

    if (synapses == Synapses.enabled) {
      synapses = Synapses();
    }

    receptor = receptor != null ? receptor.isActivated
        ? receptor == TissueReceptor.passThrough ? _TissueReceptor<E,C>.fromRecord() : receptor.clone
        : receptor : null;

    final inheritableMask = (
        (context != null && context != Context.system        ? 1 : 0) |
        (receptor != null && receptor != TissueReceptor.passThrough ? 2 : 0 ) |
        (testRule != null && testRule != TestTissue.allowAll      ? 4 : 0) |
        (container != null && container != Container.create<E,I>()  ? 8 : 0)
    );

    final inheritable = switch (inheritableMask) {
      0 => (),
      1 => (context: context),
      2 => (receptor: receptor),
      3 => (context: context, receptor: receptor),
      4 => (testRule: testRule),
      5 => (context: context, testRule: testRule),
      6 => (receptor: receptor, testRule: testRule),
      7 => (context: context, receptor: receptor, testRule: testRule),
      8 => (container: container),
      9 => (context: context, container: container),
      10 => (receptor: receptor, container: container),
      11 => (context: context, receptor: receptor, container: container),
      12 => (testRule: testRule, container: container),
      13 => (context: context, testRule: testRule, container: container),
      14 => (receptor: receptor, testRule: testRule, container: container),
      15 => (context: context, receptor: receptor, testRule: testRule, container: container),
      _ => ()
    };

    final containerStorage = container != null ? (container as _Container).create<E,I>() : null;

    final mask = (
        (inheritableMask > 0      ? 1 : 0) |
        (user != null             ? 2 : 0) |
        (!forceLock                ? 4 : 0) |
        (synapses != null         ? 8 : 0) |
        (bind != null             ? 16 : 0)|
        (containerStorage != null ? 32 : 0)
    );

    if (others != null) {

      return switch (mask) {
        0 => (others: others),
        1 => (inheritable: inheritable, others: others),
        2 => (user: user, others: others),
        3 => (inheritable: inheritable, user: user, others: others),
        4 => (forceLock: forceLock, others: others),
        5 => (inheritable: inheritable, forceLock: forceLock, others: others),
        6 => (user: user, forceLock: forceLock, others: others),
        7 => (inheritable: inheritable, user: user, forceLock: forceLock, others: others),
        8 => (synapses: synapses, others: others),
        9 => (inheritable: inheritable, synapses: synapses, others: others),
        10 => (user: user, synapses: synapses, others: others),
        11 => (inheritable: inheritable, user: user, synapses: synapses, others: others),
        12 => (forceLock: forceLock, synapses: synapses, others: others),
        13 => (inheritable: inheritable, forceLock: forceLock, synapses: synapses, others: others),
        14 => (user: user, forceLock: forceLock, synapses: synapses, others: others),
        15 => (inheritable: inheritable, user: user, forceLock: forceLock, synapses: synapses, others: others),
        16 => (bind: bind, others: others),
        17 => (inheritable: inheritable, bind: bind, others: others),
        18 => (user: user, bind: bind, others: others),
        19 => (inheritable: inheritable, user: user, bind: bind, others: others),
        20 => (forceLock: forceLock, bind: bind, others: others),
        21 => (inheritable: inheritable, forceLock: forceLock, bind: bind, others: others),
        22 => (user: user, forceLock: forceLock, bind: bind, others: others),
        23 => (inheritable: inheritable, user: user, forceLock: forceLock, bind: bind, others: others),
        24 => (synapses: synapses, bind: bind, others: others),
        25 => (inheritable: inheritable, synapses: synapses, bind: bind, others: others),
        26 => (user: user, synapses: synapses, bind: bind, others: others),
        27 => (inheritable: inheritable, user: user, synapses: synapses, bind: bind, others: others),
        28 => (forceLock: forceLock, synapses: synapses, bind: bind, others: others),
        29 => (inheritable: inheritable, forceLock: forceLock, synapses: synapses, bind: bind, others: others),
        30 => (user: user, forceLock: forceLock, synapses: synapses, bind: bind, others: others),
        31 => (inheritable: inheritable, user: user, forceLock: forceLock, synapses: synapses, bind: bind, others: others),
        32 => (container: containerStorage, others: others),
        33 => (inheritable: inheritable, container: containerStorage, others: others),
        34 => (user: user, container: containerStorage, others: others),
        35 => (inheritable: inheritable, user: user, container: containerStorage, others: others),
        36 => (forceLock: forceLock, container: containerStorage, others: others),
        37 => (inheritable: inheritable, forceLock: forceLock, container: containerStorage, others: others),
        38 => (user: user, forceLock: forceLock, container: containerStorage, others: others),
        39 => (inheritable: inheritable, user: user, forceLock: forceLock, container: containerStorage, others: others),
        40 => (synapses: synapses, container: containerStorage, others: others),
        41 => (inheritable: inheritable, synapses: synapses, container: containerStorage, others: others),
        42 => (user: user, synapses: synapses, container: containerStorage, others: others),
        43 => (inheritable: inheritable, user: user, synapses: synapses, container: containerStorage, others: others),
        44 => (forceLock: forceLock, synapses: synapses, container: containerStorage, others: others),
        45 => (inheritable: inheritable, forceLock: forceLock, synapses: synapses, container: containerStorage, others: others),
        46 => (user: user, forceLock: forceLock, synapses: synapses, container: containerStorage, others: others),
        47 => (inheritable: inheritable, user: user, forceLock: forceLock, synapses: synapses, container: containerStorage, others: others),
        48 => (bind: bind, container: containerStorage, others: others),
        49 => (inheritable: inheritable, bind: bind, container: containerStorage, others: others),
        50 => (user: user, bind: bind, container: containerStorage, others: others),
        51 => (inheritable: inheritable, user: user, bind: bind, container: containerStorage, others: others),
        52 => (forceLock: forceLock, bind: bind, container: containerStorage, others: others),
        53 => (inheritable: inheritable, forceLock: forceLock, bind: bind, container: containerStorage, others: others),
        54 => (user: user, forceLock: forceLock, bind: bind, container: containerStorage, others: others),
        55 => (inheritable: inheritable, user: user, forceLock: forceLock, bind: bind, container: containerStorage, others: others),
        56 => (synapses: synapses, bind: bind, container: containerStorage, others: others),
        57 => (inheritable: inheritable, synapses: synapses, bind: bind, container: containerStorage, others: others),
        58 => (user: user, synapses: synapses, bind: bind, container: containerStorage, others: others),
        59 => (inheritable: inheritable, user: user, synapses: synapses, bind: bind, container: containerStorage, others: others),
        60 => (forceLock: forceLock, synapses: synapses, bind: bind, container: containerStorage, others: others),
        61 => (inheritable: inheritable, forceLock: forceLock, synapses: synapses, bind: bind, container: containerStorage, others: others),
        62 => (user: user, forceLock: forceLock, synapses: synapses, bind: bind, container: containerStorage, others: others),
        63 => (inheritable: inheritable, user: user, forceLock: forceLock, synapses: synapses, bind: bind, container: containerStorage, others: others),
        _ => ()
      };
    }

    return switch (mask) {
      0 => (),
      1 => (inheritable: inheritable),
      2 => (user: user),
      3 => (inheritable: inheritable, user: user),
      4 => (forceLock: forceLock),
      5 => (inheritable: inheritable, forceLock: forceLock),
      6 => (user: user, forceLock: forceLock),
      7 => (inheritable: inheritable, user: user, forceLock: forceLock),
      8 => (synapses: synapses),
      9 => (inheritable: inheritable, synapses: synapses),
      10 => (user: user, synapses: synapses),
      11 => (inheritable: inheritable, user: user, synapses: synapses),
      12 => (forceLock: forceLock, synapses: synapses),
      13 => (inheritable: inheritable, forceLock: forceLock, synapses: synapses),
      14 => (user: user, forceLock: forceLock, synapses: synapses),
      15 => (inheritable: inheritable, user: user, forceLock: forceLock, synapses: synapses),
      16 => (bind: bind),
      17 => (inheritable: inheritable, bind: bind),
      18 => (user: user, bind: bind),
      19 => (inheritable: inheritable, user: user, bind: bind),
      20 => (forceLock: forceLock, bind: bind),
      21 => (inheritable: inheritable, forceLock: forceLock, bind: bind),
      22 => (user: user, forceLock: forceLock, bind: bind),
      23 => (inheritable: inheritable, user: user, forceLock: forceLock, bind: bind),
      24 => (synapses: synapses, bind: bind),
      25 => (inheritable: inheritable, synapses: synapses, bind: bind),
      26 => (user: user, synapses: synapses, bind: bind),
      27 => (inheritable: inheritable, user: user, synapses: synapses, bind: bind),
      28 => (forceLock: forceLock, synapses: synapses, bind: bind),
      29 => (inheritable: inheritable, forceLock: forceLock, synapses: synapses, bind: bind),
      30 => (user: user, forceLock: forceLock, synapses: synapses, bind: bind),
      31 => (inheritable: inheritable, user: user, forceLock: forceLock, synapses: synapses, bind: bind),
      32 => (container: containerStorage),
      33 => (inheritable: inheritable, container: containerStorage),
      34 => (user: user, container: containerStorage),
      35 => (inheritable: inheritable, user: user, container: containerStorage),
      36 => (forceLock: forceLock, container: containerStorage),
      37 => (inheritable: inheritable, forceLock: forceLock, container: containerStorage),
      38 => (user: user, forceLock: forceLock, container: containerStorage),
      39 => (inheritable: inheritable, user: user, forceLock: forceLock, container: containerStorage),
      40 => (synapses: synapses, container: containerStorage),
      41 => (inheritable: inheritable, synapses: synapses, container: containerStorage),
      42 => (user: user, synapses: synapses, container: containerStorage),
      43 => (inheritable: inheritable, user: user, synapses: synapses, container: containerStorage),
      44 => (forceLock: forceLock, synapses: synapses, container: containerStorage),
      45 => (inheritable: inheritable, forceLock: forceLock, synapses: synapses, container: containerStorage),
      46 => (user: user, forceLock: forceLock, synapses: synapses, container: containerStorage),
      47 => (inheritable: inheritable, user: user, forceLock: forceLock, synapses: synapses, container: containerStorage),
      48 => (bind: bind, container: containerStorage),
      49 => (inheritable: inheritable, bind: bind, container: containerStorage),
      50 => (user: user, bind: bind, container: containerStorage),
      51 => (inheritable: inheritable, user: user, bind: bind, container: containerStorage),
      52 => (forceLock: forceLock, bind: bind, container: containerStorage),
      53 => (inheritable: inheritable, forceLock: forceLock, bind: bind, container: containerStorage),
      54 => (user: user, forceLock: forceLock, bind: bind, container: containerStorage),
      55 => (inheritable: inheritable, user: user, forceLock: forceLock, bind: bind, container: containerStorage),
      56 => (synapses: synapses, bind: bind, container: containerStorage),
      57 => (inheritable: inheritable, synapses: synapses, bind: bind, container: containerStorage),
      58 => (user: user, synapses: synapses, bind: bind, container: containerStorage),
      59 => (inheritable: inheritable, user: user, synapses: synapses, bind: bind, container: containerStorage),
      60 => (forceLock: forceLock, synapses: synapses, bind: bind, container: containerStorage),
      61 => (inheritable: inheritable, forceLock: forceLock, synapses: synapses, bind: bind, container: containerStorage),
      62 => (user: user, forceLock: forceLock, synapses: synapses, bind: bind, container: containerStorage),
      63 => (inheritable: inheritable, user: user, forceLock: forceLock, synapses: synapses, bind: bind, container: containerStorage),
      _ => ()
    };


  }

  /// Retrieves the hierarchical principal of this property configuration within
  /// the reactive collection tree.
  ///
  /// In the `cell` framework's property model, [TissueNucleusBase] instances
  /// can be organized in a chain to support behavioral inheritance. This getter
  /// acts as the "super" link in that chain.
  ///
  /// ### Where to start
  /// You rarely need to read this directly. The framework uses it internally
  /// when you create a deputy via `deputy()`. It's what makes a deputy "share"
  /// the same logic and storage as its principal.
  ///
  /// ### When to use
  /// Only if you are building a custom collection implementation and need to
  /// traverse the inheritance chain to resolve a property value. For most
  /// application code, you never call this – the framework handles it for you.
  ///
  /// ### How it works
  /// 1. **Delegation**: If a property is requested but not explicitly defined
  ///    in the local [record], the system "walks up" this [principal] chain.
  /// 2. **Contextual Overrides**: A "Deputy" collection (created via `deputy()`)
  ///    typically has a [principal] link to the original collection's nucleus,
  ///    allowing it to inherit the physical data [container] while providing
  ///    a local override for the [context] or [testRule].
  /// 3. **Termination**: The chain ends when this getter returns `null` –
  ///    that's the "root" nucleus.
  ///
  /// ### Non‑obvious
  /// - The type is overridden to `TissueNucleusBase<E, I, C>?` – a covariant
  ///   override that ensures you get a properly typed principal when you need
  ///   to access collection‑specific methods (like `containerType`).
  /// - Even though the getter is `public`, it's intended for internal
  ///   framework use. Mutating or replacing the principal after construction
  ///   is not supported – the nucleus is immutable.
  /// - The principal chain determines the `containerType` and all other
  ///   structural properties; deputies cannot change the storage type.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final list = TissueList<int>();
  /// final deputy = list.deputy(testRule: TestTissue.readOnly);
  /// // deputy._nucleus.principal points back to list._nucleus
  /// // So when deputy needs the container type, it delegates to list._nucleus.
  /// ```
  ///
  /// ### Returns:
  /// The parent nucleus that this configuration extends, or `null` if this is
  /// a root nucleus with no ancestors.
  @override
  TissueNucleusBase<E,I,C>? get principal => super.principal as TissueNucleusBase<E,I,C>?;

  /// The [TissueContainer] responsible for managing the physical storage,
  /// low‑level data access, and structural strategy for this reactive tissue.
  ///
  /// The [container] serves as the "source of truth" and the primary storage
  /// abstraction for the collection's data. It encapsulates the underlying
  /// Dart collection implementation (such as a `List`, `Set`, or `Map`) into
  /// a unified, reactive‑ready interface.
  ///
  /// ### Where to start
  /// You rarely need to access this directly. The collection's public API
  /// (e.g., `add`, `remove`, `length`) delegates to this container, but you
  /// typically work with the high‑level `Tissue` methods.
  ///
  /// ### When to use
  /// Only if you are building a custom collection implementation that needs
  /// to manipulate the underlying storage directly. For most application code,
  /// the provided collection methods are sufficient.
  ///
  /// ### How it works
  /// 1. **Local Lookup**: First attempts to retrieve a `container` defined
  ///    explicitly in the current nucleus's record.
  /// 2. **Parental Delegation**: If not found, it recursively "walks up"
  ///    the `principal` chain to find the container from an ancestor.
  /// 3. **Root Synchronization**: The search continues until it reaches
  ///    the root property set that originally initialized the physical storage.
  ///    This ensures that all derived views (deputies) share the same
  ///    underlying data instance.
  ///
  /// ### Non‑obvious
  /// - The container is resolved lazily – it is only instantiated when first
  ///   accessed, saving memory for collections that are never used.
  /// - For deputies, the container is always inherited from the principal –
  ///   a deputy never has its own container.
  /// - The container's type (List, Set, Map, Queue, etc.) is fixed at the
  ///   root nucleus and cannot be changed by deputies.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final container = list._nucleus.container;
  /// print(container.length); // number of elements
  /// ```
  ///
  /// ### Returns:
  /// The resolved [TissueContainer<E, I>] associated with this property set.
  @override
  TissueContainer<E,I> get container {
    return get<TissueContainer<E,I>>(() => record.mask.container, fallback: () => principal?.container);
  }

  /// The physical storage strategy (e.g., List, Set, Map, Queue) used by this
  /// collection.
  ///
  /// This getter resolves the [Container] type by walking up the `principal`
  /// chain. It determines the collection's structural behaviour – whether it
  /// is ordered, unique, key‑value, etc.
  ///
  /// ### When to use
  /// Read this to understand what kind of storage the collection uses.
  /// This is useful for conditional logic or debugging.
  ///
  /// ### Non‑obvious
  /// - This is a **structural** property – it is fixed at the root nucleus
  ///   and inherited by all deputies. A deputy cannot change a List into a Set.
  /// - Defaults to [Container.create<E, I>()] if not set.
  @override
  Container get containerType {
    return get<Container>(() => record.mask.inhertiable.container, fallback: () => principal?.containerType, orElse: Container.create<E,I>());
  }

  /// The [TestTissue] validation logic used to guard the integrity and
  /// state consistency of the reactive tissue.
  ///
  /// The [testRule] acts as a functional "gatekeeper" during the tissue's
  /// mutation cycle. Before any mutation pulse (such as `add`, `remove`, or
  /// `update`) is applied to the underlying [container], the framework
  /// invokes this rule to determine if the proposed change is valid within
  /// the current [context].
  ///
  /// ### Where to start
  /// You typically set this when creating a collection via the [Tissue]
  /// factories. For example:
  /// ```dart
  /// final list = TissueList<int>(
  ///   testRule: TestTissue<int>((v) => v >= 0),
  /// );
  /// ```
  ///
  /// ### When to use
  /// Read this when you need to understand what validation rules are applied
  /// to the collection – e.g., for conditional UI logic (disabling an "Add"
  /// button) or for debugging.
  ///
  /// ### How it works
  /// 1. **Local Lookup**: First attempts to retrieve the `testRule` defined
  ///    directly in the current nucleus's record.
  /// 2. **Parental Inheritance**: If not found, it recursively "walks up"
  ///    the `principal` chain to find the rule from an ancestor.
  /// 3. **Default Fallback**: If the root is reached without finding a rule,
  ///    it defaults to [TestTissue.allowAll] – no restrictions.
  ///
  /// ### Non‑obvious
  /// - For deputies, the [testRule] is **layered on top** of the principal's
  ///   rule (via `+`). You can only narrow permissions, never widen.
  /// - The rule is invoked for **every** mutation attempt – it is a hot path,
  ///   so keep it efficient.
  /// - The rule can be asynchronous ([FutureOr<bool>]) – the framework
  ///   suspends the mutation until the future completes.
  ///
  /// ### Example
  /// ```dart
  /// final list = TissueList<int>(testRule: TestTissue<int>((v) => v > 0));
  /// print(list.validate); // the TestTissue instance
  /// ```
  ///
  /// ### Returns:
  /// The resolved [TestTissue<E, C>] providing the validation logic.
  @override
  TestTissue<E,C> get testRule {
    return get<TestTissue<E,C>>(() => record.mask.testRule, fallback: () => principal?.testRule, orElse: TestTissue.allowAll);
  }

  /// The [TissueReceptor] responsible for processing mutation signals and
  /// orchestrating state updates for the reactive collection.
  ///
  /// The [receptor] is the functional heart of the tissue's reactive cycle.
  /// It acts as a specialised "reducer" or "command handler" that intercepts
  /// incoming [TissueEvent] signals (such as `add`, `remove`, or `clear`)
  /// and translates them into concrete operations on the underlying [container].
  ///
  /// ### Where to start
  /// You rarely need to read this directly. The receptor is set when you
  /// create a collection via the [Tissue] factories, and the framework
  /// invokes it automatically on every mutation.
  ///
  /// ### When to use
  /// Only if you are building a custom collection implementation that needs
  /// to inspect or replace the default mutation handler.
  ///
  /// ### How it works
  /// 1. **Local Definition**: First attempts to retrieve the `receptor`
  ///    stored in the current nucleus's record.
  /// 2. **Inheritance (Parent Link)**: If not found, it recursively "walks up"
  ///    the `principal` chain to find a handler from an ancestor.
  /// 3. **Default Fallback**: If the root is reached without finding a
  ///    custom receptor, it defaults to [TissueReceptor.passThrough].
  ///
  /// ### Non‑obvious
  /// - The receptor is **activated** when the nucleus is bound to a live
  ///   tissue – this is when it becomes aware of the specific collection
  ///   instance.
  /// - If you pass an already‑activated receptor to a new nucleus, the
  ///   framework automatically clones it to prevent state leakage.
  /// - For deputies, the receptor is typically inherited from the principal
  ///   unless explicitly overridden.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final receptor = list._nucleus.receptor;
  /// // receptor is the function that processes mutation pulses
  /// ```
  ///
  /// ### Returns:
  /// The resolved [TissueReceptor<E, C>] configured for this collection.
  @override
  TissueReceptor<E,C> get receptor {
    return get<TissueReceptor<E,C>>(() => record.mask.inheritable.receptor, fallback: () => principal?.receptor, orElse: TissueReceptor.passThrough);
  }

}

/// A terminal, immutable representation of empty tissue properties.
///
/// [TissueNucleusNever] serves as the "Null Object" or "bottom" type
/// within the [TissueNucleus] hierarchy. It implements the interface
/// for a tissue holding [Never], representing a configuration that
/// contains no data, permits no mutations, and occupies minimal memory.
///
/// ### Where to start
/// You never create this directly. The framework uses it internally
/// as the fallback for empty or uninitialised collections.
///
/// ### When to use
/// Only if you are building a custom collection implementation that needs
/// a no‑op nucleus placeholder. For standard use, the framework provides
/// this automatically.
///
/// ### How it works
/// - It extends [Nucleolus] to inherit the zero‑state property resolution.
/// - It returns a specialised [TissueContainer] that is permanently empty
///   and rejects all mutations.
/// - It uses [TestTissue.allowAll] and [TissueReceptor.passThrough] as
///   defaults, but since the type is [Never], no signals can actually be
///   posted to it.
///
/// ### Non‑obvious
/// - This is a `const` singleton – all empty tissue nuclei point to the
///   exact same instance, making it extremely memory‑efficient.
/// - Attempting to call mutation methods on a collection built from this
///   nucleus will either throw or be silently ignored (depending on the
///   implementation).
/// - It serves as the **root of the inheritance chain** for any nucleus
///   that has no explicit `principal`.
///
/// ### Example (Internal)
/// ```dart
/// final emptyNucleus = TissueNucleusNever();
/// final emptyList = Tissue.fromNucleus(emptyNucleus);
/// print(emptyList.length); // 0
/// // emptyList.add(1); // throws or silently fails
/// ```
///
/// Inherits from [Nucleolus] to ensure it is a fundamental, non‑reducible
/// part of the reactive property tree.
class TissueNucleusNever extends Nucleolus implements TissueNucleusBase<Never,Never, Never> {

  /// Creates a constant instance of [TissueNucleusNever].
  ///
  /// Using the `const` constructor ensures that all "empty" property
  /// references across the system point to the same memory location,
  /// optimizing identity checks and reducing GC pressure.
  const TissueNucleusNever();

  @override
  TissueNucleusBase<Never,Never,Never>? get principal => null;

  /// Returns the default pass-through receptor.
  ///
  /// For an empty tissue of type [Never], the receptor is effectively
  /// unreachable in a type-safe environment, but provides a valid
  /// implementation for the [TissueNucleus] interface.
  @override
  TissueReceptor<Never, Never> get receptor => TissueReceptor.passThrough;

  /// Returns the default permissive validation rule.
  ///
  /// Since no elements of type [Never] can exist, this rule will never
  /// technically be invoked for a valid element, but serves to satisfy
  /// the property contract.
  @override
  TestTissue<Never, Never> get testRule => TestTissue.allowAll;

  /// Provides a specialized, empty [TissueContainer].
  ///
  /// This getter constructs a container using the internal `_iterableNever`
  /// factory logic. The resulting container is:
  /// 1. **Immutable**: Any attempt to add or remove elements will result
  ///    in an operation consistent with an empty [Iterable].
  /// 2. **Typed to Never**: Ensures that the Dart type system recognizes
  ///    the collection cannot contain any values.
  ///
  /// Returns:
  ///   A [TissueContainer] backed by an empty, immutable storage engine.
  @override
  TissueContainer<Never, Never> get container => const _Container(
      create: Container._iterableNeverCreate,
      add: Container._iterableNeverAdd,
      remove: Container._iterableNeverRemove
  ).create<Never,Never>();

  @override
  TissueNucleusNever get clone => this;

  @override
  Container get containerType => Container.iterableNever;

}