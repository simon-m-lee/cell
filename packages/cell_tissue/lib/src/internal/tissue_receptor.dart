// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

/// The singleton pass‑through receptor for tissues.
///
/// This is the default receptor used when no custom transformation is needed.
/// It simply forwards pulses unchanged. It is a `const` singleton, so all
/// tissues that use pass‑through share the same instance.
///
/// ### When to use
/// This is used internally as the default receptor for all tissues. You don't
/// need to instantiate it – use [TissueReceptor.passThrough] instead.
///
/// ### How it works
/// - It implements the [TissueReceptor] interface.
/// - The `call` method returns the input pulse unchanged.
/// - It is a singleton – all tissues share the same instance.
/// - It cannot be activated – `activate` returns `false`.
///
/// ### Non‑obvious
/// - This is a `const` singleton, making it extremely memory‑efficient.
/// - It is the foundation of the **Deputy Pattern** – a deputy with a
///   pass‑through receptor stays perfectly in sync with its principal.
class _PassThroughTissueReceptor implements TissueReceptor<Never,Never> {

  const _PassThroughTissueReceptor();

  @override
  Never get cell => throw UnsupportedError('Inactivated receptor');

  @override
  bool activate(Never cell) => false;

  @override
  ReceptorAsync<Never> get async => throw UnsupportedError('Inactivated receptor');

  @override
  bool get isActivated => true;

  @override
  TissueReceptor<Never,Never> get clone => this;

  @override
  FutureOr<PulseBase<dynamic>?> call(covariant PulseBase<dynamic> pulse) {
    return pulse;
  }

  @override
  bool get isGoverned => false;

}

/// Internal implementation of [TissueReceptor] for generic tissues.
///
/// [_TissueReceptor] is the concrete receptor that powers `_Tissue` and its
/// subclasses. It extends [TissueReceptorBase] and provides the specific
/// logic for cloning.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly – use the
/// factories on [TissueReceptor] instead.
///
/// ### How it works
/// - It extends [TissueReceptorBase] and provides the concrete implementation.
/// - The `clone` getter creates a fresh copy with its own state.
/// - The constructor stores the pipeline instructions in a memory‑optimised
///   record using bitmasking.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue type.
class _TissueReceptor<E, C extends Tissue<E>> extends TissueReceptorBase<E,C> {

  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  _TissueReceptor({
    Instruction? instruction,
    Instruction? preProcess,
    Instruction? postProcess,
    Pulse? Function(Pulse pulse, C host, {dynamic user})? reaction,
    void Function()? init,
    dynamic Function()? user,
    bool isGoverned = false,
  }) : this.fromRecord(record: ReceptorBase.mask(
      instruction: instruction, preProcess: preProcess, postProcess: postProcess,
      reaction: reaction, user: user, init: init, isGoverned: isGoverned
  ));

  _TissueReceptor.fromRecord({super.record}) :_record = record, super.fromRecord();

  /// Creates an independent, decoupled clone of this receptor.
  ///
  /// ### When to use
  /// This is used internally when creating a new tissue from a template receptor.
  ///
  /// ### How it works
  /// - The clone retains the same [instruction], [preProcess], [postProcess],
  ///   and [user] metadata.
  /// - The clone is initially **inactive** – it must be activated by being
  ///   bound to a tissue instance.
  ///
  /// ### Returns:
  /// A new [TissueReceptor] instance with identical behavioural logic.
  @override
  TissueReceptor<E,C> get clone => _TissueReceptor.fromRecord(record: _record);

}

