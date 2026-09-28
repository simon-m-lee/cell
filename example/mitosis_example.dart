// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.

// ─────────────────────────────────────────────────────────────────────────────
// MITOSIS — start with the Mitose pipeline
// ─────────────────────────────────────────────────────────────────────────────
// This file is the pub.dev example entry point for the `mitosis` umbrella
// package, but the primary way to operate this repository is the **Mitose
// pipeline** described in `guide/HowTo-Mitose.md`.
//
// Mitose pipeline in one sentence:
//
//   You provide a business requirement; an AI prompt agent follows
//   `guide/HowTo-Mitose.md` and produces a working Cell + Flow + Tissue
//   solution together with its project documents:
//
//     <stem>-BRD.md
//     <stem>(Cell)-WalkThrough.md
//     <stem>(Cell)-Demo.dart
//     <stem>(Cell)-ARCHITECTURE.md
//     <stem>(Cell)-FEATURES.md
//
// How to start the pipeline:
//
//   1. In an agentic IDE (Copilot, Codex, Cursor, …), open this repository
//      and simply say "Mitose" — the repo-root `AGENTS.md` tells the agent
//      what to do.
//
//   2. In a plain AI chat, paste:
//
//        Read guide/HowTo-Mitose.md and run the Mitose pipeline.
//        The repository is the cell workspace.
//        My business requirement is: <paste your requirement here>
//
//   3. Or try a ready-made BRD from `example/BRD/` to watch the pipeline run:
//
//        Read guide/HowTo-Mitose.md and run the Mitose pipeline.
//        Use example/BRD/airport_baggage_handling-BRD.md as the BRD.
//
// Layer rules the pipeline consults while placing every part:
//
//   guide/HowTo-Mitose-Cell.md   — where a requirement lands in Cell
//   guide/HowTo-Mitose-Flow.md   — where a requirement lands in Flow
//   guide/HowTo-Mitose-Tissue.md — where a requirement lands in Tissue
//
// The runnable `main()` below only prints the pointer above. The canonical
// three-layer code sample is kept as a reference comment at the bottom of
// this file.
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  print('''
MITOSIS — start with the Mitose pipeline.

  In an agentic IDE (Copilot, Codex, Cursor, ...): just say "Mitose".

  In a plain AI chat, paste:
    Read guide/HowTo-Mitose.md and run the Mitose pipeline.
    The repository is the cell workspace.
    My business requirement is: <paste your requirement here>

  Try a sample BRD immediately:
    Read guide/HowTo-Mitose.md and run the Mitose pipeline.
    Use example/BRD/airport_baggage_handling-BRD.md as the BRD.

Docs: guide/HowTo-Mitose.md  ·  AGENTS.md  ·  example/BRD/
''');
}

// ─────────────────────────────────────────────────────────────────────────────
// Canonical three-layer pattern (reference code, kept in comments)
//
//   import 'package:mitosis/mitosis.dart';
//
//   Future<void> main() async {
//     // 1. CELL — events enter the graph through an ingress.
//     final commands = Cell.ingress<String>();
//
//     // 2. FLOW — orchestration: normalize, gate, deduplicate.
//     final accepted = commands.cell
//         .map<String, String>(project: (c) => c.trim())
//         .filter<String>(test: (c) => c.isNotEmpty)
//         .distinct<String>();
//
//     // 3. TISSUE — application state: a governed, observable collection.
//     final ledger = TissueList.of(<String>[]);
//
//     Cell.observe<Pulse<String>>(
//       source: accepted.cell,
//       effect: (pulse) => ledger.add('ACCEPTED: ${pulse.payload}'),
//     );
//
//     await commands.emitAsync('  deploy mitosis  ');
//     await commands.emitAsync('  deploy mitosis  '); // distinct: duplicate dropped
//     print(ledger); // [ACCEPTED: deploy mitosis]
//   }
// ─────────────────────────────────────────────────────────────────────────────
