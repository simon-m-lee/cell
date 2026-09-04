// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/routing.dart';

/// Feature flag on the same Receptor: beta users get a preview label.
///
/// Expected:
/// ```text
/// [flag] preview
/// [flag] stable
/// ```
Future<void> main() async {
  final gate = Filter<({String user, bool beta})>((u) => u.user.isNotEmpty) +
      Iif<({String user, bool beta}), String>(
        (u) => u.beta,
        thenMap: (_) => 'preview',
        elseMap: (_) => 'stable',
      );

  final users = Cell.ingress<({String user, bool beta})>();
  final out = gate.toHandle(source: users.cell);
  final obs = Cell.observe(
    source: out.cell,
    effect: (Pulse p) => print('[flag] ${p.payload}'),
  );

  await users.emitAsync((user: 'ada', beta: true));
  await users.emitAsync((user: 'bob', beta: false));
  obs.stop();
}
