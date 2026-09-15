// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.

/// 🧬 **Mitosis** — the unified reactive framework for Dart.
///
/// Mitosis is the umbrella package for the three public layers of the
/// framework. One import brings in the whole organism:
///
/// ```dart
/// import 'package:mitosis/mitosis.dart';
/// ```
///
/// ### 🏗️ The three layers
///
/// | Layer | Package | Biological analogue | Key types |
/// |---|---|---|---|
/// | Core | `cell` | The brain & synapses | [Cell], [Pulse], [Receptor], [TestCell], [Context] |
/// | Orchestration | `cell_flow` | The nervous system | [Flow], [FlowInstruction] |
/// | Application | `cell_tissue` | The body | [TissueList], [TissueSet], [TissueMap], [TissueQueue], [TissueValue] |
///
/// Every layer shares the same graph, locks, validation, and provenance:
/// a [Pulse] is the immutable message that moves a change, [TestCell] /
/// [TestTissue] gates are enforced before a mutation commits, and the
/// [Pulse.trace] keeps the causal chain inspectable end to end.
///
/// ### 🚀 Hello Mitosis
///
/// ```dart
/// Future<void> main() async {
///   // Cell — state with an explicit update path.
///   final counter = Cell.state<int>(
///     initial: 0,
///     evolve: (host, input) =>
///         Pulse((host.value ?? 0) + (input.payload ?? 1)),
///   );
///
///   // Observe — side effects react to accepted pulses.
///   final observer = Cell.observe<Pulse<int>>(
///     source: counter.cell,
///     effect: (pulse) => print('Counter: ${pulse.payload}'),
///   );
///
///   await counter.updateAsync(5); // prints: Counter: 5
///   observer.stop();
/// }
/// ```
///
/// ### 🧭 Which layer do I need?
///
/// - Reach for [Cell] for state atoms, events, validation gates, deputies,
///   and multi-cell transactions.
/// - Reach for [Flow] when you need temporal or combinatorial operators
///   (`debounce`, `switchMap`, `mergeMap`, `zip`, `retry`, `buffer`, ...).
/// - Reach for [TissueList] and friends when you need governed, observable
///   collections — ordered, unique, keyed, queued, or scalar — with the same
///   causal trail.
///
/// Flutter has no dedicated widgets here; bind with [Cell.observe] and drive
/// `setState` or your existing state library.
///
/// ### 📚 Documentation
///
/// - Core layer: <https://pub.dev/packages/cell>
/// - Orchestration layer: <https://pub.dev/packages/cell_flow>
/// - Application layer: <https://pub.dev/packages/cell_tissue>
/// - Repository: <https://github.com/simon-m-lee/cell>
/// {@category Walkthroughs}
library;

export 'package:cell/cell.dart';
export 'package:cell_flow/cell_flow.dart';
export 'package:cell_tissue/cell_tissue.dart';
