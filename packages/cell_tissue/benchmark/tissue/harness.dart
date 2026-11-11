// Shared fixtures for the benchmark/tissue suite.
library;

import 'package:cell_tissue/cell_tissue.dart';

/// Builds each empty tissue shape.
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

/// Attaches [n] observers to a tissue through the public observe API.
void attachObservers(Tissue<int> tissue, int n) {
  for (var i = 0; i < n; i++) {
    Cell.observe(source: tissue, effect: (_) {});
  }
}

/// A plain growable list with a manual listener registry — the feature-fair
/// control for `TissueList` (reactivity without governance).
class PlainList {
  final List<int> store = <int>[];
  final List<void Function()> listeners = <void Function()>[];

  void add(int e) {
    store.add(e);
    for (final l in listeners) {
      l();
    }
  }
}

/// A plain map with a manual listener registry — the feature-fair control
/// for `TissueMap`.
class PlainMap {
  final Map<String, int> store = <String, int>{};
  final List<void Function()> listeners = <void Function()>[];

  void put(String k, int v) {
    store[k] = v;
    for (final l in listeners) {
      l();
    }
  }
}

/// A plain set with a manual listener registry — the feature-fair control
/// for `TissueSet`.
class PlainSet {
  final Set<int> store = <int>{};
  final List<void Function()> listeners = <void Function()>[];

  void add(int e) {
    store.add(e);
    for (final l in listeners) {
      l();
    }
  }
}
