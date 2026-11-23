// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The REST binding.
///
/// Reuses the same four Cells as every other transport; only the HTTP
/// adapter differs. Routes:
///
/// * `POST /skin/apply` — parse body into `WireRequest`, await the
///   correlated response, serialise the outcome JSON. JSON only, with
///   a bounded body; the server assigns the correlation id and echoes
///   the client's under `clientCorrelationId`.
/// * `GET  /skin/manifest` — the tool catalogue.
/// * `GET  /skin/observe/:cellId` — SSE stream of `skin.egress.<id>`
///   state changes, for exposed cells only.
/// * `GET  /skin/ledger?since=N` — SSE stream of ledger entries for
///   exposed cells; replays entries after `N` from the ledger store
///   before switching to the live tail, with SSE `id:` events.
/// * `POST /skin/verify` — `Ledger.verify` (a control operation; no
///   pulse needed).
/// * `GET  /health` — liveness, before authentication.
///
/// The default posture is **closed**: authentication is required
/// (pass `auth: const AllowAllSkinAuth()` explicitly to opt out), the
/// bind is loopback, POSTs must carry `Content-Type: application/json`,
/// `Host` must match the bind address, and any browser `Origin` header
/// is rejected unless explicitly allowed. There is no second wire
/// format: `wire_outcome.dart`, `wire_schema.dart` and
/// `wire_ledger.dart` are shared with MCP.
/// {@category Features}
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';

import '../../cells/skin_membrane.dart';
import '../../security/context_bridge.dart';
import '../../security/skin_auth.dart';
import '../../wire/wire_message.dart';
import '../../wire/wire_outcome.dart';

/// The maximum request body size accepted by default (1 MiB).
const int kDefaultMaxBodyBytes = 1024 * 1024;

/// The HTTP + SSE adapter over a [SkinMembrane].
/// {@category REST Adapter}
final class RestAdapter {
  final SkinMembrane membrane;
  final HttpServer _server;
  final SkinAuth _auth;
  final ContextBridge _contextBridge;
  final Set<String> _allowedHosts;
  final Set<String> _allowedOrigins;
  final int _maxBodyBytes;
  final Duration _requestTimeout;
  final Duration _keepAliveInterval;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  int _correlationCounter = 0;

  RestAdapter._(
    this.membrane,
    this._server,
    this._auth, {
    required ContextBridge contextBridge,
    required Set<String> allowedHosts,
    required Set<String> allowedOrigins,
    required int maxBodyBytes,
    required Duration requestTimeout,
    required Duration keepAliveInterval,
  })  : _contextBridge = contextBridge,
        _allowedHosts = allowedHosts,
        _allowedOrigins = allowedOrigins,
        _maxBodyBytes = maxBodyBytes,
        _requestTimeout = requestTimeout,
        _keepAliveInterval = keepAliveInterval {
    _server.listen(_handle);
  }

