// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// The recording rule: principal validation, then the bool policy, then
/// (0.4.0) the verdict policy — recording every decision.
///
/// ### How it works
/// 1. Runs `principalRule.call(...)` — the cell's original rule.
///    Reject → records `Reject('principal-rejected')`.
/// 2. Runs `policy.call(...)` — the bool policy.
///    Reject → records `Reject('policy-rejected')`.
/// 3. No verdict policy → records `Accept()`.
/// 4. Runs `verdictPolicy.call(...)`:
///    - `Accept` / `Reject` → recorded as-is.
///    - `Defer` → **wave-honest resolution**:
///      - no resolver → `Reject('defer-no-resolver')` (fail closed);
///      - with a resolver → the `Defer` is recorded, the pulse is
///        dropped from this wave (human latency never blocks a wave),
///        the resolver runs out-of-band, and its result is recorded as
///        a follow-up decision linked by `decisionId`:
///        `Accept({'deferredBy': ..., 'decisionId': ...})` or
///        `Reject('defer-rejected'/'defer-resolver-failed', ...)`.
///
/// ### Non-obvious
/// - **Sequential, not chained.** Attribution requires knowing which
///   rule rejected.
/// - **Argument evaluations are enforcement-only.** Passing argument
///   checks are silent; a rejection there is attributed to the
///   command. A `Defer` during argument validation fails closed
///   (`defer-in-argument-validation`) — arguments are not decisions.
/// - **Only the four decision shapes are recorded** (pulse, action,
///   link, and argument-level rejections).
/// - **Fail closed.** `Exception`s record `composite-rejected` and
///   reject; `Error`s from the verdict policy propagate loudly — a
///   resolver's errors, however, always fail closed with
///   `defer-resolver-failed`.
/// - **Purity `readOnlyExternal`**; version `1.1.0` (the verdict path).
final class _RecordingTestCell<C extends Cell> extends TestCell<C> {
  final TestCell<C> _principalRule;
  final Policy _policy;
  final VerdictPolicy? _verdictPolicy;
  final Future<bool> Function(Decision, Verdict)? _onDeferred;
  final void Function(Decision) _onDecision;
  final C _cell;

  _RecordingTestCell({
    required TestCell<C> principalRule,
    required Policy policy,
    required void Function(Decision) onDecision,
    required C cell,
    VerdictPolicy? verdictPolicy,
    Future<bool> Function(Decision, Verdict)? onDeferred,
  })  : _principalRule = principalRule,
        _policy = policy,
        _onDecision = onDecision,
        _cell = cell,
        _verdictPolicy = verdictPolicy,
        _onDeferred = onDeferred,
        super((object, {host, arguments, user}) => true);

  @override
  FutureOr<bool> call(dynamic object, {Cell? host, dynamic arguments}) =>
      _evaluate(object, host: host, arguments: arguments);

  FutureOr<bool> _evaluate(dynamic object, {Cell? host, dynamic arguments}) {
    // The principal rule belongs to the principal cell and is typed for
    // it (a ValueCell's rule expects a ValueCell host — covariant
    // check). The policy sees the *view* host when one is supplied. The
    // override deliberately widens `host` to `Cell?`: on a deputy chain
    // the substrate passes the *deputy* (a generic `_Cell`) as the
    // host, so keeping `covariant C?` would throw for every `ValueCell`
    // principal.
    final viewHost = host ?? _cell;
    // During action validation the substrate also evaluates the rule
    // for each argument, passing the *action function* as `arguments`.
    final isArgumentEvaluation = arguments is Function;
    final start = DateTime.now();
    try {
      final r1 = _principalRule.call(
        object,
        host: _cell,
        arguments: arguments,
      );
      if (r1 is Future<bool>) {
        return r1.then((passed) {
          if (!passed) {
            _record(
              object,
              arguments,
              isArgumentEvaluation,
              const Reject('principal-rejected'),
              start,
            );
            return false;
          }
          return _afterPolicy(
            object,
            viewHost,
            arguments,
            isArgumentEvaluation,
            start,
          );
        });
      }
      if (!r1) {
        _record(
          object,
          arguments,
          isArgumentEvaluation,
          const Reject('principal-rejected'),
          start,
        );
        return false;
      }
      return _afterPolicy(
        object,
        viewHost,
        arguments,
        isArgumentEvaluation,
        start,
      );
    } on ReplayDivergenceException {
      rethrow;
    } on Exception {
      // A throwing rule fails closed — and the failure is recorded.
      _record(
        object,
        arguments,
        isArgumentEvaluation,
        const Reject('composite-rejected'),
        start,
      );
      return false;
    }
  }