/// The foundational pulse‑processing engine for all reactive collections.
///
/// [TissueReceptorBase] is the specialised receptor that powers every [Tissue].
/// It extends the generic [ReceptorBase] to add collection‑aware logic:
/// automatic state synchronisation with a bound principal, and the ability to
/// process structural events like additions and removals.
///
/// ### When to use
/// Only if you are building a custom collection type that needs to override
/// the default mutation handling. For standard use, the provided receptors
/// are sufficient.
///
/// You never implement this class directly. The framework provides concrete
/// receptors via the [TissueReceptor] factory and the `passThrough` constant.
/// Your interaction with receptors is typically through the `receptor` parameter
/// when creating a tissue, or via the `async` getter for asynchronous processing.
///
/// ### How it works
/// - It extends [ReceptorBase] to inherit the multi‑stage pipeline
///   (`preProcess` → `rule` → `postProcess`) and error handling.
/// - It adds a crucial **implicit synchronisation** step: when a pulse arrives
///   from a bound principal (the `bind` source), it automatically applies
///   structural deltas (adds, removes, updates) to the local tissue's
///   [TissueContainer] before any user‑defined rules run.
/// - This synchronisation is what makes the **Deputy Pattern** work – a deputy
///   tissue stays perfectly in sync with its principal without any extra code.
/// - The receptor then passes the (possibly transformed) pulse to the
///   standard pipeline for user‑defined processing.
/// - It handles both synchronous and asynchronous pulses seamlessly.
///
/// ### Non‑obvious
/// - The implicit synchronisation only happens for pulses that **originate
///   from the bind source**. Pulses from other sources are processed normally
///   but do not trigger automatic mirroring.
/// - If the synchronisation cannot be fully applied (e.g., due to validation
///   failure or capacity constraints), the receptor may produce a **partial
///   pulse** that reflects only the changes that were actually committed.
/// - The receptor is **activated** when bound to a tissue – this sets the
///   `cell` getter and marks `isActivated` as `true`.
/// - The `clone` method creates a shallow copy for reuse across multiple tissues.
/// - The `call` method uses the pulse's `_checker` to prevent cycles.
///
/// ### Example (Internal – how the framework uses it)
/// ```dart
/// final receptor = TissueReceptorBase<int, TissueList<int>>(
///   rule: Instruction((tissue, pulse, {user}) {
///     // Custom transformation logic
///     return pulse;
///   }),
/// );
/// final list = TissueList<int>(receptor: receptor);
/// ```
///
/// ### Type Parameters:
/// - [E]: The type of elements contained in the associated [Tissue].
/// - [C]: The specific [Tissue] implementation type (e.g., `TissueList<E>`),
///   allowing for type‑safe pulse processing within the hierarchy.
abstract class TissueReceptorBase<E, C extends Tissue<E>>
    extends ReceptorBase<C> with _TissueReceptorBaseStack implements TissueReceptor<E,C> {

  /// **Primary Constructor** – defines the transformation pipeline for a
  /// reactive collection.
  ///
  /// ### When to use
  /// **Internal framework use only.** This constructor is `public` only so
  /// that concrete subclasses (like `_TissueReceptor`) can invoke it via
  /// `super()`. **Application code should never call this directly.**
  ///
  /// If you need a receptor, use [TissueReceptor] (for a single‑rule receptor)
  /// or [TissueReceptor.from] (for a multi‑stage pipeline). For the default
  /// behaviour, simply omit the `receptor` parameter when creating a tissue.
  ///
  /// You are writing a custom tissue implementation that needs to override
  /// the default receptor behaviour.
  ///
  /// ### How it works
  /// 1. The [rule], [preProcess], and [postProcess] parameters define the
  ///    multi‑stage pipeline:
  ///    - `preProcess`: runs first (e.g., sanitization, logging).
  ///    - `rule`: the core transformation logic.
  ///    - `postProcess`: runs last (e.g., validation, commitment).
  /// 2. The [reaction] parameter is a simplified functional form – if provided,
  ///    it is wrapped into a [Instruction] internally.
  /// 3. The [isGoverned] flag indicates whether the receptor is governed by
  ///    a security context (used internally).
  /// 4. The pipeline is stored in a memory‑optimised record using bitmasking.
  ///
  /// ### Non‑obvious
  /// - The [receptor] is automatically cloned if it is already activated
  ///   (bound to another cell), ensuring that each nucleus starts with a
  ///   clean logic instance.
  /// - If [rule] is `null`, the receptor behaves like `passThrough` for that stage.
  /// - The [user] parameter is passed to the rule functions and can be used
  ///   for configuration, but it's not part of the pulse's context.
  ///
  /// ### Parameters:
  /// - [rule]: The primary [Instruction] defining the core transformation logic.
  /// - [preProcess]: Optional [Instruction] for early‑stage filtering or logging.
  /// - [postProcess]: Optional [Instruction] for late‑stage commitment.
  /// - [reaction]: A simplified functional alternative to [rule].
  /// - [user]: Optional metadata passed to the rule functions.
  /// - [isGoverned]: Internal flag indicating governance context.
  TissueReceptorBase({super.instruction, super.preProcess, super.postProcess, super.reaction, super.user, super.isGoverned}) : super();

  /// **Low‑level Record Constructor** – instantiates a receptor from a
  /// pre‑packed property record.
  ///
  /// ### When to use
  /// **Strictly internal framework use only.** This constructor bypasses
  /// all parameter validation and default‑value logic. It is designed for
  /// performance‑critical paths like cloning and state restoration.
  /// **Application code must never call this.**
  ///
  /// - When implementing `clone` in a custom receptor subclass.
  /// - When restoring a receptor from a serialised state where the record
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
  /// - The record must contain all necessary fields for a receptor,
  ///   including the `rule`, `preProcess`, `postProcess`, and `user` metadata.
  /// - If the record is malformed, the resulting receptor may behave
  ///   unpredictably – use with extreme caution.
  /// - This constructor is `const`‑friendly, enabling compile‑time
  ///   instantiation of static receptors.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final record = (rule: myRule, preProcess: myPre, user: null);
  /// final receptor = TissueReceptorBase.fromRecord(record: record);
  /// ```
  ///
  /// ### Parameters:
  /// - [record]: The internal property record – an implementation‑specific
  ///   Dart `Record` containing all receptor fields.
  TissueReceptorBase.fromRecord({super.record}) : super.fromRecord();

  /// The logic gatekeeper and pulse processing engine for the associated [Tissue].
  ///
  /// This method is the entry point for every pulse arriving at the tissue.
  /// It first performs **implicit synchronisation** if the pulse originates
  /// from a bound principal, then passes the (possibly modified) pulse to the
  /// standard receptor pipeline (`preProcess` → `rule` → `postProcess`).
  ///
  /// ### When to use
  /// You never call this directly – the framework invokes it when a pulse
  /// arrives at a tissue. Use it for testing or manual invocation if needed.
  ///
  /// - Testing a custom receptor.
  /// - Manually injecting a pulse for debugging.
  ///
  /// ### How it works
  /// 1. **Activation Check**: If the receptor is not activated (bound to a
  ///    tissue), it returns `null` – no processing occurs.
  /// 2. **Tissue‑Aware Processing**: If the pulse is a [TissueEvent] (a
  ///    structural event like addition or removal), it passes the event to
  ///    the internal `_tissueStack` method.
  /// 3. **Implicit Synchronisation**: `_tissueStack` checks if the pulse
  ///    originates from the tissue's `bind` (principal). If so, it applies
  ///    the structural deltas to the local [TissueContainer] – this is the
  ///    mirroring that keeps deputies in sync.
  /// 4. **User Pipeline**: The result (or the original pulse) is then passed
  ///    to `super.call()`, which executes the `preProcess` → `rule` →
  ///    `postProcess` pipeline.
  /// 5. **Return**: The final pulse is returned (or `null` if filtered).
  ///
  /// ### Non‑obvious
  /// - The implicit synchronisation only happens for pulses from the `bind`
  ///   source. Pulses from other sources are not mirrored.
  /// - If the synchronisation is partial (e.g., some elements failed
  ///   validation), the resulting pulse reflects only the committed changes.
  /// - The pipeline is wrapped in error boundaries; exceptions are caught
  ///   and reported via the pulse's `onError` callback.
  /// - The method returns `FutureOr` – it can be synchronous or asynchronous
  ///   depending on the rules.
  ///
  /// ### Example (Manual invocation)
  /// ```dart
  /// final receptor = TissueReceptor.passThrough;
  /// final result = await receptor.call(Pulse('test'));
  /// ```
  ///
  /// ### Parameters:
  /// - [pulse]: The incoming pulse to process.
  ///
  /// ### Returns:
  /// The transformed pulse, or `null` if the pulse was filtered or rejected.
  @override
  FutureOr<PulseBase?> call(covariant PulseBase pulse) {
    if (isActivated) {
      PulseBase? out = pulse;

      if (pulse is TissueEventBase) {
        out = _tissueStack<E>(tissue: cell, event: pulse) ?? pulse;
      }

      return super.call(out) as FutureOr<PulseBase?>;
    }
    return null;
  }

}

