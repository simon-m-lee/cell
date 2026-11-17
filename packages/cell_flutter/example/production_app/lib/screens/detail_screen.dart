// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Detail screen — CellBuilder + CellErrorBoundary around a cell that can
// be invalidated (the same invalidated-cell failure mode the error
// boundary exists for).

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({required this.index, super.key});

  final int index;

  @override
  State<DetailScreen> createState() => DetailScreenState();
}

class DetailScreenState extends State<DetailScreen> {
  final _boundaryKey = GlobalKey<CellErrorBoundaryState>();
  late ValueCell<String> _titleCell = _goodTitle();

  ValueCell<String> _goodTitle() =>
      Cell.state<String>(initial: 'Detail ${widget.index + 1}').cell;

  @override
  void initState() {
    super.initState();
    
  }

  @override
  void dispose() {
    CellFlutterDevTools.unregister('detail.title');
    super.dispose();
  }

  /// Swaps the displayed cell for an invalidated one; the next
  /// [CellBuilder] build throws, and the boundary catches it.
  void _breakIt() {
    final policy = EphemeralPolicy<Cell>(
      eventLimit: 1,
      onEvent: (object, {required cell, required policy, arguments, user}) =>
          (events: policy.events + 1),
      onInvalidate: (nucleus) => true,
    );
    final head =
        Cell.governed(ephemeralPolicy: policy, context: Context.system);
    policy('use', cell: head);
    setState(
        () => _titleCell = ValueCell<String>(initial: 'broken', bind: head));
  }

  void _recover() {
    setState(() => _titleCell = _goodTitle());
    _boundaryKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail')),
      body: Center(
        child: CellErrorBoundary(
          key: _boundaryKey,
          onError: (error, stack) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Something broke: ${error.runtimeType}'),
              const SizedBox(height: 8),
              FilledButton(onPressed: _recover, child: const Text('Recover')),
            ],
          ),
          child: CellBuilder<String>(
            cell: _titleCell,
            builder: (_, v) => Text(v ?? ''),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Break it',
        onPressed: _breakIt,
        child: const Icon(Icons.warning),
      ),
    );
  }
}