  FutureOr<bool> _afterPolicy(
    dynamic object,
    Cell viewHost,
    dynamic arguments,
    bool isArgumentEvaluation,
    DateTime start,
  ) {
    final r2 = _policy.call(object, host: viewHost, arguments: arguments);
    if (r2 is Future<bool>) {
      return r2.then((passed) {
        if (!passed) {
          _record(
            object,
            arguments,
            isArgumentEvaluation,
            const Reject('policy-rejected'),
            start,
          );
          return false;
        }
        return _afterVerdict(
          object,
          viewHost,
          arguments,
          isArgumentEvaluation,
          start,
        );
      });
    }
    if (!r2) {
      _record(
        object,
        arguments,
        isArgumentEvaluation,
        const Reject('policy-rejected'),
        start,
      );
      return false;
    }
    return _afterVerdict(
      object,
      viewHost,
      arguments,
      isArgumentEvaluation,
      start,
    );
  }

  FutureOr<bool> _afterVerdict(
    dynamic object,
    Cell viewHost,
    dynamic arguments,
    bool isArgumentEvaluation,
    DateTime start,
  ) {
    final verdictPolicy = _verdictPolicy;
    if (verdictPolicy == null) {
      _record(
        object,
        arguments,
        isArgumentEvaluation,
        const Accept(),
        start,
      );
      return true;
    }

    try {
      // Link establishment is structural, not a decision: the verdict
      // slot never defers it (a Defer on a link would break observers).
      if (object is Cell) {
        _record(object, arguments, false, const Accept(), start);
        return true;
      }
      final result =
          verdictPolicy.call(object, host: viewHost, arguments: arguments);
      if (result is Future<Verdict>) {
        // Async verdict policies (1.1.0): prompted policies must query
        // an LLM before they can decide. Await, then record — errors
        // fail closed exactly like the synchronous path.
        return result.then(
          (verdict) => _handleVerdict(
            object,
            viewHost,
            arguments,
            isArgumentEvaluation,
            start,
            verdict,
          ),
          onError: (Object e, StackTrace st) {
            // Replay divergences and programming Errors are NOT policy
            // failures: divergences must propagate loudly (tampered
            // ledger), and `ArgumentError`s from config validation must
            // reach the caller instead of being recorded as rejections.
            if (e is ReplayDivergenceException || e is! Exception) {
              Error.throwWithStackTrace(e, st);
            }
            _record(
              object,
              arguments,
              isArgumentEvaluation,
              const Reject('composite-rejected'),
              start,
            );
            return false;
          },
        );
      }
      return _handleVerdict(
        object,
        viewHost,
        arguments,
        isArgumentEvaluation,
        start,
        result,
      );
    } on ReplayDivergenceException {
      rethrow;
    } on Exception {
      _record(
        object,
        arguments,
        isArgumentEvaluation,
        const Reject('composite-rejected'),
        start,
      );
      return false;
    }
  }

