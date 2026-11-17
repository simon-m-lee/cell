// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The interactive pipeline gates (Gate 1: walkthrough, Gate 2: design).
library;

import 'dart:io';

/// The outcome of a gate prompt.
enum GateDecision { approve, reject }

/// Asks the user to approve [summary] for [artifact].
///
/// Interactive prompt: `[a]pprove [r]eject [v]iew raw [q]uit`. When stdin
/// is not a terminal (CI) — or [interactive] is explicitly false — the
/// gate defaults to approve so automation can run the full pipeline.
GateDecision promptGate({
  required String title,
  required String artifact,
  required String summary,
  bool? interactive,
}) {
  final isInteractive = interactive ?? stdin.hasTerminal;
  if (!isInteractive) {
    stdout.writeln('  $title: non-interactive session — auto-approved.');
    return GateDecision.approve;
  }
  while (true) {
    stdout.writeln('\n═══ $title ═══');
    stdout.writeln(summary);
    stdout.write('  [a]pprove  [r]eject  [v]iew raw  [q]uit  ');
    final line = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    switch (line) {
      case 'a' || 'approve':
        return GateDecision.approve;
      case 'r' || 'reject':
        return GateDecision.reject;
      case 'v' || 'view':
        stdout.writeln(artifact);
        continue;
      case 'q' || 'quit' || '':
        return GateDecision.reject;
      default:
        stdout.writeln('  Unknown choice: "$line"');
    }
  }
}
