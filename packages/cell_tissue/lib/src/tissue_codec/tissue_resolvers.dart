// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

/// Resolves a `Cell.id` to a live [Cell].
///
/// ### When to use
/// Pass a resolver to [decodeTissue] / `TissueXxx.fromJson` so that `Cell`
/// elements, Map keys, and the upstream `bind` recorded on the wire are
/// re-linked to the live cells of the current process.
///
/// ### Contract
/// Return the live cell for [id], or `null` when the id is not present in the
/// current graph. The null paths are deliberately asymmetric per field:
///
/// * **Elements (List/Set/Queue/Value):** an unresolved cell becomes a
///   `null` element in both modes.
/// * **Map keys/values:** strict mode throws [TissueDecodeError]; lenient
///   mode skips the entry and reports it.
/// * **`bind`:** an unresolved bind id yields `bind == null` in both modes.
///
/// Losing an element is a data gap; losing a governance reference can be a
/// security hole — which is why governance resolution (see
/// [TissueGovernanceResolver]) fails closed.
typedef TissueCellResolver = Cell? Function(String id);

/// Resolves a governance tag (`registered:<key>`) to a [TestTissue].
///
/// ### When to use
/// Pass a resolver to [decodeTissue] / `TissueXxx.fromJson` when the wire
/// record carries a `registered:` test‑rule tag that was written by an
/// encoder outside this process.
///
/// ### Contract
/// The predefined tags `allowAll` and `readOnly` are resolved by the codec
/// without consulting this resolver. For any other tag the codec calls the
/// resolver (and, as a fallback, the in-process [TissueGovernanceRegistry]).
/// Returning `null` means "cannot resolve":
///
/// * **Strict mode:** [TissueDecodeError].
/// * **Lenient mode:** `lenientFallbackTestRule` (default
///   [TestTissue.readOnly] — fail-closed) and the loss is recorded in
///   `__skipped__`.
typedef TissueGovernanceResolver = TestTissue<dynamic, Tissue<dynamic>>?
    Function(String tag);

/// An in-process registry mapping governance tags (`registered:<key>`) to
/// [TestTissue] instances.
///
/// ### When to use
/// Register the named rules that participate in serialisation:
///
/// ```dart
/// final positive = TestTissue<int, TissueList<int>>(
///     (v, {host, arguments, user}) => v is int && v >= 0);
/// TissueGovernanceRegistry.register('positiveInt', positive);
/// ```
///
/// After registration, [encodeTissue] writes the rule as
/// `{"tag": "registered:positiveInt"}` and [decodeTissue] resolves the tag
/// back to the **same instance** — even when no [TissueGovernanceResolver]
/// is supplied.
///
/// ### Non-obvious
/// * **The registry is in-process.** Cross-process records still need a
///   [TissueGovernanceResolver] that rebuilds the rule from its name.
/// * **Identity matters.** A rule registered under a key must be retrieved
///   by that exact key; keys are compared by `String` equality.
/// * **The registry never widens permissions.** Decoding a tag that is
///   neither predefined nor registered falls back to
///   `lenientFallbackTestRule` in lenient mode (default
///   [TestTissue.readOnly]).
abstract final class TissueGovernanceRegistry {
  static final Map<String, TestTissue<dynamic, Tissue<dynamic>>> _rules = {};

  /// Registers [rule] under [tag] for both encode and decode.
  ///
  /// Re-registering the same tag replaces the previous rule.
  static void register(
    String tag,
    TestTissue<dynamic, Tissue<dynamic>> rule,
  ) {
    _rules[tag] = rule;
  }

  /// Removes the rule registered under [tag], if any.
  static void unregister(String tag) {
    _rules.remove(tag);
  }

  /// The tag under which [rule] is registered, or `null` when the rule is
  /// not registered. [TestTissue.allowAll] / [TestTissue.readOnly] resolve
  /// through the codec, not the registry, and therefore return `null` here.
  static String? tagOf(TestTissue<dynamic, Tissue<dynamic>> rule) {
    if (identical(rule, TestTissue.allowAll) ||
        identical(rule, TestTissue.readOnly)) {
      return null;
    }
    for (final entry in _rules.entries) {
      if (identical(entry.value, rule)) return entry.key;
    }
    return null;
  }

  /// Resolves a full `registered:<key>` tag to its registered rule, or
  /// `null` when the tag is not registered.
  static TestTissue<dynamic, Tissue<dynamic>>? lookup(String tag) {
    if (!tag.startsWith('registered:')) return null;
    return _rules[tag.substring('registered:'.length)];
  }

  /// Clears the registry (tests only).
  static void forceReset() {
    _rules.clear();
  }
}
