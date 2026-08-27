// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell.dart';

class _ContextDescribe implements Context {

  final String description;

  const _ContextDescribe(this.description);

  @override
  Context evolve(GovernanceEntry? Function(Governance evolvable) resolver, {Map<String, dynamic>? others}) {
    final entries = Ontology.evolve(resolver);
    return _Context.fromEntries(entries, others: others);
  }

  @override
  operator [](Governance dimension) => null;

  @override
  String? get compliance => null;

  @override
  Map<String, String>? get constraints => null;

  @override
  String? get dataSources => null;

  @override
  String? get domains => null;

  @override
  String? get isNot => null;

  @override
  List<String> lineage(Governance<dynamic> dimension) => const[];

  @override
  String? get partOf => null;

  @override
  String? get stakeholders => null;

  @override
  String? get subDomains => null;

  @override
  String? get taxonomy => null;

  @override
  String? get topology => null;

  @override
  String? get version => null;

  @override
  String? get identity => null;

  @override
  String? get type => null;

}

class _ContextSystem implements Context {

  const _ContextSystem();

  @override
  Context evolve(GovernanceEntry? Function(Ontology evolvable) resolver, {Map<String, dynamic>? others}) {
    final entries = Ontology.evolve(resolver);
    return _Context.fromEntries(entries, others: others);
  }

  @override
  operator [](Governance dimension) => null;

  @override
  List<String> lineage(Governance dimension) => const [];

  @override
  String? get taxonomy => null;

  @override
  String? get topology => null;

  @override
  String? get dataSources => null;

  @override
  Map<String, dynamic>? get constraints => null;

  @override
  String? get stakeholders => null;

  @override
  String? get domains => null;

  @override
  String? get version => null;

  @override
  String? get subDomains => null;

  @override
  String? get isNot => null;

  @override
  String? get compliance => null;

  @override
  String? get partOf => null;

  @override
  String? get identity => null;

  @override
  String? get type => null;

}

class _Context extends ContextBase {

  _Context({
    String? type,
    String? identity,

    String? domains,
    String? dataSources,
    String? taxonomy,
    String? topology,
    String? version,

    String? subDomains,
    String? stakeholders,
    Map<String, dynamic>? constraints,
    String? isNot,
    String? compliances,
    String? partOf,
    Map<String, dynamic>? others
  }) : this.fromEntries(<GovernanceEntry>[
    if (type != null) Ontology.type.entry(type),
    if (identity != null) Ontology.identity.entry(identity),
    if (partOf != null) Ontology.partOf.entry(partOf),
    if (dataSources != null) Ontology.dataSources.entry(dataSources),
    if (constraints != null) Ontology.constraints.entry(constraints),
    if (domains != null) Ontology.domains.entry(domains),
    if (subDomains != null) Ontology.subDomains.entry(subDomains),
    if (stakeholders != null) Ontology.stakeholders.entry(stakeholders),
    if (isNot != null) Ontology.isNot.entry(isNot),
    if (compliances != null) Ontology.compliance.entry(compliances),
  ], others: others);

  _Context.fromEntries(super.entries, {super.others, super.parent});

  @override
  Context evolve(covariant GovernanceEntry? Function(Ontology evolvable) resolver, {Map<String, dynamic>? others}) {
    final entries = Ontology.evolve(resolver);
    return _Context.fromEntries(entries, others: others, parent: this);
  }

}

/// The foundational implementation of the **Operational Environment**, providing
/// the core logic for **Prototype-based Inheritance** and **Ontological Resolution**.
///
/// [ContextBase] serves as the metabolic engine for all specialized contexts
/// (such as [DeputyContext] or [PulseContext]). It handles the hierarchical
/// lookups and state management required to maintain the **Causal Trace** of
/// a [Cell]'s authority and identity.
///
/// ### When to use
/// You rarely interact with this directly. Use the [Context] factory methods
/// like `Context.module()`, `Context.secureEnclave()`, or `Context.system`.
/// This class is the base that powers those factories.
///
/// ### How it works
/// - Stores governance metadata (like domains, constraints, compliance) in a
///   memory-efficient record.
/// - Supports prototype-based inheritance: if a property isn't found locally,
///   it walks up the `parent` chain.
/// - All state is immutable – to change a context, you create a new one via
///   `evolve()`.
///
/// ### Non‑obvious
/// - The `parent` chain is established at construction time and never changes.
/// - Equality (`==`) and `hashCode` are based on the entire record, including
///   the parent chain – so two contexts are equal only if they have identical
///   metadata and ancestry.
/// - Even though it's called "base", it's fully functional on its own – you
///   can use it directly, but the factory methods are more convenient.
///
/// See also: [Context], [DeputyContext], [PulseContext], [Ontology].
abstract class ContextBase implements Context {

