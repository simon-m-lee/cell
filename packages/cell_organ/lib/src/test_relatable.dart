// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell_organ.dart';

class TestRelatable<E, C extends Tissue<E>> extends TestTissue<E, C> {

  static const allowAll = _TestRelatableNever();

  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  const TestRelatable(FutureOr<bool> Function(dynamic object, {C? host, dynamic arguments, dynamic user}) rule, {TestRelatable<E, C>? parent, dynamic user})
      : this.fromRecord(parent != null ? user != null
      ? (rule: rule, parent: parent, user: user) : (rule: rule, parent: parent) : (rule: rule)
  );

  const TestRelatable.chain(Iterable<TestRule<C>> rules, {TestRelatable<E, C>? parent, dynamic user,
    FutureOr<bool> Function(dynamic object, {C? host, dynamic arguments, dynamic user})? strategy})
      : this.fromRecord(strategy != null ? parent != null
      ? user != null ? (rules: rules, rule: strategy, parent: parent, user: user) : (rules: rules, rule: strategy, parent: parent)
      : user != null ? (rules: rules, rule: strategy, user: user) : (rules: rules, rule: strategy)
      : (rules: rules)
  );

  const TestRelatable.fromRecord(super.record) : _record = record, super.fromRecord();

  @override
  TestRelatable<E, C> operator +(covariant TestRule<C> other) {
    return TestRelatable<E, C>.chain([this, other]);
  }

  static TestOne<H> one<H extends One>(Iterable<TestField<H, dynamic, Tissue>> rules, {
    TestOne<H>? parent, dynamic user,
    bool Function(dynamic object, {Tissue? host, dynamic arguments, dynamic user})? strategy}) {
    return TestOne<H>(rules, parent: parent, user: user, strategy: strategy);
  }

  static TestValue<H, V> value<H extends One, V>(Symbol name, Iterable<TestRule<ValueField<H, V>>> rules, {
    TestValue<H, V>? parent, dynamic user}) {
    return TestValue<H, V>.chain(name, rules, parent: parent, user: user);
  }

  static TestRelation<H, E, R> relation<H extends One, E extends One, R extends Relation<H, E>>(
      Symbol name, Iterable<TestRule<R>> rules, {TestRelation<H, E, R>? parent, dynamic user}) {
    return TestRelation<H, E, R>.chain(name, rules, parent: parent, user: user);
  }
}
