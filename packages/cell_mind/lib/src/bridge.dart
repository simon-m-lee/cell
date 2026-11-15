// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// A capability the [toolRouter] can dispatch.
///
/// ### How it works
/// A function from a `Map<String, dynamic>` argument payload to a
/// `Future<Object?>` result. Exceptions become tool errors.
///
/// ### When to use
/// Provided to `toolRouter(tools: {'verb': fn, ...})`. The map key is
/// the verb the model chooses; the function is what the user executes.
///
/// ### Non-obvious
/// - **Not a `Cell`.** Tools are functions; their audit comes from the
///   journal effects (`MindToolDispatchEffect`, `MindToolResultEffect`,
///   `MindToolErrorEffect`) and the pulse provenance. Wrap a tool in
///   `cognitive(...)` if per-tool decision receipts are required.
///
/// ### See also
/// - [completion], [streamCompletion], [streamChunks], [toolRouter],
///   `guide/06-Bridges.md`.
///
/// ## AI Agent Guide
/// - Tool invocations are journaled io effects — replay never
///   re-invokes them.
/// - Router emissions carry the result pulse as the payload of the
///   outer pulse; unwrap one level.
///
/// {@category Organ}
/// {@category Bridge}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
typedef Tool = Future<Object?> Function(Map<String, dynamic> args);

/// Bridges a single-shot [Future] to a governed cell.
///
/// ### When to use
/// The primary bridge for LLM chat completions, single API calls, or
/// any asynchronous operation whose result is one `String`.
///
/// ### How it works
/// 1. Builds a governed inference context from [actor], [prompt],
///    [confidence], and [strategy].
/// 2. Creates an ingress cell with that context.
/// 3. Awaits [future]; on success emits a governed
///    `mind.completion.result` pulse; on error emits a
///    `mind.completion.error` pulse and journals the error.
/// 4. Returns the ingress cell (composable with `cognitive()`).
///
/// ### Non-obvious
/// - **`confidence` is required.** Ungoverned LLM calls belong outside
///   `cell_mind` — use `Cell.fromFuture` directly.
/// - **Every emission is journaled** (`mind.completion` /
///   `mind.completion.error`), so replays reconstruct the output
///   without re-invoking the model.
///
/// ### See also
/// - [completion], [streamCompletion], [streamChunks], [toolRouter],
///   `guide/06-Bridges.md`.
///
/// ## AI Agent Guide
/// - Tool invocations are journaled io effects — replay never
///   re-invokes them.
/// - Router emissions carry the result pulse as the payload of the
///   outer pulse; unwrap one level.
///
/// {@category Organ}
/// {@category Bridge}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Cell completion({
  required Future<String> future,
  required String actor,
  required String prompt,
  required double confidence,
  required EffectJournal journal,
  PulseContext? baseContext,
  ReasoningStrategy strategy = ReasoningStrategy.probabilistic,
}) {
  final context = _aiContext(
    baseContext: baseContext,
    actor: actor,
    reason: prompt,
    confidence: confidence,
    strategy: strategy,
    purpose: 'COMPLETION',
  );

  final cell = _emittingCell();
  unawaited(_recordBridgeEffect(
    journal,
    MindCompletionEffect(
      actor: actor,
      prompt: prompt,
      confidence: confidence,
      strategy: strategy,
      at: journal.clock(),
    ).toMap(),
  ));

  unawaited(future.then((value) {
    _emit(
        cell,
        Pulse<String>.governed(
          payload: value,
          type: 'mind.completion.result',
          context: context,
        ));
  }).catchError((Object e, StackTrace st) {
    _emit(
        cell,
        Pulse<String>.governed(
          payload: null,
          type: 'mind.completion.error',
          context: context,
        ));
    unawaited(_recordBridgeEffect(
      journal,
      MindCompletionErrorEffect(
        error: e.toString(),
        stackTrace: st.toString(),
        at: journal.clock(),
      ).toMap(),
    ));
  }));

  return cell;
}

