import 'dart:io';

void patch(String path, List<(String, String)> pairs) {
  final p = File(path);
  var s = p.readAsStringSync().replaceAll('\r\n', '\n');
  for (final (from, to) in pairs) {
    if (!s.contains(from)) {
      stderr.writeln('MISSING in $path: ${from.substring(0, 70)}');
    }
    s = s.replaceAll(from, to);
  }
  p.writeAsStringSync(s.replaceAll('\n', '\r\n'));
}

const bridgeSeeAlso = '/// ### See also\n'
    '/// - [completion], [streamCompletion], [streamChunks], [toolRouter],\n'
    '///   [guide/06-Bridges.md](guide/06-Bridges.md).\n'
    '///\n';
const bridgeAiGuide = '/// ## AI Agent Guide\n'
    '/// - Tool invocations are journaled io effects — replay never\n'
    '///   re-invokes them.\n'
    '/// - Router emissions carry the result pulse as the payload of the\n'
    '///   outer pulse; unwrap one level.\n'
    '///\n';

void main() {
  patch('lib/src/bridge.dart', [
    (
      '/// A capability the [toolRouter] can dispatch.\n'
      '///\n',
      '/// A capability the [toolRouter] can dispatch.\n'
      '///\n'
      '/// ### How it works\n'
      '/// A function from a `Map<String, dynamic>` argument payload to a\n'
      '/// `Future<Object?>` result. Exceptions become tool errors.\n'
      '///\n',
    ),
    (
      '///   `cognitive(...)` if per-tool decision receipts are required.\n'
      '///\n'
      '/// {@category Organ}\n'
      '/// {@category Bridge}\n'
      '///\n'
      '/// **Stability:** Stable since `cell_mind 1.0.0`.\n'
      'typedef Tool = Future<Object?> Function(Map<String, dynamic> args);',
      '///   `cognitive(...)` if per-tool decision receipts are required.\n'
      '///\n'
      '$bridgeSeeAlso'
      '$bridgeAiGuide'
      '/// {@category Organ}\n'
      '/// {@category Bridge}\n'
      '///\n'
      '/// **Stability:** Stable since `cell_mind 1.0.0`.\n'
      'typedef Tool = Future<Object?> Function(Map<String, dynamic> args);',
    ),
    (
      '/// - **Every emission is journaled** (`mind.completion` /\n'
      '///   `mind.completion.error`), so replays reconstruct the output\n'
      '///   without re-invoking the model.\n'
      '///\n'
      '/// {@category Organ}\n'
      '/// {@category Bridge}\n'
      '///\n'
      '/// **Stability:** Stable since `cell_mind 1.0.0`.\n'
      'Cell completion({',
      '/// - **Every emission is journaled** (`mind.completion` /\n'
      '///   `mind.completion.error`), so replays reconstruct the output\n'
      '///   without re-invoking the model.\n'
      '///\n'
      '$bridgeSeeAlso'
      '$bridgeAiGuide'
      '/// {@category Organ}\n'
      '/// {@category Bridge}\n'
      '///\n'
      '/// **Stability:** Stable since `cell_mind 1.0.0`.\n'
      'Cell completion({',
    ),
    (
      '/// Streaming LLM completions where each token should be observable in\n'
      '/// real time.\n'
      '///\n',
      '/// Streaming LLM completions where each token should be observable in\n'
      '/// real time.\n'
      '///\n'
      '/// ### How it works\n'
      '/// Subscribes to the stream, wraps each token as a governed\n'
      '/// `mind.stream.token` pulse, and journals the stream effect so\n'
      '/// replay never re-reads the upstream stream.\n'
      '///\n',
    ),
    (
      '/// - **`streamChunks` is the buffer-first sibling** — use it when\n'
      '///   per-token observability is not needed.\n'
      '///\n'
      '/// {@category Organ}\n'
      '/// {@category Bridge}\n'
      '///\n'
      '/// **Stability:** Stable since `cell_mind 1.0.0`.\n'
      'Cell streamCompletion({',
      '/// - **`streamChunks` is the buffer-first sibling** — use it when\n'
      '///   per-token observability is not needed.\n'
      '///\n'
      '$bridgeSeeAlso'
      '$bridgeAiGuide'
      '/// {@category Organ}\n'
      '/// {@category Bridge}\n'
      '///\n'
      '/// **Stability:** Stable since `cell_mind 1.0.0`.\n'
      'Cell streamCompletion({',
    ),
    (
      '/// A buffer-first stream bridge that groups tokens into chunks.\n'
      '///\n',
      '/// A buffer-first stream bridge that groups tokens into chunks.\n'
      '///\n'
      '/// ### How it works\n'
      '/// Accumulates tokens via `_bufferedChunks` until `bufferEvery` or\n'
      '/// `bufferSize` thresholds, then flushes one governed chunk pulse\n'
      '/// per buffer.\n'
      '///\n',
    ),
    (
      '/// - **Flush timestamps come from the journal clock** — replay\n'
      '///   fidelity, not wall time.\n'
      '///\n'
      '/// {@category Organ}\n'
      '/// {@category Bridge}\n'
      '///\n'
      '/// **Stability:** Stable since `cell_mind 1.0.0`.\n'
      'Cell streamChunks({',
      '/// - **Flush timestamps come from the journal clock** — replay\n'
      '///   fidelity, not wall time.\n'
      '///\n'
      '$bridgeSeeAlso'
      '$bridgeAiGuide'
      '/// {@category Organ}\n'
      '/// {@category Bridge}\n'
      '///\n'
      '/// **Stability:** Stable since `cell_mind 1.0.0`.\n'
      'Cell streamChunks({',
    ),
    (
      '/// - **`exhaust: true` drops in-flight arrivals.** The router is\n'
      '///   latest-request-wins by design; use `exhaust: false` (a future\n'
      '///   multi-tool dispatch) for queues.\n'
      '///\n'
      '/// {@category Organ}\n'
      '/// {@category Bridge}\n'
      '///\n'
      '/// **Stability:** Stable since `cell_mind 1.0.0`.\n'
      'Cell toolRouter({',
      '/// - **`exhaust: true` drops in-flight arrivals.** The router is\n'
      '///   latest-request-wins by design; use `exhaust: false` (a future\n'
      '///   multi-tool dispatch) for queues.\n'
      '///\n'
      '$bridgeSeeAlso'
      '$bridgeAiGuide'
      '/// {@category Organ}\n'
      '/// {@category Bridge}\n'
      '///\n'
      '/// **Stability:** Stable since `cell_mind 1.0.0`.\n'
      'Cell toolRouter({',
    ),
  ]);
}
