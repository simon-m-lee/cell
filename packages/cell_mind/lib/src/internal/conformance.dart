// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

// Conformance runner internals: verdict comparison for `conform`.

/// The mismatch description between [actual] and [expected], or `null`
/// when they match.
///
/// Same runtime type; `Reject` also compares `reason`; `Defer` also
/// compares `resolver`. Annotations are deliberately NOT compared —
/// parser-added fields (`reason`, `confidence`) would make every
/// hand-built expectation fail against a parsed verdict.
String? _verdictMismatch(Verdict actual, Verdict expected) {
  if (actual.runtimeType != expected.runtimeType) {
    return 'expected ${expected.runtimeType}, got ${actual.runtimeType}';
  }
  if (actual is Reject &&
      expected is Reject &&
      actual.reason != expected.reason) {
    return 'expected reason "${expected.reason}", got "${actual.reason}"';
  }
  if (actual is Defer &&
      expected is Defer &&
      actual.resolver != expected.resolver) {
    return 'expected resolver "${expected.resolver}", '
        'got "${actual.resolver}"';
  }
  return null;
}