  /// Binds the REST adapter on [address]:[port] (port `0` = ephemeral).
  ///
  /// ### When to use
  /// * Exposing the membrane over HTTP: commands, manifest, SSE
  ///   observe/ledger, verify, health. Import it from
  ///   `package:cell_skin/cell_skin_rest.dart` (the main barrel stays
  ///   `dart:io`-free).
  ///
  /// ### How it works
  /// The adapter is **closed by default**: [auth] is required, methods
  /// are enforced per route, POST bodies must be JSON and bounded,
  /// `Host`/`Origin` are validated, and per-request `PulseContext`
  /// provenance flows from the [contextBridge]. Timeouts surface 504
  /// `outcome_unknown`; a same-id retry replays the stored outcome.
  ///
  /// ### Non-obvious
  /// SSE runs over a detached raw socket — `HttpResponse.done` does not
  /// complete on a silent client disconnect, `Socket.done` does, and
  /// the keep-alive ping bounds the detection window.
  ///
  /// * [auth] — **required**. Pass `const AllowAllSkinAuth()` to make
  ///   anonymous access an explicit opt-in.
  /// * [contextBridge] — translates the authenticated principal into
  ///   the framework [Context] stamped on every inbound pulse
  ///   (`DescribeContextBridge` by default; `SystemContextBridge` is
  ///   the loud opt-in to system authority).
  /// * [allowedHosts] — accepted `Host` header values; defaults to the
  ///   loopback names.
  /// * [allowedOrigins] — accepted browser `Origin` header values.
  ///   Empty by default: a browser request carrying an `Origin` header
  ///   is rejected unless its origin is listed here.
  /// * [maxBodyBytes] — request body cap (default 1 MiB).
  /// * [requestTimeout] — the membrane request timeout surfaced as 504
  ///   `outcome_unknown` (default 30s).
  /// * [keepAliveInterval] — SSE ping cadence (default 15s). A silent
  ///   client disconnect is detected by the next failed ping, which
  ///   releases the subscription.
  ///
  /// ### See also
  /// [SkinAuth], [ContextBridge], `ARCHITECTURE-Skin.md` §7.
  ///
  /// ### AI Agent Guide
  /// **Layer:** Skin — the HTTP transport on top of the membrane, not a second dispatch path.
  /// **When to use:** a requirement says "REST endpoint for the graph", "SSE stream of changes", "audit log over HTTP", or "curl-able manifest".
  /// **When NOT to use:** in-process calls (use `SkinClient`); speaking MCP (use the `McpAdapter` seam with an MCP SDK).
  /// **Live signature:** `static Future<RestAdapter> bind({required SkinMembrane membrane, required SkinAuth auth, ContextBridge contextBridge = const DescribeContextBridge(), Object? address, int port = 0, Set<String>? allowedHosts, Set<String>? allowedOrigins, int maxBodyBytes = 1048576, Duration requestTimeout = Duration(seconds: 30), Duration keepAliveInterval = Duration(seconds: 15)})` — pinned at `cell_skin: 0.1.0`
  /// **Do NOT confuse with:** `SkinMembrane.open` (the membrane) or `SkinAuth` (the credential check the adapter calls).
  /// **Guide:** `FEATURES-Skin.md` §10 (REST adapter).
  /// **Example:** `example/lib/mock/rest_io.dart` (the demo's real adapter binding).
  /// **Cross-layer:** every request is stamped with `PulseContext(baseContext: bridge.resolve(principal), actor: 'skin:<id>')` — the domain's gates see the remote actor.
  /// **Minimal compilable example**
  /// ```dart
  /// final adapter = await RestAdapter.bind(
  ///   membrane: membrane,
  ///   auth: const AllowAllSkinAuth(),
  /// );
  /// ```
  static Future<RestAdapter> bind({
    required SkinMembrane membrane,
    required SkinAuth auth,
    ContextBridge contextBridge = const DescribeContextBridge(),
    Object? address,
    int port = 0,
    Set<String>? allowedHosts,
    Set<String>? allowedOrigins,
    int maxBodyBytes = kDefaultMaxBodyBytes,
    Duration requestTimeout = const Duration(seconds: 30),
    Duration keepAliveInterval = const Duration(seconds: 15),
  }) async {
    final server =
        await HttpServer.bind(address ?? InternetAddress.loopbackIPv4, port);
    return RestAdapter._(
      membrane,
      server,
      auth,
      contextBridge: contextBridge,
      allowedHosts: allowedHosts ??
          {
            'localhost',
            '127.0.0.1',
            '::1',
            'localhost:${server.port}',
            '127.0.0.1:${server.port}',
            '[::1]:${server.port}',
          },
      allowedOrigins: allowedOrigins ?? const {},
      maxBodyBytes: maxBodyBytes,
      requestTimeout: requestTimeout,
      keepAliveInterval: keepAliveInterval,
    );
  }

  /// The number of live SSE subscriptions (observability for tests and
  /// operations).
  int get activeSubscriptions => _subscriptions.length;

  /// The bound port (after an ephemeral bind, this is the real port).
  int get port => _server.port;

