// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered example file names; the numeric
// prefix is intentional (02_authority_deputy → example #2).
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';

/// Authority-gated API — a cell whose command surface is governed by its
/// `Mandate.authority`, with every attempt recorded.
///
/// Run with:
/// ```bash
/// dart run example/02_authority_deputy.dart
/// ```
Future<void> main() async {
  print('=== Authority-gated API ===');
  print('');

  // 1. The cell's mandate declares its verb whitelist.
  final mandate = DeputyContext(
    baseContext: Context.system,
    authority: 'read,write',
    justification: 'Balance API surface',
  );

  final cell = Cell.ingress<int>(context: mandate);

  // 2. Dynamic mode: authority policy + decision recording.
  final handle = cognitive(cell: cell.cell, policy: authorityPolicy());

  // 3. The API surface.
  Future<String> tryApply(Function fn, [List<Object?>? args]) async {
    final outcome = await handle.cognitive.apply<dynamic>((
      function: fn,
      arguments: (positionalArguments: args, namedArguments: null),
      compensation: null,
    ));
    return outcome is ApplyAccepted ? 'ACCEPTED' : 'REJECTED';
  }

  print('  read   -> ${await tryApply(read, [1])}');
  print('  write  -> ${await tryApply(write, [1])}');
  print('  delete -> ${await tryApply(delete, [1])}');

  // 4. The decision log — every attempt, accept or reject.
  print('');
  print('=== Decision log ===');
  for (final decision in handle.decisions) {
    final command = decision.command;
    final verb = command == null ? '?' : _verbName(command.function);
    final verdict = decision.verdict;
    final detail = verdict is Reject ? ' (${verdict.reason})' : '';
    print('  [$verb] ${verdict.runtimeType}$detail '
        'ctx=${decision.contextVersion}');
  }
  print('');
  print('Done.');
}

int read(int x) => x;
void write(int x) {}
void delete(int x) {}

String _verbName(Function function) {
  final match = RegExp(r"Function '(\w+)'").firstMatch(function.toString());
  return match?.group(1) ?? function.toString();
}
