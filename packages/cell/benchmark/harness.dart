// Shared fixtures for the Cell benchmark suite.
//
// All benchmarks live OUTSIDE the `cell` library, so they exercise only the
// public API surface — exactly what an adopter would use.
library;

import 'package:cell/cell.dart';

/// A no-op lifecycle policy used to exercise governed cells without
/// extra timer/limit machinery.
EphemeralPolicy<Cell> noOpPolicy() => EphemeralPolicy<Cell>(
      onEvent: (object, {required cell, arguments, required policy, user}) {
        return (events: policy.events + 1);
      },
      onInvalidate: (nucleus) => true,
    );

/// Builds a linear chain of [depth] pass-through cells.
///
/// The head is an [Cell.ingress] handle whose `emit` feeds the chain at
/// native speed. With [governed] every cell hosts an ephemeral policy so
/// governed-vs-ungoverned comparisons share the exact same shape.
({Cell head, bool Function(int) emit}) buildChain(int depth,
    {bool governed = false}) {
  final handle = Cell.ingress<int>(
    ephemeralPolicy: governed ? noOpPolicy() : null,
  );
  var current = handle.cell;
  for (var i = 1; i < depth; i++) {
    current = Cell.governed(
      bind: current,
      ephemeralPolicy: governed ? noOpPolicy() : null,
    );
  }
  return (head: handle.cell, emit: handle.emit);
}

/// Builds a fan-out: one source with [fanOut] observers.
({Cell source, bool Function(int) emit}) buildFanOut(int fanOut) {
  final handle = Cell.ingress<int>();
  for (var i = 0; i < fanOut; i++) {
    Cell.observe(source: handle.cell, effect: (_) {});
  }
  return (source: handle.cell, emit: handle.emit);
}

/// Builds a diamond: one source, two middle branches, one shared sink.
({Cell source, bool Function(int) emit, Cell sink}) buildDiamond() {
  final handle = Cell.ingress<int>();
  final left = Cell(bind: handle.cell);
  final right = Cell(bind: handle.cell);
  // Both branches converge on the sink: `left` via its bind, `right`
  // through an observer that re-emits into the sink's ingress.
  final sinkHandle = Cell.ingress<int>(source: left);
  Cell.observe(
    source: right,
    effect: (Pulse p) => sinkHandle.emit(p.payload! as int),
  );
  return (source: handle.cell, emit: handle.emit, sink: sinkHandle.cell);
}
