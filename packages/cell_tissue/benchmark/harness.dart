// Shared fixtures for the cell_tissue benchmark suite.
//
// All benchmarks live OUTSIDE the `cell_tissue` library, so they exercise
// only the public API surface — exactly what an adopter would use.
library;

import 'dart:collection';

import 'package:cell_tissue/cell_tissue.dart';

/// Builds one observer per tissue so mutation benchmarks measure the full
/// signal path (validation, mutation, broadcast, observer dispatch).
void observe(void Function(Pulse pulse) effect, {required Object tissue}) {
  Cell.observe(source: tissue as Cell, effect: effect);
}

/// A plain-collection control with a listener list, so the "reactive" cost
/// is compared against an equivalent hand-rolled notification.
class ListenerBox {
  final List<void Function()> listeners = [];

  void notify() {
    for (final listener in listeners) {
      listener();
    }
  }
}

/// Control fixture: plain List plus listener dispatch.
class PlainList extends ListenerBox {
  final List<int> values = [];
  void add(int v) {
    values.add(v);
    notify();
  }
}

/// Control fixture: plain Map plus listener dispatch.
class PlainMap extends ListenerBox {
  final Map<String, int> values = {};
  void put(String k, int v) {
    values[k] = v;
    notify();
  }
}

/// Control fixture: plain Set plus listener dispatch.
class PlainSet extends ListenerBox {
  final Set<int> values = {};
  void add(int v) {
    values.add(v);
    notify();
  }
}

/// Control fixture: plain Queue plus listener dispatch.
class PlainQueue extends ListenerBox {
  final Queue<int> values = Queue<int>();
  void addLast(int v) {
    values.addLast(v);
    notify();
  }
}

/// Control fixture: plain field plus listener dispatch.
class PlainValue extends ListenerBox {
  int value = 0;
  void set(int v) {
    value = v;
    notify();
  }
}

/// Creates each tissue shape with an empty state.
({
  TissueList<int> list,
  TissueMap<String, int> map,
  TissueSet<int> set,
  TissueQueue<int> queue,
  TissueValue<int> value
}) buildTissues() => (
      list: TissueList<int>(),
      map: TissueMap<String, int>(),
      set: TissueSet<int>(<int>[]),
      queue: TissueQueue<int>(),
      value: TissueValue<int>(0),
    );