  /// Stops the server and all subscriptions.
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _server.close(force: true);
  }

  String _nextCorrelationId() =>
      'rest-${DateTime.now().microsecondsSinceEpoch}-${_correlationCounter++}';

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      // Liveness comes first — unauthenticated probes get a clean 200.
      if (request.method == 'GET' && request.uri.path == '/health') {
        await _json(response, HttpStatus.ok, {'ok': true});
        return;
      }
      if (!_hostAllowed(request) || !_originAllowed(request)) {
        await _json(response, HttpStatus.forbidden, {
          'error': {'code': 'forbidden', 'message': 'host/origin not allowed'}
        });
        return;
      }
      final principal = await _authenticate(request);
      if (principal == null) {
        await _json(response, HttpStatus.unauthorized, {
          'error': {
            'code': 'unauthorized',
            'message': 'missing or invalid credentials'
          }
        });
        return;
      }
      final segments =
          request.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length >= 2 && segments[0] == 'skin') {
        switch (segments[1]) {
          case 'apply':
            await _requireMethod(request, 'POST');
            await _apply(request, response, principal);
            return;
          case 'manifest':
            await _requireMethod(request, 'GET');
            await _manifest(response);
            return;
          case 'verify':
            await _requireMethod(request, 'POST');
            await _verify(response);
            return;
          case 'observe':
            await _requireMethod(request, 'GET');
            await _observe(request, response, segments);
            return;
          case 'ledger':
            await _requireMethod(request, 'GET');
            await _ledger(request, response);
            return;
        }
      }
      await _json(response, HttpStatus.notFound, {
        'error': {'code': 'not_found'}
      });
    } on _HttpError catch (error) {
      try {
        await _json(response, error.status, {
          'error': {'code': error.code}
        });
      } catch (_) {
        // Headers already sent (SSE); nothing more to do.
      }
    } catch (error) {
      // Best-effort error reply: a response whose headers were already
      // written (e.g. an SSE stream) cannot be rewritten, so the write
      // is guarded and swallowed there.
      try {
        response.statusCode = HttpStatus.internalServerError;
        response.write(jsonEncode({
          'error': {
            'code': 'transport_error',
            'message': '${error.runtimeType}'
          }
        }));
        await response.close();
      } catch (_) {
        // The transport is gone or the headers are sent; nothing more
        // to do.
      }
    }
  }

  bool _hostAllowed(HttpRequest request) {
    final host = request.headers.value(HttpHeaders.hostHeader);
    if (host == null) return true; // HTTP/1.0 clients may omit it
    final normalized = host.toLowerCase();
    return _allowedHosts.any((allowed) => allowed.toLowerCase() == normalized);
  }

  bool _originAllowed(HttpRequest request) {
    final origin = request.headers.value('origin');
    if (origin == null) return true;
    return _allowedOrigins.contains(origin);
  }

  Future<void> _requireMethod(HttpRequest request, String method) async {
    if (request.method != method) {
      throw const _HttpError(HttpStatus.methodNotAllowed, 'method_not_allowed');
    }
  }

  Future<void> _requireJson(HttpRequest request) async {
    final contentType = request.headers.contentType?.mimeType.toLowerCase();
    if (contentType != 'application/json') {
      throw const _HttpError(
          HttpStatus.unprocessableEntity, 'content_type_required');
    }
  }

  Future<SkinPrincipal?> _authenticate(HttpRequest request) async {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    final token = header != null && header.toLowerCase().startsWith('bearer ')
        ? header.substring('bearer '.length).trim()
        : null;
    final principal = await _auth.authenticate(SkinCredentials(
      token: token,
      metadata: {
        'peerAddress': request.connectionInfo?.remoteAddress.address,
        'peerPort': request.connectionInfo?.remotePort,
        'host': request.headers.value(HttpHeaders.hostHeader),
        'userAgent': request.headers.value(HttpHeaders.userAgentHeader),
      },
    ));
    if (principal == null) {
      request.response.headers.set(HttpHeaders.wwwAuthenticateHeader,
          'Bearer realm="skin", charset="UTF-8"');
    }
    return principal;
  }

  Future<Map<String, Object?>> _readJsonBody(
      HttpRequest request, HttpResponse response) async {
    await _requireJson(request);
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > _maxBodyBytes) {
        throw const _HttpError(
            HttpStatus.requestEntityTooLarge, 'body_too_large');
      }
    }
    if (bytes.isEmpty) {
      throw const _HttpError(HttpStatus.badRequest, 'missing_body');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const _HttpError(HttpStatus.badRequest, 'bad_json');
    }
    if (decoded is! Map) {
      throw const _HttpError(HttpStatus.badRequest, 'bad_json');
    }
    return decoded.cast<String, Object?>();
  }

  Future<void> _apply(
    HttpRequest request,
    HttpResponse response,
    SkinPrincipal principal,
  ) async {
    final Map<String, Object?> json;
    try {
      json = await _readJsonBody(request, response);
    } on _HttpError catch (error) {
      await _json(response, error.status, {
        'error': {'code': error.code}
      });
      return;
    }

    // Server-side correlation: the client's id is echoed, never matched.
    final clientCorrelationId = json['correlationId'];
    if (clientCorrelationId != null && clientCorrelationId is! String) {
      await _json(response, HttpStatus.badRequest, {
        'error': {'code': 'bad_correlation_id'}
      });
      return;
    }
    final WireRequest wireRequest;
    try {
      wireRequest = WireRequest(
        cellId: _requireString(json, 'cellId'),
        function: _requireString(json, 'function'),
        positional: _positionalArgs(json['positional']),
        named: (json['named'] as Map?)?.cast<String, Object?>(),
        correlationId: _nextCorrelationId(),
        clientCorrelationId: clientCorrelationId as String?,
        lastSeenSeq: _optionalInt(json, 'lastSeenSeq'),
      );
    } on _HttpError catch (error) {
      await _json(response, error.status, {
        'error': {'code': error.code}
      });
      return;
    }

    final WireMessage message;
    try {
      message = await membrane.request(
        wireRequest,
        type: SkinPulseTypes.restApplyRequest,
        timeout: _requestTimeout,
        context: PulseContext(
          baseContext: _contextBridge.resolve(principal),
          actor: 'skin:${principal.id}',
          reason: 'rest apply ${wireRequest.cellId}.${wireRequest.function}',
        ),
      );
    } on TimeoutException {
      // The serial router may still execute the command after the
      // timeout. The outcome is unknown — the ledger is the truth.
      await _json(response, HttpStatus.gatewayTimeout, {
        'error': {
          'code': 'outcome_unknown',
          'message': 'no response in time; the command may have run — '
              'check /skin/ledger and use the same clientCorrelationId '
              'to retry without duplicating',
        }
      });
      return;
    }
    switch (message) {
      case WireResponse wireResponse:
        if (wireResponse.pendingReceipt) {
          await _json(response, HttpStatus.accepted, {
            'correlationId': wireResponse.correlationId,
            'clientCorrelationId': wireResponse.clientCorrelationId,
            'pendingReceipt': true,
            if (wireResponse.receiptJson != null)
              'receipt': wireResponse.receiptJson,
          });
          return;
        }
        await _json(response, HttpStatus.ok, {
          'correlationId': wireResponse.correlationId,
          'clientCorrelationId': wireResponse.clientCorrelationId,
          'outcome': wireResponse.outcome != null
              ? wireOutcomeJson(wireResponse.outcome!)
              : wireResponse.outcomeJson!.toJson(),
        });
        return;
      case WireError error:
        final status = switch (error.code) {
          'unknown_tool' => HttpStatus.notFound,
          'conflict' => HttpStatus.conflict,
          'cursor_required' => HttpStatus.preconditionRequired,
          'bad_arguments' => HttpStatus.unprocessableEntity,
          _ => HttpStatus.internalServerError,
        };
        await _json(response, status, {
          'error': {
            'code': error.code,
            'message': error.message,
            if (error.clientCorrelationId != null)
              'clientCorrelationId': error.clientCorrelationId,
          }
        });
        return;
      case WireStateChange stateChange:
        // Egress is not a reply; treat it as an unexpected response.
        await _json(response, HttpStatus.internalServerError, {
          'error': {
            'code': 'unexpected_response',
            'message': stateChange.cellId
          }
        });
        return;
      default:
        await _json(response, HttpStatus.internalServerError, {
          'error': {'code': 'unexpected_response'}
        });
    }
  }

  static String _requireString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw _HttpError(HttpStatus.badRequest, 'missing_$key');
    }
    return value;
  }

  static int? _optionalInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! int) {
      throw _HttpError(HttpStatus.badRequest, 'invalid_$key');
    }
    return value;
  }

  /// Accepts positional arguments as either a JSON array (`[a, b]`,
  /// the preferred wire form) or the legacy index-keyed object
  /// (`{"0": a, "1": b}`).
  static Map<String, Object?>? _positionalArgs(Object? value) {
    if (value == null) return null;
    if (value is Map) return value.cast<String, Object?>();
    if (value is List) {
      return {for (var i = 0; i < value.length; i++) '$i': value[i]};
    }
    throw _HttpError(HttpStatus.badRequest, 'invalid_positional');
  }

  Future<void> _manifest(HttpResponse response) async {
    final message = await membrane.request(
      const WireManifestRequest(),
      type: SkinPulseTypes.manifestRequest,
    );
    final manifest = switch (message) {
      WireManifestResponse m => m.manifest,
      WireError e =>
        throw StateError('manifest failed: ${e.code}: ${e.message}'),
      _ => throw StateError('unexpected manifest response: $message'),
    };
    await _json(response, HttpStatus.ok, {'manifest': manifest.toJson()});
  }

  Future<void> _verify(HttpResponse response) async {
    final ledger = membrane.ledger;
    if (ledger == null) {
      await _json(response, HttpStatus.notImplemented, {
        'error': {'code': 'no_ledger'}
      });
      return;
    }
    try {
      await ledger.verify();
      await _json(response, HttpStatus.ok,
          {'ok': true, 'lastSeq': await ledger.lastSeq});
    } catch (error) {
      await _json(response, HttpStatus.internalServerError, {
        'ok': false,
        'message': '${error.runtimeType}: $error',
      });
    }
  }

  Future<void> _observe(
    HttpRequest request,
    HttpResponse response,
    List<String> segments,
  ) async {
    if (segments.length < 3) {
      await _json(response, HttpStatus.badRequest, {
        'error': {'code': 'missing_cell'}
      });
      return;
    }
    final cellId = segments[2];
    if (!membrane.isExposed(cellId)) {
      await _json(response, HttpStatus.notFound, {
        'error': {'code': 'unknown_tool', 'message': cellId}
      });
      return;
    }
    final type = '${SkinPulseTypes.egressPrefix}$cellId';
    await _sse(
      response,
      membrane.responses.where(
          (pulse) => pulse.type == type && pulse.payload is WireStateChange),
      (pulse) => _pulseFrame(pulse),
    );
  }

  Future<void> _ledger(HttpRequest request, HttpResponse response) async {
    final since =
        int.tryParse(request.uri.queryParameters['since'] ?? '') ?? -1;
    // Replay the backlog from the store first, so a reconnecting
    // auditor never silently loses entries.
    final ledger = membrane.ledger;
    if (ledger != null && since >= 0) {
      final backlog = await ledger.entriesSince(since).toList();
      await _sse(
        response,
        membrane.responses.where((pulse) => _ledgerEntryPasses(pulse, -1)),
        (pulse) => _pulseFrame(pulse),
        backlog: backlog
            .where((entry) => membrane.isExposed(entry.receiptCellId))
            .toList(),
      );
      return;
    }
    await _sse(
      response,
      membrane.responses.where((pulse) => _ledgerEntryPasses(pulse, since)),
      (pulse) => _pulseFrame(pulse),
    );
  }

  bool _ledgerEntryPasses(Pulse<WireMessage> pulse, int since) {
    final payload = pulse.payload;
    if (payload is! WireLedgerEntry) return false;
    if (payload.entry.seq <= since) return false;
    return membrane.isExposed(payload.entry.receiptCellId);
  }

  /// Sends [backlog] frames first (with SSE `id:` events), then the
  /// live [stream]. Each client gets its own subscription, cancelled
  /// when the response closes; a bounded queue with `pause()` applies
  /// backpressure instead of buffering unboundedly, and a client that
  /// overflows is dropped.
  Future<void> _sse(
    HttpResponse response,
    Stream<Pulse<WireMessage>> stream,
    String Function(Pulse<WireMessage>) frame, {
    List<LedgerEntry> backlog = const [],
  }) async {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType('text', 'event-stream');
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

    // The SSE writer owns the raw socket: `HttpResponse.done` does not
    // complete on a *silent* client disconnect, `Socket.done` does.
    // All frames are written through the socket, never through the
    // detached response. Chunked transfer is disabled before the
    // detach so the header block `detachSocket` emits is followed by
    // raw, connection-delimited SSE bytes (otherwise the client's
    // chunk parser would choke on the frames).
    response.headers.chunkedTransferEncoding = false;
    Socket socket;
    try {
      socket = await response.detachSocket();
    } catch (_) {
      return; // The client vanished before the handshake finished.
    }
    socket.setOption(SocketOption.tcpNoDelay, true);

    const maxQueue = 64;
    final queue = <String>[];
    var done = false;
    var draining = false;
    StreamSubscription<Pulse<WireMessage>>? subscription;
    Timer? keepAlive;

    void cleanup() {
      if (done) return;
      done = true;
      keepAlive?.cancel();
      final sub = subscription;
      if (sub != null) {
        _subscriptions.remove(sub);
        unawaited(sub.cancel());
      }
      socket.destroy();
    }

    Future<void> drain() async {
      if (draining || done) return;
      draining = true;
      try {
        while (queue.isNotEmpty && !done) {
          socket.write(queue.removeAt(0));
          await socket.flush();
        }
      } catch (_) {
        cleanup();
      } finally {
        draining = false;
      }
    }

    void enqueue(String data) {
      if (done) return;
      if (queue.length >= maxQueue) {
        // Slow client: drop the connection instead of buffering forever.
        cleanup();
        return;
      }
      queue.add(data);
      unawaited(drain());
    }

    for (final entry in backlog) {
      final json = {
        'kind': 'ledgerEntry',
        'entry': entry.toJson(),
      };
      enqueue('id: ${entry.seq}\n'
          'event: ${SkinPulseTypes.ledgerEntry}\n'
          'data: ${jsonEncode(json)}\n\n');
    }

    subscription = stream.listen(
      (pulse) => enqueue(frame(pulse)),
      onDone: cleanup,
      onError: (Object _) => cleanup,
    );
    _subscriptions.add(subscription);
    // Silent disconnect detection: the socket closes (or a write
    // fails) → cleanup releases the subscription.
    socket.done.whenComplete(cleanup);
    // The ping keeps intermediaries from dropping idle streams and
    // bounds the detection window for silent disconnects.
    keepAlive =
        Timer.periodic(_keepAliveInterval, (_) => enqueue(': ping\n\n'));
    // Keep-alive comment; frames follow as they arrive.
    enqueue('retry: 1000\n\n');
  }

  String _pulseFrame(Pulse<WireMessage> pulse) {
    final payload = pulse.payload;
    if (payload == null) return '';
    final json = payload is WireLedgerEntry
        ? {
            'kind': 'ledgerEntry',
            'entry': payload.entry.toJson(),
          }
        : payload is WireStateChange
            ? payload.toJson()
            : payload is WireResponse
                ? _responseFrameJson(payload)
                : payload.toJson();
    return 'event: ${_safeEventName(pulse.type)}\n'
        'data: ${jsonEncode(json)}\n\n';
  }

  /// SSE event names are single-line fields — a cell id containing a
  /// newline must never break the frame.
  static String _safeEventName(Object? type) =>
      '$type'.replaceAll(RegExp(r'[\r\n]'), '_');

  Map<String, Object?> _responseFrameJson(WireResponse response) {
    if (response.pendingReceipt) {
      return {
        'kind': 'response',
        'correlationId': response.correlationId,
        'pendingReceipt': true,
        if (response.receiptJson != null) 'receipt': response.receiptJson,
      };
    }
    return {
      'kind': 'response',
      'correlationId': response.correlationId,
      'outcome': response.outcome != null
          ? wireOutcomeJson(response.outcome!)
          : response.outcomeJson!.toJson(),
    };
  }

  Future<void> _json(
    HttpResponse response,
    int status,
    Map<String, Object?> body,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}

/// An internal typed HTTP error carrying its response status.
final class _HttpError implements Exception {
  final int status;
  final String code;

  const _HttpError(this.status, this.code);

  @override
  String toString() => 'HttpError($status, $code)';
}
