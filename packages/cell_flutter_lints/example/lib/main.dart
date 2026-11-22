// The pub.dev example entry point for cell_flutter_lints.
//
// This package ships lint rules, not widgets, so the example is a
// deliberately plain counter app: it must stay free of the four
// anti-patterns the rules guard (creation in build, unkeyed hook
// builders, forgotten dispose, selector misuse) so the example itself
// always analyzes cleanly. The expect_lint fixtures in this directory
// (`lib/*_fixture.dart`) demonstrate each violation on purpose.

import 'package:flutter/material.dart';

void main() => runApp(const LintsExampleApp());

/// A minimal app that follows every `cell_flutter_lints` rule.
class LintsExampleApp extends StatelessWidget {
  const LintsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'cell_flutter_lints example',
      home: CounterScreen(),
    );
  }
}

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('cell_flutter_lints example')),
      body: Center(
        child: Text('Count: $_count'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _count++),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
