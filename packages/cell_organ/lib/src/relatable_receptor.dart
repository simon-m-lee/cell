// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell_organ.dart';

// final class RelatablePost extends Post<Tissue, RelatablePulse> {
//   RelatablePost._({required super.from, required super.body}) : super();
//
//   late final RelatablePost unmodifiable = _UnmodifiableRelatablePost._(this);
// }

abstract interface class RelatableReceptor<E, C extends Tissue<E>>
    implements TissueReceptor<E, C> {
  static const passThrough = _PassThroughRelatableReceptor();

  factory RelatableReceptor(PulseRule rule) = _RelatableReceptor;

  static RelatableReceptor<E, C>
      transform<E, C extends Tissue<E>, O extends Pulse>(
          O? Function(C cell, RelatablePost pulse, {dynamic user}) rule,
          {dynamic user}) {
    return _RelatableReceptor<E, C>(PulseRule<C, RelatablePost, O>(rule));
  }

  @override
  RelatableReceptor<E, C> get clone;
}
