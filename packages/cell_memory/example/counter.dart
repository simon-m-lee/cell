// A counter executable for cell_memory.
//
// Cell.ingress is the only way a count enters the graph. Each accepted
// pulse increments Cell.state. FileMemoryStore loads the last total when
// the process starts and persists the new total before it exits.
//
//   dart run bin/counter.dart            # add 1, print the total
//   dart run bin/counter.dart 5          # add 5
//   dart run bin/counter.dart --get      # print the stored total
//   dart run bin/counter.dart --dir /tmp/counts 3
//
// The store is a directory of JSON envelopes (default: ./counter_data).

import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_memory/cell_memory.dart';
import 'package:cell_memory/cell_memory_io.dart';

Future<void> main(List<String> args) async {
  final options = _parse(args);
  if (options == null) {
    exitCode = 64;
    return;
  }

  final counter = Cell.state<int>(
    initial: 0,
    // Each ingress pulse is a delta. evolve adds it to the retained total.
    evolve: (host, input) {
      final delta = input.payload;
      if (delta is! int) return null;
      return Pulse<int>((host.value ?? 0) + delta);
    },
  );

  // External fact: "increment by n". Stateless; the total lives in state.
  final increments = Cell.ingress<int>();

  // update() drops a payload that == the current value before evolve runs,
  // so a second +1 would be ignored. ingest is the state's ingress and does
  // not apply that equality check. The futures are chained so each delta is
  // applied, and the file flush sees the final total.
  var applied = Future<void>.value();
  final bridge = Cell.observe(
    source: increments.cell,
    effect: (Pulse pulse) {
      final delta = pulse.payload;
      if (delta is! int) return;
      applied = applied.then((_) => counter.ingest(Pulse<int>(delta)));
    },
  );

  final store = FileMemoryStore.directory(options.directory);
  final memory = await remember<int>(
    counter.cell,
    id: 'counter',
    store: store,
    codec: JsonMemoryCodec<int>.identity(),
    project: (pulse) => pulse.payload as int?,
    policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
    ownsStore: true,
    // seed runs after load and before attach, so restoring the total does
    // not write it back. State starts at 0, and evolve adds, so the stored
    // total is itself the delta that lands on that total.
    seed: (loaded) {
      if (loaded == null || loaded == counter.cell.value) return;
      counter.update(loaded);
    },
  );

  final loaded = counter.cell.value;
  for (var i = 0; i < options.steps; i++) {
    final accepted = increments.emit(1);
    if (!accepted) {
      stderr.writeln('increment rejected');
      exitCode = 1;
      break;
    }
  }
  await applied;

  final total = counter.cell.value;
  // close flushes a dirty value and releases the file store.
  await memory.close();
  bridge.stop();

  stdout.writeln('loaded $loaded');
  stdout.writeln('counter $total');
  stdout.writeln('store ${options.directory.path}${Platform.pathSeparator}counter.json');
}

final class _Options {
  const _Options({required this.steps, required this.directory});

  final int steps;
  final Directory directory;
}

_Options? _parse(List<String> args) {
  var getOnly = false;
  Directory? directory;
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--get') {
      getOnly = true;
    } else if (arg == '--dir') {
      if (i + 1 >= args.length) {
        stderr.writeln('--dir needs a path');
        return null;
      }
      directory = Directory(args[++i]);
    } else if (arg == '--help' || arg == '-h') {
      stdout.writeln(
        'Usage: dart run bin/counter.dart [--get] [--dir path] [increments]',
      );
      exit(0);
    } else if (arg.startsWith('-')) {
      stderr.writeln('unknown option $arg');
      return null;
    } else {
      positional.add(arg);
    }
  }

  if (positional.length > 1) {
    stderr.writeln('increments must be a single non-negative integer');
    return null;
  }
  var steps = getOnly ? 0 : 1;
  if (positional.isNotEmpty) {
    final parsed = int.tryParse(positional.first);
    if (parsed == null || parsed < 0) {
      stderr.writeln('increments must be a single non-negative integer');
      return null;
    }
    steps = parsed;
  }
  return _Options(
    steps: steps,
    directory: directory ?? Directory('counter_data'),
  );
}
