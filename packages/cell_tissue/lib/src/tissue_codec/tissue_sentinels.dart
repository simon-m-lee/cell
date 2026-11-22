// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

/// The **Explicit Null Test‑Rule Sentinel** for the `TissueXxx.fromJson`
/// override surface.
///
/// ### When to use
/// Pass it as `testRule:` to explicitly reconstruct the tissue with **no
/// validation** — `TestTissue.allowAll`:
///
/// ```dart
/// final list = TissueList.fromJson(json, testRule: tissueNullTestRule);
/// // list.validate == TestTissue.allowAll
/// ```
///
/// ### Non-obvious
/// This is **not** the lenient fallback. [tissueNullTestRule] is an explicit
/// override meaning "I want no validation"; the lenient fallback (when
/// `lenient: true` and the JSON's rule cannot be resolved) is
/// `lenientFallbackTestRule`, which defaults to [TestTissue.readOnly]. The
/// two intents differ: one widens, the other fails closed.
const Object tissueNullTestRule = _TissueNullTestRule();

/// The **Explicit Null Bind Sentinel** for the `TissueXxx.fromJson` override
/// surface. Passing it strips the upstream bind (`bind: null`).
const Object tissueNullBind = _TissueNullBind();

/// The **Explicit Null Container Sentinel** for the `TissueXxx.fromJson`
/// override surface. Passing it selects the framework default container for
/// the collection kind (e.g. [Container.growableTrue] for a list).
const Object tissueNullContainer = _TissueNullContainer();

/// The **Explicit Null User Sentinel** for the `TissueXxx.fromJson` override
/// surface. Passing it strips custom metadata (`user: null`).
const Object tissueNullUser = _TissueNullUser();

/// The **Explicit Null Elements Sentinel** for the `TissueXxx.fromJson`
/// override surface. Passing it reconstructs an empty collection
/// (`[]` for List/Set/Queue, `{}` for Map).
const Object tissueNullElements = _TissueNullElements();

/// The **Explicit Null Capacity Sentinel** for `TissueQueue.fromJson`.
/// Passing it reconstructs an unlimited queue (`capacity: -1`).
const Object tissueNullCapacity = _TissueNullCapacity();

/// The **Explicit Null Value Sentinel** for `TissueValue.fromJson`.
/// Passing it reconstructs a [TissueValue] whose value is `null`.
const Object tissueNullValue = _TissueNullValue();

/// Sentinel carrier for [tissueNullTestRule].
final class _TissueNullTestRule {
  const _TissueNullTestRule();

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => 0;

  @override
  String toString() => 'tissueNullTestRule';
}

/// Sentinel carrier for [tissueNullBind].
final class _TissueNullBind {
  const _TissueNullBind();

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => 1;

  @override
  String toString() => 'tissueNullBind';
}

/// Sentinel carrier for [tissueNullContainer].
final class _TissueNullContainer {
  const _TissueNullContainer();

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => 2;

  @override
  String toString() => 'tissueNullContainer';
}

/// Sentinel carrier for [tissueNullUser].
final class _TissueNullUser {
  const _TissueNullUser();

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => 3;

  @override
  String toString() => 'tissueNullUser';
}

/// Sentinel carrier for [tissueNullElements].
final class _TissueNullElements {
  const _TissueNullElements();

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => 4;

  @override
  String toString() => 'tissueNullElements';
}

/// Sentinel carrier for [tissueNullCapacity].
final class _TissueNullCapacity {
  const _TissueNullCapacity();

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => 5;

  @override
  String toString() => 'tissueNullCapacity';
}

/// Sentinel carrier for [tissueNullValue].
final class _TissueNullValue {
  const _TissueNullValue();

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => 6;

  @override
  String toString() => 'tissueNullValue';
}
