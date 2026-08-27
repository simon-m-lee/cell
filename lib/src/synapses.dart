// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell.dart';

/// A filter that can transform, redact, or suppress a [Pulse] before it is
/// broadcast to downstream observers.
///
/// [FilterRule] sits at the egress point of a cell's [Synapses]. It acts as a
/// middleware gateway, letting you modify or drop outgoing signals based on
/// their content or metadata. Filters are composable using the `+` operator,
/// creating sequential pipelines.
///
/// ### When to use
/// Use this when you need to sanitize, redact, or filter pulses before they
/// reach observers – e.g., removing PII, enforcing format constraints, or
/// conditionally suppressing events.
///
/// ### How it works
/// You provide a function that receives the outgoing pulse and can return a
/// new pulse (to continue propagation) or `null` (to drop it). The filter is
/// stateless and reusable across multiple synapses.
///
/// ### Non‑obvious
/// - If a filter throws an exception, the framework catches it and preserves
///   the original pulse – a single faulty filter doesn't break the chain.
/// - Filters are composed using `+`; the output of one becomes the input of
///   the next. If any filter returns `null`, the pipeline short‑circuits and
///   the pulse is dropped.
/// - The [FilterRule.base()] constructor creates a no‑op filter that acts as
///   an identity element for composition.
///
/// ### Example: redacting sensitive data
/// ```dart
/// final redactFilter = FilterRule<UserData>((pulse, {user}) {
///   final data = pulse.payload;
///   return Pulse(data.copyWith(email: '***', phone: '***'));
/// });
/// ```
///
/// ### Example: filtering out negative values
/// ```dart
/// final positiveFilter = FilterRule<int>((pulse, {user}) {
///   return pulse.payload > 0 ? pulse : null;
/// });
/// ```
///
/// See also: [Synapses], [FilterRule.chain] (for building multi‑stage pipelines).
///
/// {@category Signals & Synapses}
class FilterRule<P extends Pulse> {

  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  Function? get _rule {
    return get<Function?>(() => _record.rule, orElse: null);
  }

  FilterRule<P>? get _parent => get<FilterRule<P>?>(() => _record._parent, orElse: null);

  dynamic get _user => get<dynamic>(() => _record.user, orElse: null);

  /// The collection of rules managed by this object.
  Iterable<FilterRule<P>> get _rules =>
      get<Iterable<FilterRule<P>>>(
              () => _record.rules, orElse: const Iterable.empty());

  /// Creates a single filter rule from a transformation function.
  ///
  /// ### When to use
  /// This is the primary way to define a filter – you provide a function that
  /// receives the pulse and returns either a new pulse or `null`.
  ///
  /// ### Parameters:
  /// - [rule]: The transformation logic. Receives the pulse and optional
  ///   [user] metadata; returns a [Pulse] to continue or `null` to drop.
  /// - [parent]: An optional filter to be applied after this one, enabling
  ///   chaining (but using `+` is usually more readable).
  /// - [user]: Optional metadata passed to the [rule] function.
  ///
  /// ### Example: filter with configuration
  /// ```dart
  /// final thresholdFilter = FilterRule<int>((pulse, {user}) {
  ///   final limit = user as int? ?? 100;
  ///   return pulse.payload > limit ? pulse : null;
  /// }, user: 50);
  /// ```
  const FilterRule(P? Function(P pulse, {dynamic user}) rule, {
    FilterRule<P>? parent, dynamic user
  }) : _record = parent != null ? user != null
      ? (rule: rule, parent: parent, user: user) : (rule: rule, parent: parent) : (rule: rule);

