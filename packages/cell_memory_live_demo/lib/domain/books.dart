// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_tissue/cell_tissue.dart';

/// One order line a kiosk can brew.
class OrderLine {
  const OrderLine({required this.drink, required this.price});

  final String drink;

  final double price;
}

/// The kiosk's governed books.
///
/// **Tissue** owns the invariants: `stock` and `cash` are [TissueValue]s
/// whose `TestTissue` rule rejects any non-negative violation before the
/// value ever changes. **Cell** owns the orders counter. Later phases
/// attach a memory boundary to each of these three books; for now they
/// are process-local, which is exactly the state Phase C persists.
class KioskBooks {
  KioskBooks({int initialStock = 24, double initialCash = 0})
      : stockView = Cell.state<int>(initial: initialStock),
        cashView = Cell.state<double>(initial: initialCash),
        stock = TissueValue.create<int, TissueValue<int>>(
          container: Container.finalValue,
          value: initialStock,
          testRule: TestTissue<int, TissueValue<int>>(
            (object, {dynamic host, dynamic arguments, dynamic user}) =>
                _nonNegativeRule(object, arguments),
            user: 'non-negative',
          ),
        ),
        cash = TissueValue.create<double, TissueValue<double>>(
          container: Container.finalValue,
          value: initialCash,
          testRule: TestTissue<double, TissueValue<double>>(
            (object, {dynamic host, dynamic arguments, dynamic user}) =>
                _nonNegativeRule(object, arguments),
            user: 'non-negative',
          ),
        );

  /// The framework invokes a `TestTissue` rule through several shapes:
  /// the action shape (the proposed value rides in
  /// `arguments.positionalArguments.first`), the element shape (the value
  /// is the `object` itself and `arguments` is a mutation-vector
  /// `Function`), and the link shape (the `object` is the downstream
  /// [Cell] an observer wants to register). A link is always allowed;
  /// a numeric proposal must be non-negative; anything else fails
  /// closed — and the rule never throws, because a throwing rule is an
  /// integrity failure, not a verdict.
  static bool _nonNegativeRule(dynamic object, dynamic arguments) {
    final candidate = _candidate(object, arguments);
    if (candidate is Cell) return true;
    return candidate is num && candidate >= 0;
  }

  /// Extracts the proposed value from the action or element shape.
  static dynamic _candidate(dynamic object, dynamic arguments) {
    if (arguments is Record) {
      final positional =
          (arguments as dynamic).positionalArguments as dynamic;
      if (positional is List && positional.isNotEmpty) {
        return positional.first;
      }
    }
    return object;
  }

  final TissueValueBase<int, TissueValue<int>> stock;

  final TissueValueBase<double, TissueValue<double>> cash;

  final StateHandle<int> orders = Cell.state<int>(initial: 0);

  /// Value projections of the tissue books, for the UI.
  ///
  /// These are plain state cells maintained by the book's single
  /// mutation path: a governed `TissueValue` broadcasts
  /// `elementUpdated` records (not raw values), and its internal
  /// principal rejects downstream observer links when a typed
  /// `TestTissue` rule is attached — so the UI mirrors the committed
  /// book after each accepted mutation instead of linking into the
  /// tissue. The books remain the only source of truth.
  final StateHandle<int> stockView;

  final StateHandle<double> cashView;

  /// Governance denials, for the UI banner. The Tissue gate is the only
  /// thing that decides; this ingress just carries the news.
  final IngressHandle<String> denials = Cell.ingress<String>();

  /// Governed restock: `set` returns false when the `TestTissue` rule
  /// rejects the new value (a negative amount), and the books stay
  /// unchanged. True restocks always pass. A no-op (the same value) is
  /// not a denial.
  bool restock(int amount) {
    final next = (stock.value ?? 0) + amount;
    if (stock.value == next) return true;
    if (!stock.set(next)) return false;
    stockView.update(next);
    return true;
  }

  /// Settles one order line: stock −1, cash +price, orders +1.
  ///
  /// Each mutation goes through its own governed gate; the caller (the
  /// Flow pipeline's reserve gate) has already checked availability, so a
  /// false here means the pipeline let something impossible through —
  /// never expected in this phase.
  bool settle(OrderLine line) {
    final nextStock = (stock.value ?? 0) - 1;
    if (!stock.set(nextStock)) return false;
    stockView.update(nextStock);
    final nextCash = (cash.value ?? 0) + line.price;
    if (!cash.set(nextCash)) return false;
    cashView.update(nextCash);
    orders.update((orders.cell.value ?? 0) + 1);
    return true;
  }

  /// Adopts a restored stock value through the same governed gate as any
  /// other mutation. Returns false when the restored value violates the
  /// invariant — a corrupt record must not be adopted. An identical
  /// no-op is adoption, not rejection.
  bool adoptStock(int loaded) {
    if (stock.value == loaded) {
      stockView.update(loaded);
      return true;
    }
    if (!stock.set(loaded)) return false;
    stockView.update(loaded);
    return true;
  }

  /// Adopts a restored cash value through the governed gate.
  bool adoptCash(double loaded) {
    if (cash.value == loaded) {
      cashView.update(loaded);
      return true;
    }
    if (!cash.set(loaded)) return false;
    cashView.update(loaded);
    return true;
  }

  /// Adopts a restored orders value.
  void adoptOrders(int loaded) => orders.update(loaded);
}
