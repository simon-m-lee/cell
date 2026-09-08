// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell_tissue.dart';

/// The strategic contract for a [Receptor] specialised for orchestrating
/// pulse evolution and state synchronisation within a [Tissue] context.
///
/// A [TissueReceptor] acts as the **Reactive Gateway** and **Input Logic Controller**
/// for a collection‑based cell (e.g., [TissueList], [TissueSet], [TissueMap]).
/// It sits at the intersection of incoming [Synapses] and the internal [TissueContainer],
/// serving as the arbiter that decides how external [Pulse]s – primarily [TissueEvent]s –
/// should modify the local state and how they should be projected downstream.
///
/// ### When to use
/// Use a custom [TissueReceptor] when you need to:
/// - Transform structural pulses before they are applied to the collection
///   (e.g., normalise or filter elements).
/// - Intercept mutations for logging, auditing, or side‑effects.
/// - Implement a specialised synchronisation strategy between a principal and
///   a deputy.
/// - Map collection events to different signal types (e.g., turn a list
///   addition into a domain event).
/// - Suppress certain pulses entirely (by returning `null`).
///
/// Most of the time, you don't need to define a custom receptor. The default
/// [TissueReceptor.passThrough] does exactly what you expect: it mirrors
/// structural changes from a principal into the local collection. Use it
/// whenever you're building a standard reactive list, set, map, or queue.
///
/// When you do need custom behaviour, start with the primary constructor:
/// ```dart
/// final receptor = TissueReceptor<String, TissueList<String>>(
///   (tissue, pulse, {user}) {
///     // your transformation logic here
///     return pulse;
///   },
/// );
/// ```
///
/// For more complex pipelines, use [TissueReceptor.from] to combine
/// pre‑process, core rule, and post‑process stages.
///
/// ### How it works
/// - A receptor is a functional wrapper around one or more [Instruction]s.
/// - When a pulse arrives (typically a [TissueEvent]), the receptor first
///   checks if the pulse originates from a bound principal (via [bind]).
///   If so, it automatically updates the local [TissueContainer] to mirror
///   the principal's state (this is the "synchronisation" phase).
/// - Then it applies the user‑provided transformation pipeline:
///   `preProcess` → `rule` → `postProcess`.
/// - If any stage returns `null`, the pulse is dropped and does not propagate.
/// - The final (possibly transformed) pulse is dispatched to downstream
///   observers via the tissue's [Synapses].
///
/// ### Non‑obvious
/// - **Auto‑synchronisation**: If the tissue is `bind`ed to a principal, the
///   receptor automatically syncs structural changes (adds, removes, updates)
///   from that principal into the local container, even before your custom
///   rule runs. This is the foundation of the **Deputy Pattern**.
/// - **Activation**: A receptor is a stateless template until it is activated
///   (bound to a tissue). Once activated, it holds a reference to that tissue
///   and cannot be safely reused on another one – use [clone] for that.
/// - **Pass‑through**: The `passThrough` constant is a singleton; it's the
///   default for all tissues, and it's extremely lightweight.
/// - **Async support**: All pipeline stages can be synchronous or asynchronous
///   (`FutureOr`). If any stage returns a `Future`, the propagation wave
///   suspends until it completes.
/// - **Cloning**: If you need the same logic on multiple tissues, call `clone`
///   on an activated receptor to get a fresh, unactivated copy.
/// - **Returning `null`** is the standard way to filter a pulse – it's not an
///   error path.
///
/// ### Example: Simple transformation
/// ```dart
/// final doubleReceptor = TissueReceptor<int, TissueList<int>>(
///   (tissue, pulse, {user}) {
///     final value = pulse.payload as int;
///     return Pulse(value * 2);
///   },
/// );
/// ```
///
/// ### Example: Validated pipeline with logging
/// ```dart
/// final validatedReceptor = TissueReceptor.from(
///   preProcess: Instruction((tissue, input, {user}) {
///     print("Incoming: $input");
///     return input;
///   }),
///   rule: Instruction((tissue, input, {user}) => Pulse(input.payload * 2)),
///   postProcess: Instruction((tissue, input, {user}) {
///     return (input.payload < 100) ? input : null;
///   }),
/// );
/// ```
///
/// ### Example: Suppressing pulses from a specific source
/// ```dart
/// final filterReceptor = TissueReceptor<String, TissueList<String>>(
///   (tissue, pulse, {user}) {
///     if (pulse.source is MyInternalCell) return null; // drop
///     return pulse;
///   },
/// );
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of elements managed by the associated [Tissue].
/// * [C]: The concrete type of the [Tissue] this receptor serves
///   (e.g., `TissueList<E>`), providing type‑safe access to the
///   collection's specific APIs.
///
/// See also:
/// - [Instruction] – the building block for transformation logic.
/// - [TissueReceptor.passThrough] – the default, no‑op receptor.
/// - [TissueReceptor.from] – for multi‑stage pipelines.
/// - [TissueReceptor.transform] – for strongly‑typed type conversions.
abstract interface class TissueReceptor<E, C extends Tissue<E>> implements Receptor<C> {