  /// Creates a composite filter pipeline from a collection of rules.
  ///
  /// ### When to use
  /// Use this when you need to apply multiple filters in sequence – it's an
  /// alternative to chaining with `+`. You can optionally provide a custom
  /// [strategy] to control execution order or branching.
  ///
  /// ### How it works
  /// By default, the rules are executed in order. The output of one becomes
  /// the input of the next. If any returns `null`, the pipeline stops.
  ///
  /// ### Example: security pipeline
  /// ```dart
  /// final securityPipeline = FilterRule.chain([
  ///   piiRedactionFilter,
  ///   encryptionFilter,
  ///   auditLogFilter,
  /// ]);
  /// ```
  ///
  /// ### Parameters:
  /// - [rules]: The collection of [FilterRule] instances to be managed.
  /// - [parent]: An optional filter to be evaluated after this chain
  ///   completes, continuing the chain of responsibility.
  /// - [user]: Optional metadata passed to the [strategy].
  /// - [strategy]: An optional transformation function that overrides the
  ///   default sequential execution of the [rules] collection.
  const FilterRule.chain(Iterable<FilterRule<P>> rules, {
    FilterRule<P>? parent, dynamic user,
    bool Function(P pulse, {dynamic user})? strategy
  }) : _record = strategy != null ? parent != null ? user != null
      ? (rule: strategy, parent: parent, user: user) : (rule: strategy, parent: parent) : (rule: strategy)
      : parent != null ? (rules: rules, parent: parent) : (rules: rules);

  /// Reconstitutes a [FilterRule] from a raw flyweight record.
  ///
  /// This is an internal constructor used by the framework for performance
  /// optimization. You don't need to call it directly.
  const FilterRule.fromRecord(Record record) : _record = record;

  /// Creates a no‑op filter that does nothing – it passes pulses through unchanged.
  ///
  /// ### When to use
  /// This is useful as a starting point for building pipelines with `+`.
  /// It acts as an identity element.
  ///
  /// ### Example
  /// ```dart
  /// final base = FilterRule.base();
  /// final pipeline = base + redactFilter + formatFilter;
  /// ```
  const FilterRule.base() : _record = ();

  /// Executes the filter chain on a [Pulse].
  ///
  /// ### When to use
  /// You typically don't call this directly – the framework does it when
  /// broadcasting pulses. Use it for testing or manual invocation.
  ///
  /// ### Returns:
  /// The transformed pulse, or `null` if the pulse was filtered out.
  P? call(P pulse) {

    P? out;
    out = pulse;
    try {
      final rule = _rule;
      if (rule != null) {
        out = rule.call(out, user: _user);
      } else {
        for (final rule in _rules) {
          try {
            out = rule.call(out!);
            if (out == null) {
              break;
            }
          } catch (_) {
            // Ignore exceptions from individual rules and continue.
          }
        }
      }
    } catch(_) {}

    if (out != null) {
      final parent = _parent;
      if (parent != null) {
        out = parent.call(out);
      }
    }
    return out;
  }

  /// Composes two filters into a sequential pipeline.
  ///
  /// ### When to use
  /// This is the idiomatic way to chain filters – it's clean and readable.
  ///
  /// ### How it works
  /// The current filter runs first, then the [other] filter. If the current
  /// returns `null`, the pipeline stops and `other` is not executed.
  ///
  /// ### Example
  /// ```dart
  /// final pipeline = redactFilter + sanitizeFilter + formatFilter;
  /// ```
  FilterRule<P> operator +(covariant FilterRule<P> other) {
    return FilterRule<P>.chain([this, other]);
  }

  @override
  int get hashCode => _record.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FilterRule) return false;
    return _record == other._record;
  }

}

