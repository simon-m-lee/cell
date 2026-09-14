// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell_organ.dart';

class _TestRelationNever
    implements TestRelation<Never, Never, Never>, TestPasses {
  const _TestRelationNever();

  @override
  TestRelation<Never, Never, Never> operator +(covariant TestRule other) {
    return TestRelation<Never, Never, Never>(const [],
        fn: (dynamic object,
                {TestRelation<Never, Never, Never>? host,
                dynamic arguments,
                dynamic user}) =>
            other.call(object, host: host, arguments: arguments));
  }

  @override
  bool call(object, {covariant Cell? host, arguments}) {
    return true;
  }

  @override
  bool action(Function action, {required Cell host, Arguments? arguments}) {
    return true;
  }

  @override
  bool element(covariant Never? element,
      {required Cell host, Function? action}) {
    return true;
  }

  @override
  bool link(covariant Cell link, {required Cell host}) {
    return false;
  }

  @override
  bool pulse(covariant Pulse<dynamic> pulse, {required Cell host}) {
    return true;
  }

  @override
  get _record => ();
}