  /// The default, singleton implementation of [TissueReceptor] providing
  /// standardised pulse propagation and structural state synchronisation.
  ///
  /// In the `cell_tissue` ecosystem, [passThrough] serves as the **Standard
  /// Reactive Gateway**. It is the "Vanilla" implementation used by the
  /// framework whenever a [Tissue] needs to stay perfectly synchronised with
  /// an upstream source without applying custom transformations or filters.
  ///
  /// ### When to use
  /// This is the default for all tissues. You only need to specify it explicitly
  /// if you are building a custom tissue and want to be explicit, or if you
  /// are overriding a receptor in a deputy and want to preserve the pass‑through
  /// behaviour.
  ///
  /// ### How it works
  /// - It checks if the incoming pulse originates from the tissue's bound
  ///   principal (via [Cell.bind]).
  /// - If so, it applies the structural deltas (adds, removes, updates) to the
  ///   local [TissueContainer] – this is the "mirroring" phase.
  /// - Then it forwards the pulse unchanged to downstream observers.
  /// - If the pulse is from any other source, it simply relays it without
  ///   modifying the local state.
  ///
  /// ### Non‑obvious
  /// - This is a singleton; millions of tissues can share it without memory
  ///   overhead.
  /// - It is the foundation of the **Deputy Pattern**: a deputy with a pass‑
  ///   through receptor stays perfectly in sync with its principal.
  /// - It does **not** perform any validation – that is the job of the
  ///   [TestTissue] gatekeeper.
  static const passThrough = _PassThroughTissueReceptor();

  /// The primary factory constructor for creating a [TissueReceptor] with a
  /// single transformation rule.
  ///
  /// This is the most common way to define a custom receptor – it's simple,
  /// covers the majority of use cases, and is easy to read.
  ///
  /// ### When to use
  /// Use this when you need to transform, filter, or react to pulses arriving
  /// at a tissue. Most custom logic fits here.
  ///
  /// ### How it works
  /// - You provide a function that receives the tissue, the incoming pulse,
  ///   and optional `user` data.
  /// - The function can return a modified pulse (to propagate) or `null` (to
  ///   drop it).
  /// - The framework wraps this function into a [Instruction] internally.
  ///
  /// ### Non‑obvious
  /// - If the function throws an exception, the error is caught and logged,
  ///   and the receptor returns `null` (drops the pulse).
  /// - The receptor is stateless until activated (bound to a tissue).
  /// - The `user` parameter is a convenient way to pass configuration
  ///   (e.g., a multiplier, a threshold) without creating a custom class.
  ///
  /// ### Example
  /// ```dart
  /// final doubleReceptor = TissueReceptor<int, TissueList<int>>(
  ///   (tissue, pulse, {user}) {
  ///     final value = pulse.payload as int;
  ///     return Pulse(value * 2);
  ///   },
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [rule]: The transformation logic. Receives the tissue, the pulse, and
  ///   optional `user` data; returns a new pulse or `null` to drop it.
  /// - [user]: Optional arbitrary data passed to the rule function.
  factory TissueReceptor(Pulse? Function(C tissue, Pulse pulse, {dynamic user}) instruction) {
    return _TissueReceptor<C>(instruction: Instruction<C,Pulse,Pulse>((pulse, {C? cell, future, token, dynamic user}) {
      return instruction.call(cell!, pulse, user: user);
    }));
  }
  // factory TissueReceptor(FutureOr<Pulse?> Function(C tissue, Pulse pulse, {dynamic user}) rule, {dynamic user}) {
  //   return _TissueReceptor<E,C>(instruction: Instruction<C,Pulse,Pulse>((cell, pulse, {dynamic user}) => rule(cell, pulse, user: user), user: user));
  // }