/// Bridges a [Stream] of tokens to per-token governed pulses.
///
/// ### When to use
/// Streaming LLM completions where each token should be observable in
/// real time.
///
/// ### How it works
/// Subscribes to the stream, wraps each token as a governed
/// `mind.stream.token` pulse, and journals the stream effect so
/// replay never re-reads the upstream stream.
///
/// ### Non-obvious
/// - **Default confidence is 0.5** — streams do not declare their own
///   confidence. Override via [baseContext] for governed streams.
/// - **`cancelOnError` controls error propagation.** `false` continues
///   after an error; `true` closes the stream.
///
/// ### See also
/// - [completion], [streamCompletion], [streamChunks], [toolRouter],
///   `guide/06-Bridges.md`.
///
/// ## AI Agent Guide
/// - Tool invocations are journaled io effects — replay never
///   re-invokes them.
/// - Router emissions carry the result pulse as the payload of the
///   outer pulse; unwrap one level.
///
/// {@category Organ}
/// {@category Bridge}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Cell streamCompletion({
  required Stream<String> tokens,
  required String actor,
  required String prompt,
  required EffectJournal journal,
  PulseContext? baseContext,
  bool cancelOnError = false,
}) {
  final context = _aiContext(
    baseContext: baseContext,
    actor: actor,
    reason: prompt,
    confidence: 0.5,
    strategy: ReasoningStrategy.probabilistic,
    purpose: 'STREAM_COMPLETION',
  );
  final cell = _emittingCell();
  unawaited(() async {
    try {
      await for (final token in tokens) {
        await _recordBridgeEffect(
          journal,
          MindStreamChunkEffect(
            actor: actor,
            chunk: token,
            at: journal.clock(),
          ).toMap(),
        );
        await cell.emit(
          Pulse<String>.governed(
            payload: token,
            type: 'mind.stream.token',
            context: context,
          ),
        );
      }
    } catch (e, st) {
      await _recordBridgeEffect(
        journal,
        MindCompletionErrorEffect(
          error: e.toString(),
          stackTrace: st.toString(),
          at: journal.clock(),
        ).toMap(),
      );
      await cell.emit(
        Pulse<String>.governed(
          payload: null,
          type: 'mind.stream.error',
          context: context,
        ),
      );
      if (cancelOnError) rethrow;
    }
  }());
  return cell;
}

/// Buffers chunks into batched pulses.
///
/// ### When to use
/// Streaming output where the downstream policy is expensive per
/// pulse. Buffering reduces the pulse rate without losing tokens.
///
/// ### How it works
/// Accumulates chunks until the `buffer` window, then flushes one
/// governed chunk pulse per window. `buffer: Duration.zero`
/// disables buffering.
///
/// ### Non-obvious
/// - **Not lossy.** Unlike throttling, every chunk is retained (joined
///   within the buffer window). No tokens are dropped.
/// - **`buffer: Duration.zero`** disables buffering (per-chunk,
///   matching [streamCompletion]).
///
/// ### See also
/// - [completion], [streamCompletion], [streamChunks], [toolRouter],
///   `guide/06-Bridges.md`.
///
/// ## AI Agent Guide
/// - Tool invocations are journaled io effects — replay never
///   re-invokes them.
/// - Router emissions carry the result pulse as the payload of the
///   outer pulse; unwrap one level.
///
/// {@category Organ}
/// {@category Bridge}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Cell streamChunks({
  required Stream<String> chunks,
  required String actor,
  required EffectJournal journal,
  Duration buffer = Duration.zero,
}) {
  final stream =
      buffer == Duration.zero ? chunks : _bufferedChunks(chunks, buffer);
  final context = _aiContext(
    baseContext: null,
    actor: actor,
    reason: 'STREAM_CHUNKS',
    confidence: 0.5,
    strategy: ReasoningStrategy.probabilistic,
    purpose: 'STREAM_CHUNKS',
  );
  final cell = _emittingCell();
  unawaited(() async {
    try {
      await for (final chunk in stream) {
        await _recordBridgeEffect(
          journal,
          MindStreamChunkEffect(
            actor: actor,
            chunk: chunk,
            at: journal.clock(),
          ).toMap(),
        );
        await cell.emit(
          Pulse<String>.governed(
            payload: chunk,
            type: 'mind.stream.chunk',
            context: context,
          ),
        );
      }
    } catch (e, st) {
      await _recordBridgeEffect(
        journal,
        MindCompletionErrorEffect(
          error: e.toString(),
          stackTrace: st.toString(),
          at: journal.clock(),
        ).toMap(),
      );
      await cell.emit(
        Pulse<String>.governed(
          payload: null,
          type: 'mind.stream.error',
          context: context,
        ),
      );
    }
  }());
  return cell;
}

