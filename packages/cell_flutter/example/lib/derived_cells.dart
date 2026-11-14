// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DerivedCellsApp());

class DerivedCellsApp extends StatefulWidget {
  const DerivedCellsApp({super.key});
  @override
  State<DerivedCellsApp> createState() => _DerivedCellsAppState();
}

class _DerivedCellsAppState extends State<DerivedCellsApp> {
  late final StateHandle<int> _price;
  late final StateHandle<int> _tax;
  late final Cell _total;

  @override
  void initState() {
    super.initState();
    _price = Cell.state<int>(initial: 100);
    _tax = Cell.state<int>(initial: 10);
    _total = Cell.synthesis<Pulse<int>>(
      [_price.cell, _tax.cell],
      aggregator: (cells, _) {
        final total = cells.fold<int>(0, (sum, c) {
          final v = c is ValueCell<int> ? c.value ?? 0 : 0;
          return sum + v;
        });
        return Pulse<int>(total);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Derived cells')),
        body: Column(
          children: [
            // CellBuilder over a ValueCell — the cheap path.
            CellBuilder<int>(
              cell: _price.cell,
              builder: (_, v) =>
                  Semantics(label: 'Price', child: Text('Price: $v')),
            ),
            CellBuilder<int>(
              cell: _tax.cell,
              builder: (_, v) =>
                  Semantics(label: 'Tax', child: Text('Tax: $v')),
            ),
            // CellValueBuilder over a derived Cell — the bridge path.
            // `initial` seeds the first frame: synthesis emits only on
            // pulses, so without it the mirror starts at null.
            CellValueBuilder<int>(
              cell: _total,
              initial: 110,
              builder: (_, v) => Semantics(
                label: 'Total',
                child: Text(
                  'Total: $v',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
