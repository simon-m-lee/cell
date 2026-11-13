// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Bridges a [DeputyContext] across mandate schema versions.
///
/// A `ContextTranslator` is the user's hook for "the mandate schema
/// changed between version A and version B — here's how to translate a
/// version-A context into a version-B context". The framework cannot
/// know what fields were added, renamed, or deprecated; it only knows
/// that a version boundary exists and must be crossed.
///
/// ### Non-obvious: a translator is *directional*
///
/// `v1 → v2` is not the same as `v2 → v1`. Replay only ever goes
/// forward (the ledger records the past; the graph is the present).
/// If a ledger recorded a version-2 context and the current graph is
/// version-1 (a downgrade), the translator for `v2 → v1` is required —
/// but a downgrade is almost always a *semantic loss* (a field added
/// in v2 has no home in v1), and the framework cannot safely assume
/// which direction preserves meaning. The `ContextTranslator` API
/// therefore requires the caller to declare both the source and target
/// versions explicitly.
abstract class ContextTranslator {
  /// The version this translator bridges from.
  String get fromVersion;

  /// The version this translator bridges to.
  String get toVersion;

  /// Translates [source] from [fromVersion] to [toVersion]. Returns a
  /// context whose `version` equals [toVersion].
  ///
  /// The translator is responsible for preserving the *meaning* of the
  /// source context — a `Clearance.administrative` source must not
  /// silently become `Clearance.observational` (that would weaken the
  /// mandate's authority); a new field added in the target version
  /// must be given a sensible default documented in the translator's
  /// `toString`.
  FutureOr<DeputyContext> translate(DeputyContext source);
}

/// A simple registry of translators keyed by `(from, to)`.
///
/// The registry is per-graph, matching `VersionRegistry`'s scoping.
/// Translators registered on one graph do not affect another.
class ContextTranslatorRegistry {
  final Map<String, Map<String, ContextTranslator>> _byPair = {};

  void register(ContextTranslator translator) {
    final from = translator.fromVersion;
    final to = translator.toVersion;
    if (from == to) {
      throw ArgumentError(
        'ContextTranslatorRegistry: translator from "$from" to "$to" '
        'is a no-op; do not register it.',
      );
    }
    _byPair.putIfAbsent(from, () => {})[to] = translator;
  }

  ContextTranslator? resolve({required String from, required String to}) {
    return _byPair[from]?[to];
  }

  /// Translates [source] from its own version to [target]. If they are
  /// equal, returns [source] unchanged (no translation needed). If no
  /// translator is registered, throws [UnimplementedError] — a loud
  /// failure, as the design's exit criterion requires.
  Future<DeputyContext> translate(
    DeputyContext source, {
    required String target,
  }) async {
    final from = source.version;
    if (from == target) return source;
    final translator = resolve(from: from, to: target);
    if (translator == null) {
      throw UnimplementedError(
        'ContextTranslatorRegistry: no translator registered for '
        '"$from" -> "$target". Register one with '
        'ContextTranslatorRegistry.register(...), or '
        'record a ledger at version "$target".',
      );
    }
    final result = await translator.translate(source);
    if (result.version != target) {
      throw StateError(
        'ContextTranslator "$translator" returned a context '
        'with version "${result.version}", expected "$target".',
      );
    }
    return result;
  }
}

/// The graph-scoped translator registry.
extension CellGraphTranslators on CellGraph {
  static final Expando<ContextTranslatorRegistry> _registries = Expando();

  ContextTranslatorRegistry get translators {
    return _registries[this] ??= ContextTranslatorRegistry();
  }
}
