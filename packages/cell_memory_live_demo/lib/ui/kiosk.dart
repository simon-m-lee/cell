// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

import '../boundary/memory.dart';
import '../domain/books.dart';
import '../domain/pipeline.dart';

/// Which kiosk this window is; `--dart-define=KIOSK=B` for the twin.
const String kioskLabel = String.fromEnvironment('KIOSK', defaultValue: 'A');

/// The kiosk screen: the governed books, the order buttons, the Flow
/// pipeline feed, and the governance denial banner. Every visible value
/// is bound through `cell_flutter` — no `setState` anywhere.
class KioskScreen extends StatefulWidget {
  const KioskScreen({super.key, required this.books, this.boundary});

  final KioskBooks books;

  final MemoryBoundary? boundary;

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> {
  KioskBooks get books => widget.books;

  late final OrderPipeline pipeline = OrderPipeline(books);

  void _brew(String drink, double price) =>
      pipeline.order(OrderLine(drink: drink, price: price));

  void _restock(int amount) {
    final ok = books.restock(amount);
    if (!ok) {
      books.denials.emit('drain denied by governance: $amount');
    }
  }

  /// The sync button: settles every book's pending write. On a
  /// `MemoryConflict` (the other kiosk won the race) the boundary adopts
  /// the winner and reports its revision and generation.
  Future<void> _sync() async {
    final boundary = widget.boundary;
    if (boundary == null) return;
    await boundary.syncAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Kiosk Twins — Phase D network'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                  child: Text('Kiosk $kioskLabel',
                      style: Theme.of(context).textTheme.titleMedium)),
            ),
          ]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _DenialBanner(cell: books.denials.cell),
            const SizedBox(height: 8),
            Row(
              children: [
                _BookCard(
                  label: 'Stock (Tissue)',
                  child: CellBuilder<int>(
                    cell: books.stockView.cell,
                    builder: (context, value) =>
                        Text('${value ?? 0}', style: _numberStyle(context)),
                  ),
                ),
                const SizedBox(width: 12),
                _BookCard(
                  label: 'Cash (Tissue)',
                  child: CellBuilder<double>(
                    cell: books.cashView.cell,
                    builder: (context, value) => Text(
                      '\$${(value ?? 0).toStringAsFixed(2)}',
                      style: _numberStyle(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _BookCard(
                  label: 'Orders (Cell)',
                  child: CellBuilder<int>(
                    cell: books.orders.cell,
                    builder: (context, value) =>
                        Text('${value ?? 0}', style: _numberStyle(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _brew('flat white', 2.50),
                  icon: const Icon(Icons.coffee),
                  label: const Text('Brew Flat White'),
                ),
                FilledButton.icon(
                  onPressed: () => _brew('cold brew', 3.00),
                  icon: const Icon(Icons.ac_unit),
                  label: const Text('Brew Cold Brew'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _restock(6),
                  icon: const Icon(Icons.add_box),
                  label: const Text('Restock +6'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _restock(-99),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Drain −99 (governance)'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.boundary == null ? null : _sync,
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync books (save)'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Flow pipeline (newest first)',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Expanded(
                        child: CellListView<StageEvent>.builder(
                          cell: pipeline.feed.cell,
                          reverse: true,
                          itemBuilder: (context, event, index) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.bolt),
                            title: Text('${event.stage} — ${event.drink}'),
                            subtitle: Text(
                                '\$${event.price.toStringAsFixed(2)}'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The governance denial banner: empty until a denial pulse arrives.
class _DenialBanner extends StatelessWidget {
  const _DenialBanner({required this.cell});

  final Cell cell;

  @override
  Widget build(BuildContext context) {
    return CellValueBuilder<String>(
      cell: cell,
      builder: (context, denial) {
        if (denial == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            denial,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer),
          ),
        );
      },
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.label, required this.child});

  final String label;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle? _numberStyle(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall;