  final dynamic _record;

  /// Synthesizes an **Operational Environment** from a collection of
  /// strongly-typed governance entries.
  ///
  /// ### When to use
  /// You typically use [Context.fromEntries] instead of calling this directly.
  /// This constructor is the internal engine that powers that factory.
  ///
  /// ### How it works
  /// It takes a list of [GovernanceEntry] objects and packs them into a
  /// memory-optimised record. If a [parent] is provided, the new context
  /// inherits from it via prototype-based inheritance.
  ///
  /// ### Non‑obvious
  /// - The [parent] chain is immutable – once set, it can't be changed.
  /// - The [others] map is for custom metadata that doesn't fit the standard
  ///   ontology dimensions.
  ///
  /// ### Parameters:
  /// - [entries]: An iterable of [GovernanceEntry] pairs defining the core
  ///   ontological pillars of the context.
  /// - [others]: A catch-all map for dynamic, non-standard metadata used in
  ///   specialised **Scene-Driven** logic.
  /// - [parent]: The ancestral [Context] from which this instance derives
  ///   its baseline governance and identity.
  ContextBase(Iterable<GovernanceEntry> entries, {Map<String, dynamic>? others, Context? parent})
      : this.fromRecord(parent != null ? others != null
      ? (map: Map<Governance,dynamic>.unmodifiable(Map.fromEntries(entries.map((e) => e.toEntry()))), others: Map<String,dynamic>.unmodifiable(others), parent: parent)
      : (map: Map<Governance,dynamic>.unmodifiable(Map.fromEntries(entries.map((e) => e.toEntry()))), parent: parent)
      : (map: Map.fromEntries(entries.map((e) => e.toEntry()))));

  /// The foundational initializer that anchors the context to a
  /// memory-optimised record.
  ///
  /// ### When to use
  /// This is an internal constructor used by the framework. You don't need to
  /// call it directly – use the [Context] factories.
  ///
  /// ### How it works
  /// It directly assigns the provided [Record] to the internal storage.
  /// This bypasses the overhead of map-to-record conversion for maximum
  /// performance.
  ///
  /// ### Non‑obvious
  /// - The record format is internal – don't rely on its structure.
  /// - This constructor is used by subclasses like `DeputyContext` and
  ///   `PulseContext` for efficient instantiation.
  ///
  /// ### Parameters:
  /// - [record]: The structured Dart Record containing the `map`, optional
  ///   `others`, and optional `parent` reference.
  ContextBase.fromRecord(Record record) : _record = record;

  @override
  List<String> lineage(Ontology dimension) {
    List<String> lineage = [];

    ContextBase? context;
    context = this;
    while (context != null) {
      try {
        final key = context._record.map.keys.firstWhere((k) => k == dimension);
        lineage.add(context._record.map[key]);
      } catch (_) {}
      context = context._parent;
    }
    return lineage.reversed.toList(growable: false);
  }

  @override
  dynamic operator [](Governance dimension) {
    Map<Governance,dynamic>? map = _record.map;
    while (map != null) {
      try {
        final key = map.keys.firstWhere((k) => k == dimension);
        return map[key];
      } catch (_) {}
      map = _parent?._record.map;
    }
    return null;
  }

  ContextBase? get _parent => get<ContextBase?>(() => _record._parent, orElse: null);

  @override
  String? get type => get<String?>(
        () => _record.map[Ontology.type] ?? _parent?.type,
    orElse: null,
  );

  @override
  String? get identity => get<String?>(
        () => _record.map[Ontology.identity] ?? _parent?.identity,
    orElse: null,
  );

  @override
  String? get taxonomy => get<String?>(
        () => _record.map[Ontology.taxonomy] ?? _parent?.taxonomy,
    orElse: null,
  );

  @override
  String? get topology => get<String?>(
        () => _record.map[Ontology.topology] ?? _parent?.topology,
    orElse: null,
  );