/// Closed-verb tool router. Dispatches `{verb, args}` payloads carried
/// by pulses to registered tools.
///
/// ### When to use
/// The flagship bridge — LLM tool calling, function calling, or any
/// closed-verb dispatch where the model chooses from a known set.
///
/// ### How it works
/// The [source] cell emits governed [Pulse]s whose payloads are
/// `{verb, args}` maps. The router:
/// 1. Validates: verb known, confidence ≥ [minConfidence], args a map.
/// 2. Rejections emit distinct pulses:
///    `mind.tool.rejected.unknown-verb`,
///    `mind.tool.rejected.low-confidence`,
///    `mind.tool.rejected.invalid-args`.
/// 3. Default dispatch (`fireAndForget: false`) awaits the tool and
///    emits `mind.tool.result.<verb>` or `mind.tool.error.<verb>`.
/// 4. `fireAndForget: true` dispatches without awaiting and emits
///    `mind.tool.dispatched.<verb>`; tool errors are swallowed.
///
/// ### Non-obvious
/// - **The router's emissions carry the result PULSE as payload.**
///   Consumers unwrap once: `final inner = p.payload as Pulse;` — then
///   read `inner.type` and `inner.payload` (the `{verb, result}` map).
///   Chaining routers requires a model step that maps the result into
///   the next call (see `test/bridge/integration_test.dart`).
/// - **`exhaust: true`** (hard-coded) serializes dispatches — and
///   DROPS arrivals that occur while a tool is running. For LLM tool
///   loops this is correct (the model waits for the result before the
///   next call); emit sequentially.
/// - **The tool invocation is journaled** (`mind.tool.call.<verb>`):
///   replay serves the recorded output and does NOT re-invoke the tool.
/// - **All rejection classes are pulses, never exceptions.** The
///   router fails closed without crashing the pipeline.
/// - **Order matters**: unknown verb beats low confidence beats
///   invalid args — first match wins.
/// - Every path is journaled (dispatch/result/error/rejected).
///
/// {@category Organ}
/// {@category Bridge}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
/// ### See also
/// - The owning module guide and the type paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
Cell toolRouter({
  required Cell source,
  required Map<String, Tool> tools,
  required String actor,
  required EffectJournal journal,
  double minConfidence = 0.85,
  bool fireAndForget = false,
}) {
  return Cell.asyncMap<Pulse, Pulse>(
    source,
    (pulse, {required journal}) async {
      final payload = pulse.payload;
      if (payload is! Map) {
        await _reject(
          journal,
          verb: '<not-a-map>',
          reason: 'invalid-args',
          details: {'reason': 'payload-not-a-map'},
        );
        return Pulse<Object>.governed(
          payload: {'reason': 'payload-not-a-map'},
          type: 'mind.tool.rejected.invalid-args',
          context: pulse.context,
        );
      }
      final verb = payload['verb'];
      final args = payload['args'];

      // 1. Unknown verb.
      if (verb is! String || !tools.containsKey(verb)) {
        await _reject(
          journal,
          verb: verb?.toString() ?? '<null>',
          reason: 'unknown-verb',
          details: {},
        );
        return Pulse<Object>.governed(
          payload: {'verb': verb, 'reason': 'unknown-verb'},
          type: 'mind.tool.rejected.unknown-verb',
          context: pulse.context,
        );
      }

      // 2. Low confidence.
      final conf = pulse.context.confidence;
      if (conf != null && conf < minConfidence) {
        await _reject(
          journal,
          verb: verb,
          reason: 'low-confidence',
          details: {'confidence': conf, 'threshold': minConfidence},
        );
        return Pulse<Object>.governed(
          payload: {
            'verb': verb,
            'confidence': conf,
            'threshold': minConfidence,
          },
          type: 'mind.tool.rejected.low-confidence',
          context: pulse.context,
        );
      }

      // 3. Invalid args.
      if (args is! Map) {
        await _reject(
          journal,
          verb: verb,
          reason: 'invalid-args',
          details: {'reason': 'args-not-a-map'},
        );
        return Pulse<Object>.governed(
          payload: {'verb': verb, 'reason': 'invalid-args'},
          type: 'mind.tool.rejected.invalid-args',
          context: pulse.context,
        );
      }
      final typedArgs = args.cast<String, dynamic>();

      // 4. Dispatch.
      if (fireAndForget) {
        unawaited(
          tools[verb]!(typedArgs).then<void>(
            (_) {},
            onError: (Object _, StackTrace __) {},
          ),
        );
        await _recordBridgeEffect(
          journal,
          MindToolDispatchEffect(
            actor: actor,
            verb: verb,
            args: typedArgs,
            at: journal.clock(),
          ).toMap(),
        );
        return Pulse<Object>.governed(
          payload: pulse.payload,
          type: 'mind.tool.dispatched.$verb',
          context: pulse.context,
        );
      }

      // Journal-derived timestamps throughout: replays restore the
      // same clock sequence, so both `at` and `duration` reproduce
      // exactly (wall-clock durations would never fingerprint-match).
      // The duration is computed from MILLISECOND-truncated instants —
      // the recording journal stores epoch millis, and replay restores
      // exactly that precision; mixing in sub-millisecond wall-clock
      // leftovers made `durationMillis` flap at ms boundaries.
      final startAt = _clockMs(journal);
      await _recordBridgeEffect(
        journal,
        MindToolDispatchEffect(
          actor: actor,
          verb: verb,
          args: typedArgs,
          at: startAt,
        ).toMap(),
      );
      try {
        // The tool invocation is a journaled io: on replay the recorded
        // output is served and the tool is NOT re-invoked.
        final result = await journal.io<Object?>(
          label: 'mind.tool.call.$verb',
          input: typedArgs,
          run: () => tools[verb]!(typedArgs),
          serializeOutput: _encodable,
        );
        final endAt = _clockMs(journal);
        await _recordBridgeEffect(
          journal,
          MindToolResultEffect(
            verb: verb,
            result: result,
            duration: endAt.difference(startAt),
            at: endAt,
          ).toMap(),
        );
        return Pulse<Object>.governed(
          payload: {'verb': verb, 'result': result},
          type: 'mind.tool.result.$verb',
          context: pulse.context,
        );
      } catch (e, st) {
        await _recordBridgeEffect(
          journal,
          MindToolErrorEffect(
            verb: verb,
            error: e.toString(),
            stackTrace: st.toString(),
            at: journal.clock(),
          ).toMap(),
        );
        return Pulse<Object>.governed(
          payload: {'verb': verb, 'error': e.toString()},
          type: 'mind.tool.error.$verb',
          context: pulse.context,
        );
      }
    },
    journal: journal,
    exhaust: true,
  );
}