  /// The advanced compositional factory for creating a [TissueReceptor] with
  /// a multi‑stage processing pipeline.
  ///
  /// ### When to use
  /// Use this when you need to separate concerns: e.g., logging before
  /// transformation, then post‑validation. It's a three‑stage pipeline:
  /// `preProcess` → `rule` → `postProcess`.
  ///
  /// ### How it works
  /// - You provide up to three [Instruction]s:
  ///   - `preProcess`: runs first (e.g., for sanitisation or logging).
  ///   - `rule`: the core transformation logic.
  ///   - `postProcess`: runs last (e.g., for validation or commitment).
  /// - If any stage returns `null`, the pipeline stops and no further stages
  ///   run.
  /// - The stages are executed sequentially; the output of one becomes the
  ///   input of the next.
  ///
  /// ### Non‑obvious
  /// - The stages are optional – you can provide only the ones you need.
  /// - This is the recommended way to separate validation from business logic.
  /// - For `ValueCell` tissues, the `postProcess` stage is often used to
  ///   commit the new value to the underlying [Box].
  ///
  /// ### Example: Validated Pipeline
  /// ```dart
  /// final validatedReceptor = TissueReceptor.from(
  ///   preProcess: Instruction((tissue, input, {user}) {
  ///     print("Incoming: $input");
  ///     return input;
  ///   }),
  ///   rule: Instruction((tissue, input, {user}) => Pulse(input.payload * 2)),
  ///   postProcess: Instruction((tissue, input, {user}) {
  ///     return (input.payload < 100) ? input : null;
  ///   }),
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [rule]: The central [Instruction] defining the main transformation logic.
  /// - [preProcess]: Optional [Instruction] executed before the main logic.
  /// - [postProcess]: Optional [Instruction] executed after the main logic.
  factory TissueReceptor.from({Instruction? instruction, Instruction? preProcess, Instruction? postProcess})
  = _TissueReceptor<E,C>;

  /// A static convenience factory that creates a type‑safe [TissueReceptor]
  /// specialised for transforming signals from one specific type to another.
  ///
  /// ### When to use
  /// Use this when you have a strongly‑typed transformation that maps one
  /// pulse type to another (e.g., `TissueEvent<String>` to `Pulse<int>`).
  /// It's more explicit and type‑safe than the generic constructor.
  ///
  /// ### How it works
  /// - You provide a [Instruction] that is typed with the exact input and output
  ///   types.
  /// - The receptor will only accept pulses of type [I] and will produce
  ///   pulses of type [O].
  ///
  /// ### Non‑obvious
  /// - This is just a convenience wrapper around the primary constructor.
  /// - It provides better static analysis and code completion.
  ///
  /// ### Example
  /// ```dart
  /// final lengthReceptor = TissueReceptor.transform<MyTissue, TissueEvent<String>, Pulse<int>>(
  ///   Instruction((tissue, input, {user}) {
  ///     final text = input.payload;
  ///     return text != null ? Pulse(text.length) : null;
  ///   })
  /// );
  /// ```
  ///
  /// ### Type Parameters:
  /// - [E]: The element type of the tissue.
  /// - [C]: The concrete tissue type.
  /// - [I]: The expected type of the incoming [Pulse].
  /// - [O]: The type of the [Pulse] resulting from the transformation.
  static TissueReceptor<E,C> transform<E,C extends Tissue<E>,O extends Pulse>(
      FutureOr<O?> Function(C tissue, TissueEvent pulse, {dynamic user}) rule, {
        dynamic user
      }) {
    return _TissueReceptor<E,C>(instruction: Instruction<C,TissueEvent,O>(rule));
  }

  /// Returns a shallow, immutable copy of this [TissueReceptor],
  /// preserving its strategic logic while allowing for independent lifecycle
  /// management.
  ///
  /// ### When to use
  /// You rarely need this – the framework uses it internally when you create
  /// a tissue from an already‑activated nucleus. Use it if you need to reuse
  /// the same logic on multiple tissues.
  ///
  /// ### How it works
  /// - The clone copies the rules and metadata but clears any cell binding.
  /// - The clone is in the template state ([isActivated] is `false`).
  ///
  /// ### Non‑obvious
  /// - The clone is a new object, so activating it won't affect the original.
  /// - This is essential for sharing a receptor definition across many tissues
  ///   without cross‑contamination.
  ///
  /// ### Returns:
  /// A new [TissueReceptor<E, C>] instance that is functionally
  /// equivalent to this receptor.
  @override
  TissueReceptor<E,C> get clone;

  /// Returns an asynchronous execution adapter for this receptor.
  ///
  /// ### When to use
  /// Use this when you need to process a pulse asynchronously – e.g., from
  /// an async event handler or when you want to wait for the entire
  /// downstream propagation to complete.
  ///
  /// ### How it works
  /// - The `async` getter returns a [ReceptorAsync] that wraps the synchronous
  ///   logic in a `Future`.
  /// - You can call it with `await` and optionally specify
  ///   `serializedCompletion` to wait for full propagation.
  ///
  /// ### Example
  /// ```dart
  /// await receptor.async.call(pulse, serializedCompletion: true);
  /// ```
  ///
  /// ### Returns:
  /// A [ReceptorAsync] instance for non‑blocking execution.
  @override
  ReceptorAsync<C> get async;

}