  @override
  String? get dataSources => get<String?>(
        () => _record.map[Ontology.dataSources] ?? _parent?.dataSources,
    orElse: null,
  );

  @override
  Map<String, dynamic>? get constraints => get<Map<String, dynamic>?>(
        () => _record.map[Ontology.constraints] ?? _parent?.constraints,
    orElse: null,
  );

  @override
  String? get domains => get<String?>(
        () => _record.map[Ontology.domains] ?? _parent?.domains,
    orElse: null,
  );

  @override
  String? get subDomains => get<String?>(
        () => _record.map[Ontology.subDomains] ?? _parent?.subDomains,
    orElse: null,
  );

  @override
  String? get stakeholders => get<String?>(
        () => _record.map[Ontology.stakeholders] ?? _parent?.stakeholders,
    orElse: null,
  );

  @override
  String? get isNot => get<String?>(
        () => _record.map[Ontology.isNot] ?? _parent?.isNot,
    orElse: null,
  );

  @override
  String? get compliance => get<String?>(
        () => _record.map[Ontology.compliance] ?? _parent?.compliance,
    orElse: null,
  );

  @override
  String? get partOf => get<String?>(
        () => _record.map[Ontology.partOf] ?? _parent?.partOf,
    orElse: null,
  );

  @override
  String? get version => get<String?>(
        () => _record.map[Ontology.version] ?? _parent?.version,
    orElse: null,
  );

  /// Performs **Identity Synthesis** by comparing the structural convergence
  /// of two **Somatic Signatures**.
  ///
  /// This ensures that nodes within the reactive network are recognized
  /// as identical if their ontological data and ancestry match exactly,
  /// supporting deterministic policy enforcement.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ContextBase) return false;

    // Identity is derived from the structural equality of the
    // internal Somatic Signature (Record).
    return _record == other._record;
  }

  /// Generates a unique hash derived from the **Ontological Footprint**
  /// of the context.
  ///
  /// This stable identifier allows for high-performance lookups and
  /// ensures that the node's position within the **Causal Trace** remains
  /// consistent during reactive propagation.
  @override
  int get hashCode => _record.hashCode;

}

/*

  late final Map<String, String> _map = _createMap();

  Map<String, String> _createMap() {
    final Map<String, String> local = get<Map<String, String>>(() => _record.map, orElse: {});

    // Recursively resolve the parent's consolidated map
    final Map<String, String> parentMap = (parent as _Context?)?._map ?? {};

    if (parentMap.isEmpty) return local;
    if (local.isEmpty) return parentMap;

    // Create a mutable collection for metabolic fusion
    final result = Map<String, String>.from(parentMap);

    // Merge local traits into the inherited map
    local.forEach((key, value) {
      final existing = result[key];
      if (existing != null) {
        // If the key exists in the lineage, append the new trait to the
        // existing somatic signature.
        result[key] = '$existing, $value';
      } else {
        result[key] = value;
      }
    });

    return Map<String, String>.unmodifiable(result);
  }

  @override
  Iterable<String> findKeysByValue(Pattern pattern) {
    final List<String> matchingKeys = [];

    _map.forEach((key, value) {
      // Since values can be consolidated (joined by ', '), we split the
      // metabolic signature into individual phenotypic traits before matching.
      final traits = value.split(', ');

      for (final trait in traits) {
        if (pattern.allMatches(trait).isNotEmpty) {
          matchingKeys.add(key);
          break; // Move to the next key once a trait match is found.
        }
      }
    });

    return matchingKeys;
  }

  @override
  Map<String, String> get properties => Map.unmodifiable(_map);

  @override
  int get hashCode {
    /// The hash code is derived from the **Structural Identity** of the context.
    ///
    /// In the reactive framework, the identity of a [Context] is defined by the
    /// unique intersection of its localized property overrides and its position
    /// within the **Inheritance Hierarchy**.
    ///
    /// This ensures that:
    /// *   **Authority Uniqueness**: Two contexts with identical local properties
    ///     are treated as distinct if they originate from different [parent]
    ///     authority chains.
    /// *   **Deterministic Resolution**: The hash remains stable and anchored
    ///     to the specific configuration and ancestry, allowing for high-
    ///     performance lookups in flattened state maps.
    return Object.hash(
      /// The internal record containing localized property overrides.
      _record,
      /// The parent reference representing the inherited authority chain.
      parent,
    );
  }

  String toString() => _map.toString();

}

*/