Future<void> _reject(
  EffectJournal journal, {
  required String verb,
  required String reason,
  required Map<String, dynamic> details,
}) =>
    _recordBridgeEffect(
      journal,
      MindToolRejectedEffect(
        verb: verb,
        reason: reason,
        details: details,
        at: journal.clock(),
      ).toMap(),
    );

/// An `OpenCell` pass-through: the public surface on the live
/// substrate that can `emit(Pulse)` with full provenance. Used by the
/// completion/stream bridges so emitted pulses carry the governed
/// inference context.
OpenCell _emittingCell() => OpenCell.perform(
      Cell.ingress<Object?>().cell,
      (on, pulse, {user}) => pulse,
    );

/// Fire-and-forget emission: `OpenCell.emit` returns `FutureOr<Pulse?>`,
/// which `unawaited` cannot take directly.
void _emit(OpenCell cell, Pulse pulse) {
  unawaited(
    Future.sync(() => cell.emit(pulse)).then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    ),
  );
}

/// Builds the governed inference context used by the bridges. The live
/// substrate has no `PulseContext.aiInference`; it is composed from
/// the standard provenance entries.
PulseContext _aiContext({
  required PulseContext? baseContext,
  required String actor,
  required String reason,
  required double confidence,
  required ReasoningStrategy strategy,
  required String purpose,
}) {
  final entries = <GovernanceEntry<Provenance, dynamic>>[
    Provenance.actor.entry(actor),
    Provenance.reason.entry(reason),
    Provenance.confidence.entry(confidence),
    Provenance.strategy.entry(strategy),
    Provenance.purpose.entry(purpose),
  ];
  final base = baseContext;
  if (base == null) return PulseContext.fromEntries(entries);
  return PulseContext.fromEntries(entries, parent: base);
}

/// Returns [journal.clock()] truncated to milliseconds — the precision
/// the replay journal restores. Durations and timestamps derived from
/// journal clocks must use this form, or sub-millisecond wall-clock
/// leftovers flap the effect fingerprints at ms boundaries.
DateTime _clockMs(EffectJournal journal) {
  final t = journal.clock();
  return DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch);
}