/// The distribution fabric for a [Cell]'s outgoing signals—defining how,
/// when, and to whom a pulse is delivered.
///
/// ### When to use:
/// - **Broadcasting**: The primary mechanism for managing a cell's
///   downstream observers and dependencies.
/// - **Egress Filtering**: When you need to transform or redact pulses
///   *before* they leave the cell boundary (e.g., PII masking for UI views).
/// - **Flow Control**: When you need to apply temporal governance (like
///   debouncing or batching) to the delivery of signals at the source.
///
/// ### How it works:
/// Synapses maintain an adjacency list of downstream [Cell] nodes. When
/// the host cell emits a pulse, the synapses intercept it, apply any
/// configured [FilterRule], and then broadcast it across the network
/// according to the timing rules defined in the [PropagationPolicy].
///
/// ### Non‑obvious:
/// - **Cycle Safety**: The fabric automatically prevents infinite loops
///   by tracking the forensic history of every pulse. If a pulse detects
///   it is returning to a cell it has already visited, propagation for
///   that branch is silently terminated.
/// - **Flyweight Optimization**: Predefined constants like
///   [Synapses.enabled] and [Synapses.disabled] allow the framework to
///   avoid allocating registry memory for sink nodes or inactive cells.
/// - **Forensic Tagging**: All signals passing through the fabric are
///   implicitly tagged with egress metadata, allowing for complete audit
///   trails of how data flowed between specific cell boundaries.
///
/// ### Example: simple distribution
/// ```dart
/// final synapses = Synapses<String, Cell>(
///   downstreams: [logger, analytics, uiUpdater],
/// );
/// ```
/// ### See Also:
/// - [FilterRule]: For logic used to intercept or transform pulses at the
///   egress point.
/// - [PropagationPolicy]: For defining temporal governance strategies.
/// - **HowTo**: See `guide/HowTo-Synapses.md` for best practices on
///   configuring signal distribution and flow control.
///
/// {@category Signals & Synapses}
abstract interface class Synapses<P extends Pulse, L extends Cell> implements Iterable<L> {

  /// A predefined, singleton constant representing a completely disabled
  /// synapse network.
  ///
  /// ### When to use
  /// Use this for cells that should never broadcast – e.g., terminal nodes
  /// like observers that only consume signals.
  ///
  /// ### How it works
  /// Any call to `call()` is a no‑op; `link()` and `unlink()` return `false`.
  /// It's a singleton, so millions of cells can share it without memory
  /// overhead.
  ///
  /// ### Example
  /// ```dart
  /// final terminalCell = Cell(
  ///   synapses: Synapses.disabled,
  ///   receptor: Receptor((cell, pulse, {user}) => pulse),
  /// );
  /// ```
  static const disabled = _SynapsesDisabled();

  /// A predefined, singleton constant representing a completely enabled
  /// and active synapse network.
  ///
  /// ### When to use
  /// This is the default for most cells – it allows broadcasting to observers.
  /// You rarely need to specify it explicitly.
  ///
  /// ### How it works
  /// The constant is a flyweight placeholder that signals the framework to
  /// allocate a fresh, empty registry when the cell is activated. It's not
  /// the actual registry – that's created per cell.
  static const enabled = _SynapsesEnabled();

  /// Synthesizes a new signal distribution network with optional initial
  /// observers, a filter, and a propagation policy.
  ///
  /// ### When to use
  /// Use this when you need to customize the egress behavior of a cell –
  /// e.g., to set initial observers, apply a filter, or change propagation
  /// timing.
  ///
  /// ### How it works
  /// You provide optional [downstreams] (initial observers), a [filter] to
  /// transform or drop pulses, and a [policy] to control timing (debounce,
  /// throttle, batch, etc.). You can also supply a custom [relay] to take
  /// full control of distribution.
  ///
  /// ### Non‑obvious
  /// - If you provide a [relay], the default sequential broadcast is bypassed
  ///   – you must manually deliver pulses to downstream cells.
  /// - The [filter] is applied to every outgoing pulse before any observer
  ///   receives it.
  ///
  /// ### Example: with debouncing
  /// ```dart
  /// final debouncedSynapses = Synapses<String, Cell>(
  ///   downstreams: [searchHandler],
  ///   policy: PropagationPolicy(
  ///     strategy: PropagationStrategy.debounced,
  ///     debounceTime: Duration(milliseconds: 300),
  ///   ),
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// * [policy]: The [PropagationPolicy] defining temporal governance (e.g.,
  ///   throttling or batching).
  /// * [downstreams]: **Downstream Adjacency List.** An optional collection
  ///   of [Cell] nodes to be directly linked as observers during initialization.
  /// * [filter]: **Broadcast Transformation Logic.** An optional [FilterRule]
  ///   used to refine, modify, or suppress outbound signals.
  /// * [relay]: An optional override for the internal broadcast logic,
  ///   providing manual control over the signal distribution flow.
  ///
  /// ### Returns:
  /// A functional [Synapses] instance ready to manage and propagate
  /// reactive signals within a collection.
  factory Synapses({
    PropagationPolicy? policy,
    Iterable<L>? downstreams,
    FilterRule<P>? filter,
    void Function(P pulse)? relay,
  }) = _Synapses<P,L>;

