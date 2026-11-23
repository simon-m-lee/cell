// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flow/cell_flow.dart';

import 'books.dart';

/// One pipeline stage event, newest first in the feed.
typedef StageEvent = ({String stage, String drink, double price});

/// The order pipeline: validation → reserve → settle → receipt.
///
/// Each stage is a [FlowInstruction] gate — a synchronous logic gate whose
/// closure either returns the evolved pulse (`withStep` stamps the stage
/// for provenance) or `null` to drop it. The reserve gate is the decision
/// gate the framework documentation says belongs in a Cell-variant demo:
/// it consults the Tissue stock book and refuses what governance would
/// refuse, without a second write path.
///
/// The [feed] records every stage a pulse passed, in pipeline order
/// (validated first, receipted last) — the UI reverses the list to show
/// the newest stage first. The denial ingress carries refusals to the UI
/// banner.
class OrderPipeline {
  OrderPipeline(this.books) {
    final validatedGate =
        FlowInstruction<Cell, Pulse<OrderLine>, Pulse<OrderLine>>(
      (pulse, {cell, user}) {
        final order = pulse.payload;
        if (order == null || order.drink.trim().isEmpty) return null;
        return pulse.withStep('validated');
      },
      user: 'validate',
    );
    validated = validatedGate.toHandle(source: ordersIn.cell);

    final reservedGate =
        FlowInstruction<Cell, Pulse<OrderLine>, Pulse<OrderLine>>(
      (pulse, {cell, user}) {
        final order = pulse.payload;
        if (order == null) return null;
        if ((books.stock.value ?? 0) < 1) {
          books.denials.emit('out of stock: ${order.drink}');
          return null;
        }
        return pulse.withStep('reserved');
      },
      user: 'reserve',
    );
    reserved = reservedGate.toHandle(source: validated.cell);

    final settledGate =
        FlowInstruction<Cell, Pulse<OrderLine>, Pulse<OrderLine>>(
      (pulse, {cell, user}) {
        final order = pulse.payload;
        if (order == null) return null;
        if (!books.settle(order)) {
          books.denials.emit('governance denied ${order.drink}');
          return null;
        }
        return pulse.withStep('settled');
      },
      user: 'settle',
    );
    settled = settledGate.toHandle(source: reserved.cell);

    final receiptedGate =
        FlowInstruction<Cell, Pulse<OrderLine>, Pulse<OrderLine>>(
      (pulse, {cell, user}) => pulse.withStep('receipted'),
      user: 'receipt',
    );
    receipted = receiptedGate.toHandle(source: settled.cell);

    // One observer per gate cell records the stage into the feed. The
    // observers are the pipeline's side effects; the gates stay pure
    // decisions and mutations only happen in `settle`.
    observers.add(_record(validated.cell, 'validated'));
    observers.add(_record(reserved.cell, 'reserved'));
    observers.add(_record(settled.cell, 'settled'));
    observers.add(_record(receipted.cell, 'receipted'));
  }

  final KioskBooks books;

  /// Raw order entry: the UI and (later) the Mock MCP agent emit here.
  final IngressHandle<OrderLine> ordersIn = Cell.ingress<OrderLine>();

  /// Stage feed, newest first.
  final StateHandle<List<StageEvent>> feed = Cell.state<List<StageEvent>>(
    initial: const [],
  );

  late final FlowHandle validated;
  late final FlowHandle reserved;
  late final FlowHandle settled;
  late final FlowHandle receipted;

  final List<dynamic> observers = [];

  EgressHandle<Pulse> _record(Cell source, String stage) => Cell.observe(
        source: source,
        effect: (Pulse pulse) {
          final order = pulse.payload as OrderLine;
          feed.update([
            (stage: stage, drink: order.drink, price: order.price),
            ...feed.cell.value ?? const [],
          ]);
        },
      );

  /// Emits one order line into the pipeline.
  bool order(OrderLine line) => ordersIn.emit(line);
}
