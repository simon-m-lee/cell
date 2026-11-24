// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The metrics hook for the REST adapter.
///
/// No metrics library: the same callback is the metrics hook, and an
/// application that wants a counter wraps it. The sample carries no
/// header map, no body, no principal, and no token — `toString` prints
/// only the six fields.
/// {@category Features}
library;

/// One finished HTTP request: a record for the metrics hook.
///
/// ### AI Agent Guide
/// **Layer:** Skin — the metrics hook, not a metrics library.
/// **When to use:** `RestAdapter.bind(onRequestLog:)` for counters,
/// traces, or slow-request alarms.
/// **When NOT to use:** authentication data — the sample has no headers,
/// no body, and no token.
/// **Live signature:** `typedef SkinRequestLog = void Function(SkinRequestSample sample)` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
typedef SkinRequestLog = void Function(SkinRequestSample sample);

/// One finished HTTP request as seen by [SkinRequestLog].
///
/// [route] is `request.uri.path` only — no query, which can carry a
/// token. [correlationId] is the server id minted for an apply, `''` on
/// every other route — never `clientCorrelationId`. [code] is the
/// stable error code or `null` on success — never `error.message`.
/// [ledgerSeq] is the greatest seq the apply response reports
/// (`receipt.ledgerSeq`, or the max of `ledgerSeqs`), `null` when there
/// is none. [duration] spans `_handle` entry to the `finally`.
///
/// ### AI Agent Guide
/// **Layer:** Skin — one finished HTTP request as seen by [SkinRequestLog].
/// **When to use:** the sample fields for counters and tracing.
/// **When NOT to use:** the request body or the bearer token — they are
/// deliberately absent.
/// **Live signature:** `final class SkinRequestSample { final String correlationId; final String route; final int status; final String? code; final Duration duration; final int? ledgerSeq; const SkinRequestSample({required String correlationId, required String route, required int status, required String? code, required Duration duration, required int? ledgerSeq}); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
final class SkinRequestSample {
  final String correlationId;
  final String route;
  final int status;
  final String? code;
  final Duration duration;
  final int? ledgerSeq;

  const SkinRequestSample({
    required this.correlationId,
    required this.route,
    required this.status,
    required this.code,
    required this.duration,
    required this.ledgerSeq,
  });

  @override
  String toString() =>
      'SkinRequestSample($correlationId, $route, $status, $code, $duration, $ledgerSeq)';
}