  /// Synchronously orchestrates the atomic propagation wave for the
  /// provided [pulse] across all registered downstream observers.
  ///
  /// ### When to use
  /// You don't call this directly – the framework invokes it when a cell's
  /// state changes. You might use it for manual testing.
  ///
  /// ### How it works
  /// It applies the filter (if any), then delivers the pulse to each observer
  /// in sequence, respecting the propagation policy. If a cycle is detected,
  /// the branch is silently terminated.
  ///
  /// ### Non‑obvious
  /// - The broadcast is synchronous by default – use the `async` view for
  ///   non‑blocking delivery.
  /// - If a downstream observer is invalidated, it's skipped.
  void call(covariant P pulse);

  /// Provides an asynchronous view of these synapses for non‑blocking
  /// signal distribution.
  ///
  /// ### When to use
  /// Use this when you need to broadcast without blocking the current
  /// execution thread – e.g., for UI updates, logging, or background
  /// processing.
  ///
  /// ### How it works
  /// The async view schedules the broadcast on the event loop. It also
  /// uses a thread‑safe cycle checker to maintain causal integrity.
  ///
  /// ### Example
  /// ```dart
  /// await synapses.async.call(Pulse('update'));
  /// ```
  AsyncSynapses<P,L> get async;

  /// Establishes a formal reactive connection (link) between the host [cell]
  /// and a [downstreamCell].
  ///
  /// ### When to use
  /// Use this to dynamically add an observer to a cell at runtime – e.g.,
  /// when a UI component mounts.
  ///
  /// ### How it works
  /// The method validates the link via the cell's [TestCell], then adds the
  /// downstream cell to the registry. If the cell is already linked, it's a
  /// no‑op. Returns `true` on success, `false` if rejected.
  ///
  /// ### Non‑obvious
  /// - The link is governed by the host cell's validation rules – you can't
  ///   link to a cell that the host doesn't allow.
  /// - Deputies and their principals are considered equivalent for linking.
  ///
  /// ### Example
  /// ```dart
  /// final linked = await synapses.link(source, downstreamCell: observer);
  /// if (linked) { /* observer now receives updates */ }
  /// ```
  ///
  /// ### Parameters:
  /// - [cell]: The host cell that owns these synapses (the source of the
  ///   signals).
  /// - [downstreamCell]: The cell that should receive signals from the host
  ///   (the target observer).
  ///
  /// ### Returns:
  /// - `true` if the link was successfully established or already existed.
  /// - `false` if the connection was rejected by security rules or if
  ///   the synapses are disabled.
  FutureOr<bool> link(L cell, {required Cell downstreamCell});

  /// Formally dissolves the reactive connection (link) between the host [cell]
  /// and the [downstreamCell], neutralizing the signal path between them.
  ///
  /// ### When to use
  /// Use this to remove an observer when it's no longer needed – e.g., when
  /// a UI component unmounts, to prevent memory leaks.
  ///
  /// ### How it works
  /// The method removes the downstream cell from the registry. If the link
  /// doesn't exist, it's a no‑op. Returns `true` if the link was removed,
  /// `false` otherwise.
  ///
  /// ### Example
  /// ```dart
  /// synapses.unlink(source, downstreamCell: observer);
  /// ```
  ///
  /// ### Parameters:
  /// - [cell]: The host cell that owns these synapses (the source of the signals).
  /// - [downstreamCell]: The observer cell that should be disconnected
  ///   from the host.
  ///
  /// ### Returns:
  /// - `true` if the link was successfully found and removed.
  /// - `false` if the link did not exist, or if the operation was rejected
  ///   by security rules or disabled synapses.
  bool unlink(Cell cell, {required Cell downstreamCell});

}