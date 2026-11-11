import io

# ═════════════════════════════════════════════════════════════
# 1. operators.dart: guard fire-and-forget link results.
# ═════════════════════════════════════════════════════════════
p = 'lib/src/internal/operator/operators.dart'
s = io.open(p, encoding='utf-8').read()

old = """Cell _switchMap<S, T>(
  Cell source,"""
new = """/// Consumes the result of a fire-and-forget link.
///
/// Operator pipelines are synchronous reactors, so their bridge links
/// assume synchronous [TestCell] rules. When a rule is explicitly async
/// the returned [Future] is still driven to completion: a rejected gate
/// is routed to the originating pulse's fail path (when a pulse is in
/// scope — construction-time links have none and are contained), and a
/// declined gate simply leaves the connection unestablished.
void _guardLink(FutureOr<bool> result, [PulseBase? pulse]) {
  if (result is! Future<bool>) return;
  unawaited(result.then((_) {}, onError: (Object e, StackTrace st) {
    if (pulse != null) {
      pulse._fail(e, stackTrace: st);
    }
    // Construction-time links have no pulse to fail; the error is consumed
    // so it does not become an unhandled zone error.
  }));
}

Cell _switchMap<S, T>(
  Cell source,"""
assert old in s, 'helper anchor not found'
s = s.replace(old, new, 1)

old = """        // Link the new inner cell to the output cell.
        newInner._nucleus.synapses.link(newInner, downstreamCell: cell);
        state.currentInner = newInner;"""
new = """        // Link the new inner cell to the output cell. The link may be an
        // async gate (Future<bool>): it is fire-and-forget here, but its
        // errors are routed to the originating pulse instead of the zone.
        _guardLink(
            newInner._nucleus.synapses.link(newInner, downstreamCell: cell),
            pulse as PulseBase);
        state.currentInner = newInner;"""
assert old in s, 'inner link not found'
s = s.replace(old, new, 1)

old = """  // Link the source to the output cell so source pulses reach our receptor.
  source._nucleus.synapses.link(source, downstreamCell: outputCell);

  return outputCell;
}

class _SwitchMapState<S, T> {"""
new = """  // Link the source to the output cell so source pulses reach our receptor.
  // Construction-time links have no pulse to fail; an async gate result is
  // driven to completion with errors contained (see _guardLink).
  _guardLink(source._nucleus.synapses.link(source, downstreamCell: outputCell));

  return outputCell;
}

class _SwitchMapState<S, T> {"""
assert old in s, 'switchMap source link not found'
s = s.replace(old, new, 1)

old = """  source._nucleus.synapses.link(source, downstreamCell: outputCell);
  return outputCell;
}"""
new = """  // Construction-time link (see _guardLink).
  _guardLink(source._nucleus.synapses.link(source, downstreamCell: outputCell));
  return outputCell;
}"""
assert old in s, 'distinct source link not found'
s = s.replace(old, new, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('operators link sites guarded')

# ═════════════════════════════════════════════════════════════
# 2. internal/cell.dart: guard the bind link in fromNucleus.
# ═════════════════════════════════════════════════════════════
p = 'lib/src/internal/cell.dart'
s = io.open(p, encoding='utf-8').read()

old = """      final bind = _nucleus.bind;
      if (bind != null) {
        final synapses = bind._nucleus.synapses;
        synapses.link(bind, downstreamCell: this);
      }"""
new = """      final bind = _nucleus.bind;
      if (bind != null) {
        final synapses = bind._nucleus.synapses;
        final linkResult = synapses.link(bind, downstreamCell: this);
        // `bind` construction assumes synchronous TestCell.link rules. An
        // explicitly async gate is still driven to completion; a rejection
        // is contained here (there is no pulse to fail during
        // construction) so it does not become an unhandled zone error.
        if (linkResult is Future<bool>) {
          unawaited(linkResult.then((_) {}, onError: (Object e, StackTrace st) {}));
        }
      }"""
assert old in s, 'bind link not found'
s = s.replace(old, new, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('bind link guarded')

# ═════════════════════════════════════════════════════════════
# 3. value.dart: document the StateHandle.update deduplication.
# ═════════════════════════════════════════════════════════════
p = 'lib/src/value.dart'
s = io.open(p, encoding='utf-8').read()

old = """///   `updateAsync` queues the mutation through the cell's [Lock], so it's
///   serialized with other async operations."""
new = """///   `updateAsync` queues the mutation through the cell's [Lock], so it's
///   serialized with other async operations.
///
///   **Deduplication**: a no-op update — a value that is `identical` to or
///   `==` the current state — is deliberately skipped and resolves `false`
///   (it emits nothing and is not a commit). Callers expecting exactly one
///   emission per `update` call should account for the deduplication."""
assert old in s, 'StateHandle doc anchor not found'
s = s.replace(old, new, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('StateHandle.update dedup documented')