/// Internal engine that automatically synchronises a deputy tissue with its
/// principal by mirroring structural deltas (additions, removals, updates).
///
/// ### When to use
/// You don't. This is a framework‑internal detail. But understanding it builds
/// trust that deputies stay in perfect sync without you writing any extra code.
///
/// You never interact with this mixin directly. It is used internally by
/// [TissueReceptorBase] to implement the deputy pattern. The framework invokes
/// it automatically whenever a pulse arrives from a bound principal.
///
/// ### How it works
/// 1. When a [TissueEvent] arrives, the mixin checks whether the event's
///    `source` is the local tissue itself. If yes, the event originated here –
///    no synchronisation is needed, and the event is passed through unchanged.
/// 2. If the event came from a different source (typically the `bind`
///    principal), the mixin applies the structural deltas to the local
///    [TissueContainer]:
///    - [ElementAddedEvent] → adds the element(s) to the local container.
///    - [ElementRemovedEvent] → removes the element(s) from the local container.
///    - [ValueChangedEvent] → updates the value in the local container.
/// 3. The mixin recursively flattens [CollectiveTissueEvent]s and follows
///    [EvolvedTissueEvent] chains, processing every nested event.
/// 4. If some operations fail (e.g., due to validation rules or capacity
///    limits on the deputy), it tracks a `partial` flag and returns a new
///    event that reflects **only** the successfully applied changes.
///
/// ### Non‑obvious
/// - **Idempotent**: Applying the same event multiple times does not cause
///   duplicates – the container checks for existing elements before adding.
/// - **Unmodifiable projection**: If the local tissue is unmodifiable, the
///   incoming event is automatically projected as unmodifiable before
///   processing – this ensures deep immutability for read‑only deputies.
/// - **No pulse emission**: This mixin modifies the container but does **not**
///   emit new pulses. It only syncs state. The original event (or a partial
///   representation) is then passed to the user's pipeline for further
///   processing.
/// - **Partial sync**: If a validation rule on the deputy rejects some
///   elements, only the accepted subset is applied. The returned event
///   contains only the changes that were actually committed, so downstream
///   observers see a truthful representation of what changed.
///
/// ### Example (internal flow)
/// ```dart
/// // The principal emits an event
/// final principalEvent = ElementAddedEvent<int>(payload: 42);
///
/// // The deputy's receptor receives it and calls the sync engine
/// final syncResult = _tissueStack(tissue: deputy, event: principalEvent);
///
/// // syncResult now reflects what was actually applied to the deputy
/// // (it might be the same event, a subset, or null if nothing changed).
/// ```
mixin _TissueReceptorBaseStack {

  /// Processes an incoming structural event and applies its deltas to the
  /// local tissue's container.
  ///
  /// This method is the core of the synchronisation engine – it's what keeps
  /// a deputy faithfully mirroring its principal.
  ///
  /// ### When to use
  /// Called internally by [TissueReceptorBase.call] whenever a pulse arrives.
  /// You never call it directly.
  ///
  /// ### How it works
  /// - It first checks if the event originated from the same tissue. If so, it
  ///   returns the event (or its unmodifiable projection) without applying any
  ///   changes – this prevents infinite loops.
  /// - Otherwise, it iterates through the event's structure. For collectives,
  ///   it flattens them; for evolved chains, it follows the parent links to
  ///   reach the actual delta event.
  /// - For each delta (`ElementAdded`, `ElementRemoved`, `ValueChanged`), it
  ///   attempts to apply it to the container using `container.add` or
  ///   `container.remove`.
  /// - If any operation fails (e.g., the element already exists, or validation
  ///   rejects it), it sets the `partial` flag.
  /// - Finally, it returns:
  ///   - The original event if all deltas were applied successfully.
  ///   - A new batch containing only the successfully applied events if
  ///     the sync was partial.
  ///   - The original event (or unmodifiable projection) if the event
  ///     originated locally.
  ///
  /// ### Parameters:
  /// - [tissue]: The local tissue that is synchronising (typically a deputy).
  /// - [event]: The incoming structural event from the principal.
  ///
  /// ### Returns:
  /// A [TissueEventBase] representing the changes that were actually applied
  /// to the local container, or `null` if no changes were applied.
  ///
  /// ### Example (internal)
  /// ```dart
  /// // A deputy receives a batch of changes from its principal
  /// final batch = CollectiveTissueEvent.from([add1, add2, remove1]);
  /// final result = _tissueStack(tissue: deputy, event: batch);
  /// // If add2 fails validation, result will be a partial batch containing
  /// // only add1 and remove1.
  /// ```
  TissueEventBase? _tissueStack<E>({required covariant Tissue tissue, required covariant TissueEventBase event}) {

    TissueEventBase? out;

    out = tissue is Unmodifiable ? event.unmodifiable : event;

    if (!identical(event.source, tissue)) {
      List<TissueEvent<E>>? events;

      final container = tissue._nucleus.container;
      bool partial = false;

      void process(TissueEvent event) {
        final payload = event.payload;

        if (event is ElementAddedEvent<E>) {
          if (payload != null) {
            if (container.add(tissue, payload)) {
              (events ??= <TissueEvent<E>>[]).add(event);
            } else {
              partial = true;
            }
          }
        }

        else if (event is ElementRemovedEvent<E>) {
          if (payload != null) {
            if (container.remove(tissue, payload)) {
              (events ??= <TissueEvent<E>>[]).add(event);
            } else {
              partial = true;
            }
          }
        }

        else if (event is ValueChangedEvent) {
          if (payload is ValueChangedRecord) {
            final e = payload.value;
            if (container.contains(payload.value)) {
              (events ??= <TissueEvent<E>>[]).add(event as TissueEvent<E>);
            } else {
              if (container.add(tissue, e)) {
                (events ??= <TissueEvent<E>>[]).add(ElementAddedEvent<E>._(payload: e as E));
              } else {
                partial = true;
              }
            }
          }
        }

      }

      void processType(TissueEvent event) {
        if (event is CollectiveTissueEvent) {
          for (final TissueEvent e in event.payload) {
            processType(e);
          }
        } else if (event is EvolvedTissueEvent) {
          final e = event.last;
          if (e is TissueEvent) {
            processType(e);
          }
        } else {
          process(event);
        }
      }

      processType(event);

      if (partial) {
        if (events!.length == 1) {
          return events!.first as TissueEventBase;
        }
        return TissueEvent.batch<E>(events!) as TissueEventBase<E>;
      }
      return event;
    }

    return out;
  }

}