  FutureOr<bool> _handleVerdict(
    dynamic object,
    Cell viewHost,
    dynamic arguments,
    bool isArgumentEvaluation,
    DateTime start,
    Verdict verdict,
  ) {
    if (verdict is Defer) {
      if (isArgumentEvaluation) {
        _record(
          object,
          arguments,
          true,
          Reject('defer-in-argument-validation', verdict.annotations),
          start,
        );
        return false;
      }
      final deferredDecision = _buildDecision(
        object,
        arguments,
        verdict,
        start,
      );
      final resolver = _onDeferred;
      if (resolver == null) {
        _record(
          object,
          arguments,
          false,
          Reject('defer-no-resolver', verdict.annotations),
          start,
        );
        return false;
      }
      // Wave-honest Defer: the pulse is recorded as a Defer decision
      // and dropped from this wave (fail closed). The resolver runs
      // OUT-OF-BAND — human latency must never block a pulse wave —
      // and its resolution is recorded as a follow-up decision linked
      // by `decisionId`. Delivery after approval is the resolver's
      // job (the ApprovalQueue commits the value to `committed`;
      // applications observe it and re-ingest if desired).
      _onDecision(deferredDecision);
      unawaited(
        resolver(deferredDecision, verdict).then((approved) {
          _record(
            object,
            arguments,
            false,
            approved
                ? Accept({
                    'deferredBy': verdict.resolver,
                    'decisionId': deferredDecision.id,
                    ...verdict.annotations,
                  })
                : Reject(
                    'defer-rejected',
                    {
                      'deferredBy': verdict.resolver,
                      'decisionId': deferredDecision.id,
                      ...verdict.annotations,
                    },
                  ),
            start,
          );
          return approved;
        }).catchError((Object e, StackTrace st) {
          // A resolver may throw anything — `StateError` is an
          // `Error`, not an `Exception` — and all of it fails closed.
          _record(
            object,
            arguments,
            false,
            Reject(
              'defer-resolver-failed',
              {
                'deferredBy': verdict.resolver,
                'decisionId': deferredDecision.id,
                'error': e.toString(),
              },
            ),
            start,
          );
          return false;
        }),
      );
      return false;
    }

    // The caller (`_afterVerdict`) already wraps this call in the
    // fail-closed catch; this method stays plain.
    _record(object, arguments, isArgumentEvaluation, verdict, start);
    return verdict is Accept;
  }

  Decision _buildDecision(
    dynamic object,
    dynamic arguments,
    Verdict verdict,
    DateTime start,
  ) =>
      Decision(
        id: Identity.next(),
        at: DateTime.now(),
        context: _cell.context,
        contextVersion: _cell.context.version ?? '0.0.0',
        pulse: object is Pulse ? object : null,
        command: _commandFor(object, arguments),
        verdict: verdict,
        policyVersion: _policy.version,
        evaluationTime: DateTime.now().difference(start),
      );

  ApplyCommand? _commandFor(dynamic object, dynamic arguments) {
    if (object is Function && arguments is Arguments) {
      return (
        function: object,
        arguments: (
          positionalArguments: arguments.positionalArguments,
          namedArguments: arguments.namedArguments,
        ),
        compensation: null,
      );
    }
    if (object is! Function && arguments is Function) {
      return (
        function: arguments as Function,
        arguments: (
          positionalArguments: null,
          namedArguments: null,
        ),
        compensation: null,
      );
    }
    return null;
  }

  void _record(
    dynamic object,
    dynamic arguments,
    bool isArgumentEvaluation,
    Verdict verdict,
    DateTime start,
  ) {
    if (isArgumentEvaluation) {
      // Argument evaluations are enforcement-only. A rejection here is
      // attributed to the command being validated.
      if (verdict is Reject) {
        _emit(
          command: _commandFor(object, arguments),
          verdict: verdict,
          start: start,
        );
      }
      return;
    }

    // Decision shapes: pulse reception, action invocation, link
    // establishment. Anything else is not a decision.
    if (object is! Pulse && object is! Cell && object is! Function) return;

    _emit(
      pulse: object is Pulse ? object : null,
      command: _commandFor(object, arguments),
      verdict: verdict,
      start: start,
    );
  }

  void _emit({
    Pulse? pulse,
    ApplyCommand? command,
    required Verdict verdict,
    required DateTime start,
  }) {
    _onDecision(
      Decision(
        id: Identity.next(),
        at: DateTime.now(),
        context: _cell.context,
        contextVersion: _cell.context.version ?? '0.0.0',
        pulse: pulse,
        command: command,
        verdict: verdict,
        policyVersion: _policy.version,
        evaluationTime: DateTime.now().difference(start),
      ),
    );
  }

  @override
  Purity get purity => Purity.readOnlyExternal;

  @override
  String get version => '1.1.0';
}
