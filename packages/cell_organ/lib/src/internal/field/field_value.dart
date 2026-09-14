// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell_organ.dart';

class _TestValueNever implements TestValue<Never, Never> {
  const _TestValueNever();

  @override
  get _record => ();

  @override
  bool action(Function action, {required Cell host, Arguments? arguments}) {
    return true;
  }

  @override
  bool call(object, {covariant Cell? host, arguments}) {
    return true;
  }

  @override
  bool element(covariant ValueField<Never, Never>? element,
      {required ValueField<Never, dynamic> host, Function? action}) {
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
  TestValue<Never, Never> operator +(
      covariant TestRule<ValueField<Never, Never>> other) {
    return this;
  }
}
