// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The RESTful transport binding for the somatic boundary.
///
/// In the framework's biological metaphor, **cell_skin_rest** acts as a
/// **Restful Membrane Pore**. It provides the physical infrastructure
/// required to bridge standard HTTP/HTTPS protocols with the internal
/// **Skin Membrane**.
///
/// ### The RESTful Journey
/// When a signal arrives at this pore, it follows a strictly governed
/// **Command Journey**:
///
/// 1.  **Signal Ingress**: The adapter intercepts the HTTP request as
///     a raw **Skin Payload**.
/// 2.  **Identity Analysis**: The [SkinAuth] gatekeeper extracts
///     **Environmental Markers** (headers, tokens) to identify the caller.
/// 3.  **Pulse Conversion**: The request is translated into a
///     **Nervous Signal** and dispatched into the somatic graph via
///     the [SkinMembrane].
/// 4.  **Forensic Egress**: The result of the **Somatic State Transition**
///     is sanitized into its **Skin Form** and returned to the environment.
///
/// ### Exposed Surfaces
/// This pore exposes specific somatic functions to the network:
/// * `POST /skin/apply`: Initiates a **Command Journey** to mutate state.
/// * `GET  /skin/manifest`: Provides the **Somatic Index** (tool catalogue).
/// * `GET  /skin/observe/:cellId`: An SSE stream of volatile **Nervous Signals**
///   (state changes).
/// * `GET  /skin/ledger`: An SSE stream of authoritative **Forensic Ledger Rows**.
/// * `POST /skin/verify`: A control operation to audit the system's "DNA" integrity.
///
/// ### Security Posture
/// The pore is **closed by default**. Every impulse must pass through an
/// **Integrity Gate** ([SkinAuth]) and be translated into internal authority
/// via a [ContextBridge]. Failures at the boundary are reported as
/// **Membrane Rejections** ([WireError]) to prevent "Forensic Holes" in
/// external observability.
///
/// ### Environmental Constraints
/// This library depends on `dart:io`. Because it binds to physical network
/// sockets, it is separated from the core `cell_skin` barrel. This ensures
/// that web-based cells or Flutter-web somatic entities can compile
/// without inheriting incompatible `io` dependencies.
///
/// ### See also
/// - [RestAdapter]: The physical server implementation of this pore.
/// - [SkinMembrane]: The core boundary orchestrator.
/// - [WireMessage]: The envelope for signals crossing this pore.
/// {@category Features}
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';

import '../../cells/skin_membrane.dart';
import '../../security/context_bridge.dart';
import '../../security/skin_auth.dart';
import '../../security/skin_call.dart';
import '../../wire/correlation_id.dart';
import '../../wire/file_idempotency_store.dart';
import '../../wire/wire_message.dart';
import '../../wire/wire_outcome.dart';
import '../../wire/wire_version.dart';
import 'skin_request_log.dart';

/// The default somatic saturation limit for an incoming impulse at a membrane pore.
///
/// In the framework's biological metaphor, this constant defines the maximum
/// volume of **Somatic Nutrients** (payload bytes) that a **Skin Membrane**
/// pore can ingest before the **Integrity Gate** triggers a **Membrane Rejection**.
///
/// ### When to use
/// - **Pore Configuration**: Used as the default cap in [RestAdapter.bind]
///   to protect the somatic graph from being overwhelmed by oversized
///   **Nervous Signals**.
///
/// ### How it works
/// 1. **Signal Ingress**: A request hits the [RestAdapter].
/// 2. **Saturation Check**: As the **Skin Payload** is read, the adapter
///    tracks the total bytes.
/// 3. **Gate Trigger**: If the volume exceeds this threshold, the impulse
///    is discarded, and a `body_too_large` [WireError] is returned.
///
/// ### Non‑obvious behavior
/// - **Forensic Omission**: Rejections caused by this limit occur before
///   a **Command Journey** begins, meaning no **Forensic Receipt** is
///   generated in the ledger.
/// - **Default Value**: Set to 1 MiB (1,048,576 bytes), balancing standard
///   command payloads against system resource preservation.
///
/// ### See also
/// - [RestAdapter.bind]: Where this limit is applied.
/// - [WireError]: The rejection signal sent when this limit is breached.
const int kDefaultMaxBodyBytes = 1024 * 1024;

/// The physical realization of a RESTful and SSE pore at the boundary layer.
///
/// In the framework's biological metaphor, [RestAdapter] is a **Membrane Pore**.
/// It binds the system to the external environment via HTTP, providing a
/// physical seam for **Nervous Signals** to enter the somatic graph and for
/// **Forensic Ledger Rows** to be broadcast back out.
///
/// ### Security Posture
/// The pore is **closed by default**. Every incoming impulse is treated as
/// an unverified **Skin Payload** until it passes through the following
/// **Integrity Gates**:
/// 1. **Saturation Gate**: Enforced by [_maxBodyBytes] to prevent exhaustion.
/// 2. **Identity Gatekeeper**: Handled by [_auth] to resolve credentials.
/// 3. **Membrane Translator**: Handled by [_contextBridge] to stamp the
///    resulting pulse with somatic authority.
///
/// ### Forensic Integrity
/// This adapter ensures that every successfully processed command results in
/// a **Forensic Receipt**. Failures that occur before the command reaches
/// a cell are reported as **Membrane Rejections** ([WireError]), ensuring
/// there are no "Forensic Holes" in the system's external audit trail.
///
/// ### See also
/// - [SkinMembrane]: The core reactive organ this adapter exposes.
/// - [SkinAuth]: The mechanism used to identify external actors.
/// - [ContextBridge]: The translator that turns identity into authority.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is the HTTP transport pore.
/// **Live signature:** `final class RestAdapter { final SkinMembrane membrane; int get port; Future<void> close(); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Discovery:** Use the `/skin/manifest` endpoint to fetch the **Somatic Index**.
/// **Interaction:** Use `/skin/apply` to initiate a **Command Journey**.
final class RestAdapter {
  /// The reactive organ orchestrating the somatic graph.
  final SkinMembrane membrane;

  /// The physical HTTP server instance acting as the pore's socket.
  final HttpServer _server;

  /// The **Identity Gatekeeper** used to verify incoming credentials.
  final SkinAuth _auth;

  /// The **Membrane Translator** used to map identity to somatic authority.
  final ContextBridge _contextBridge;

  /// The set of permitted `Host` headers allowed to stimulate this pore.
  final Set<String> _allowedHosts;

  /// The set of permitted browser `Origin` headers allowed for cross-site signals.
  final Set<String> _allowedOrigins;

  /// The maximum size of a **Skin Payload** before it is rejected.
  final int _maxBodyBytes;

  /// The maximum duration for a **Command Journey** before it is abandoned.
  final Duration _requestTimeout;

  /// The cadence for sending keep-alive pulses over SSE streams.
  final Duration _keepAliveInterval;

  /// The time source for request deadlines.
  final DateTime Function() _clock;

  /// The metrics hook, called once per finished request from a
  /// `finally`. `null` means no logging.
  final SkinRequestLog? onRequestLog;

  /// Receives server-side exceptions (a frame that failed to encode, a
  /// verify that threw). `null` means the failure is not logged. The
  /// exception never reaches the response body.
  final void Function(Object error, StackTrace stackTrace)? onServerError;

  /// The collection of active observers listening to the membrane's signals.
  final List<StreamSubscription<dynamic>> _subscriptions = [];

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
    required DateTime Function() clock,
    this.onServerError,
    this.onRequestLog,
  })  : _contextBridge = contextBridge,
        _allowedHosts = allowedHosts,
        _allowedOrigins = allowedOrigins,
        _maxBodyBytes = maxBodyBytes,
        _requestTimeout = requestTimeout,
        _keepAliveInterval = keepAliveInterval,
        _clock = clock {
    _server.listen(_handle);
  }

  /// Binds the REST adapter to a physical network address and port.///
  /// In the framework's biological metaphor, this method **sensitizes the pore**.
  /// It opens a specific communication channel at the **Skin Membrane**, allowing
  /// the system to receive discovery impulses, command signals, and forensic
  /// audit streams via HTTP and SSE.
  ///
  /// ### When to use
  /// - **Production Egress**: The standard way to expose a somatic graph to
  ///   the web, mobile apps, or curl-based administrative tools.
  /// - **Testing**: Used to spin up ephemeral pores for integration testing
  ///   of the membrane's **Integrity Gates**.
  ///
  /// ### How it works
  /// 1. **Socket Anchoring**: Binds an `HttpServer` to the provided [address] and [port].
  /// 2. **Gate Configuration**: Initializes the **Identity Gatekeeper** ([auth])
  ///    and the **Membrane Translator** ([contextBridge]).
  /// 3. **Saturation Limits**: Applies the [_maxBodyBytes] cap to all incoming
  ///    **Skin Payloads** to prevent resource exhaustion.
  /// 4. **CORS & Host Validation**: Configures the **Membrane Filter** using
  ///    [allowedHosts] and [allowedOrigins] to prevent unauthorized stimulation.
  ///
  /// ### Non‑obvious behavior
  /// - **Closed by Default**: [auth] is mandatory. To explicitly allow anonymous
  ///   signals, you must pass `const AllowAllSkinAuth()`.
  /// - **Forensic Timing**: The [requestTimeout] defines the window for a
  ///   **Command Journey**. If exceeded, the pore returns a 504 error, but
  ///   the state change may still complete internally (an "Observation Lag").
  /// - **SSE Liveness**: Disconnects are detected via the [keepAliveInterval].
  ///   A failed ping cleans up the subscription to prevent "Forensic Leaks"
  ///   of memory in the adapter.
  ///
  /// ### Parameters
  /// * [membrane] — The reactive organ to be exposed.
  /// * [auth] — **required**. Pass `const AllowAllSkinAuth()` to make
  ///   anonymous access an explicit opt-in.
  /// * [contextBridge] — translates the authenticated principal into
  ///   the framework [Context] stamped on every inbound pulse
  ///   (`DescribeContextBridge` by default; `SystemContextBridge` is
  ///   the loud opt-in to system authority).
  /// * [address] — The physical IP to bind (defaults to loopback).
  /// * [port] — The network port (use `0` for an ephemeral port).
  /// * [maxBodyBytes] — The saturation cap for impulses (default 1 MiB).
  ///

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
  /// **Live signature:** `static Future<RestAdapter> bind({required SkinMembrane membrane, required SkinAuth auth, ContextBridge contextBridge = const DescribeContextBridge(), Object? address, int port = 0, Set<String>? allowedHosts, Set<String>? allowedOrigins, int maxBodyBytes = 1048576, Duration requestTimeout = Duration(seconds: 30), Duration keepAliveInterval = Duration(seconds: 15), void Function(Object, StackTrace)? onServerError, DateTime Function() clock = DateTime.now, SkinRequestLog? onRequestLog})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
  /// **Do NOT confuse with:** `SkinMembrane.open` (the membrane) or `SkinAuth` (the credential check the adapter calls).
  /// **Guide:** `FEATURES-Skin.md` §10 (REST adapter).
  /// **Example:** `example/lib/mock/rest_io.dart` (the demo's real adapter binding).
  /// **Cross-layer:** every request is stamped with `skinPulseContext(baseContext: bridge.resolve(principal), actor: 'skin:<id>')` plus a JSON principal snapshot — the domain's gates read the caller through `SkinCall.current` during the apply, and stamped pulses store the actor on the ledger row.
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
    void Function(Object error, StackTrace stackTrace)? onServerError,
    DateTime Function() clock = DateTime.now,
    SkinRequestLog? onRequestLog,
  }) async {
    final server =
        await HttpServer.bind(address ?? InternetAddress.loopbackIPv4, port);
    try {
      // The decision uses what actually bound (`server.address`), not
      // the object the caller passed: a `String` address is judged by
      // the real socket. `0.0.0.0` and `::` are not loopback.
      if (allowedHosts == null && !server.address.isLoopback) {
        throw ArgumentError(
          'RestAdapter.bind: ${server.address.address} is not loopback; '
          'pass allowedHosts explicitly',
        );
      }
      return RestAdapter._(
        membrane,
        server,
        auth,
        contextBridge: contextBridge,
        allowedHosts: allowedHosts ?? _loopbackHosts(server.port),
        allowedOrigins: allowedOrigins ?? const {},
        maxBodyBytes: maxBodyBytes,
        requestTimeout: requestTimeout,
        keepAliveInterval: keepAliveInterval,
        clock: clock,
        onServerError: onServerError,
        onRequestLog: onRequestLog,
      );
    } catch (_) {
      // A refused bind must not leak a listening socket.
      await server.close(force: true);
      rethrow;
    }
  }

  /// The loopback allowlist for a bound port: the six loopback names,
  /// with and without the port (the IPv6 form is written `[::1]:port`).
  /// An explicit `allowedHosts` — including an empty set — replaces this
  /// list; it is never merged.
  static Set<String> _loopbackHosts(int port) => {
        'localhost',
        '127.0.0.1',
        '::1',
        'localhost:$port',
        '127.0.0.1:$port',
        '[::1]:$port',
      };

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

  String _nextCorrelationId() => nextCorrelationId('rest');

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final started = _clock();
    // The request log sample is filled from these locals, never from
    // the request itself: the route has no query (a query can carry a
    // token), the correlation id is the server id, and code is the
    // stable error code, not error.message.
    var correlationId = '';
    String? code;
    int? ledgerSeq;
    try {
      // Liveness comes first — unauthenticated probes get a clean 200,
      // and `/health` never reaches the host check.
      if (request.method == 'GET' && request.uri.path == '/health') {
        await _json(response, HttpStatus.ok, {'ok': true});
        return;
      }
      // Host and origin are separate gates with separate codes. The
      // header is not treated as proof of the peer address beyond the
      // allowlist.
      if (!_hostAllowed(request)) {
        code = 'host_not_allowed';
        await _json(
            response, skinErrorStatus['host_not_allowed']!, {
          'error': {'code': 'host_not_allowed'}
        });
        return;
      }
      final segments =
          request.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final origin = request.headers.value('origin');
      if (origin != null) {
        // Vary on every origin-carrying response, allowed or not.
        response.headers.set(HttpHeaders.varyHeader, 'Origin');
      }
      final originAllowed =
          origin == null || _allowedOrigins.contains(origin);
      if (!originAllowed) {
        // No Access-Control-Allow-Origin on a rejected origin.
        code = 'origin_not_allowed';
        await _json(
            response, skinErrorStatus['origin_not_allowed']!, {
          'error': {'code': 'origin_not_allowed'}
        });
        return;
      }
      if (origin != null) {
        // Echo the exact listed origin, never `*`.
        response.headers.set('Access-Control-Allow-Origin', origin);
      }
      // A preflight carries no Authorization: it must be answered
      // before authentication, or every browser preflight is 401.
      if (request.method == 'OPTIONS') {
        await _preflight(request, response, segments);
        return;
      }
      final principal = await _authenticate(request);
      if (principal == null) {
        code = 'unauthorized';
        await _json(response, HttpStatus.unauthorized, {
          'error': {
            'code': 'unauthorized',
            'message': 'missing or invalid credentials'
          }
        });
        return;
      }
      // Readiness sits beside /health in the URL list only: it is after
      // the host check and after SkinAuth. It does not call
      // SkinAuthorizer.
      if (segments.isNotEmpty && segments.first == 'ready') {
        await _requireMethod(request, 'GET', allow: 'GET');
        await _ready(response);
        return;
      }
      if (segments.length >= 2 && segments[0] == 'skin') {
        switch (segments[1]) {
          case 'apply':
            await _requireMethod(request, 'POST', allow: 'POST, OPTIONS');
            correlationId = _nextCorrelationId();
            final result = await _apply(
                request, response, principal, correlationId);
            code = result.$1;
            ledgerSeq = result.$2;
            return;
          case 'manifest':
            await _requireMethod(request, 'GET', allow: 'GET, OPTIONS');
            await _manifest(response, principal);
            return;
          case 'verify':
            await _requireMethod(request, 'POST', allow: 'POST, OPTIONS');
            await _verify(response);
            if (response.statusCode != HttpStatus.ok) {
              code = 'verify_failed';
            }
            return;
          case 'observe':
            await _requireMethod(request, 'GET', allow: 'GET, OPTIONS');
            await _observe(request, response, segments, principal);
            return;
          case 'ledger':
            await _requireMethod(request, 'GET', allow: 'GET, OPTIONS');
            await _ledger(request, response, principal);
            return;
        }
      }
      code = 'not_found';
      await _json(response, HttpStatus.notFound, {
        'error': {'code': 'not_found'}
      });
    } on _HttpError catch (error) {
      code = error.code;
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
      code = 'transport_error';
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
    } finally {
      // One sample per finished request — health, host/origin refusals,
      // preflights, 401s, applies, and SSE when the stream ends. A
      // throwing callback propagates: the response is already closed,
      // so it cannot be rewritten into a second body.
      onRequestLog?.call(SkinRequestSample(
        correlationId: correlationId,
        route: request.uri.path,
        status: response.statusCode,
        code: code,
        duration: _clock().difference(started),
        ledgerSeq: ledgerSeq,
      ));
    }
  }

  bool _hostAllowed(HttpRequest request) {
    // `/health` never reaches this check. Dart's HTTP/1.1 parser answers
    // 400 on its own when `Host` is absent, so a missing-host test must
    // speak HTTP/1.0 — here an absent, empty, whitespace, or CR/LF
    // header is rejected regardless.
    final host = request.headers.value(HttpHeaders.hostHeader);
    if (host == null) return false;
    final trimmed = host.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains('\r') || trimmed.contains('\n')) return false;
    final normalized = trimmed.toLowerCase();
    return _allowedHosts.any((allowed) => allowed.toLowerCase() == normalized);
  }

  static const Map<String, String> _routeAllowMethods = {
    'apply': 'POST, OPTIONS',
    'verify': 'POST, OPTIONS',
    'manifest': 'GET, OPTIONS',
    'observe': 'GET, OPTIONS',
    'ledger': 'GET, OPTIONS',
  };

  /// A CORS preflight for `/skin/<route>`. Runs after the host and
  /// origin gates and before authentication. A disallowed requested
  /// method is 405 with the `Allow` header listing the real verbs; an
  /// unknown path is 404, like any other method. The origin was already
  /// echoed on the response.
  Future<void> _preflight(
    HttpRequest request,
    HttpResponse response,
    List<String> segments,
  ) async {
    final route = segments.length >= 2 && segments[0] == 'skin'
        ? segments[1]
        : null;
    final allowMethods = route == null ? null : _routeAllowMethods[route];
    if (allowMethods == null) {
      await _json(response, HttpStatus.notFound, {
        'error': {'code': 'not_found'}
      });
      return;
    }
    final requested = request.headers.value('Access-Control-Request-Method');
    if (requested != null && !allowMethods.split(', ').contains(requested)) {
      // `Allow` lists the real verbs, not the one the browser asked for.
      response.headers.set(HttpHeaders.allowHeader, allowMethods);
      await _json(response, HttpStatus.methodNotAllowed, {
        'error': {'code': 'method_not_allowed'}
      });
      return;
    }
    response.headers.set('Access-Control-Allow-Methods', allowMethods);
    response.headers.set('Access-Control-Allow-Headers',
        'authorization, content-type, last-event-id');
    response.headers.set('Access-Control-Max-Age', '600');
    response.statusCode = HttpStatus.noContent;
    await response.close();
  }

  Future<void> _requireMethod(
    HttpRequest request,
    String method, {
    required String allow,
  }) async {
    if (request.method != method) {
      // RFC 9110: a 405 carries the real verbs in `Allow`.
      request.response.headers.set(HttpHeaders.allowHeader, allow);
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
    final iterator = StreamIterator<List<int>>(request);
    while (await iterator.moveNext()) {
      bytes.addAll(iterator.current);
      if (bytes.length > _maxBodyBytes) {
        // Drain the rest of the body before answering: responding
        // mid-stream would make the 413 race the client's remaining
        // writes and can destroy the connection before the status is
        // delivered. The cap bounds memory, not bytes read.
        while (await iterator.moveNext()) {}
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
    final json = decoded.cast<String, Object?>();
    // A bad wire version is the same 400 bad_json as malformed JSON —
    // the fixed version text never reaches the HTTP body.
    try {
      requireSkinWireVersion(json);
    } on FormatException {
      throw const _HttpError(HttpStatus.badRequest, 'bad_json');
    }
    return json;
  }

  Future<(String?, int?)> _apply(
    HttpRequest request,
    HttpResponse response,
    SkinPrincipal principal,
    String correlationId,
  ) async {
    final Map<String, Object?> json;
    try {
      json = await _readJsonBody(request, response);
    } on _HttpError catch (error) {
      await _json(response, error.status, {
        'error': {'code': error.code}
      });
      return (error.code, null);
    }

    // Server-side correlation: the client's id is echoed, never matched.
    final clientCorrelationId = json['correlationId'];
    if (clientCorrelationId != null && clientCorrelationId is! String) {
      await _json(response, HttpStatus.badRequest, {
        'error': {'code': 'bad_correlation_id'}
      });
      return ('bad_correlation_id', null);
    }
    final WireRequest wireRequest;
    try {
      wireRequest = WireRequest(
        cellId: _requireString(json, 'cellId'),
        function: _requireString(json, 'function'),
        positional: _positionalArgs(json['positional']),
        named: (json['named'] as Map?)?.cast<String, Object?>(),
        correlationId: correlationId,
        clientCorrelationId: clientCorrelationId as String?,
        lastSeenSeq: _optionalInt(json, 'lastSeenSeq'),
      );
    } on _HttpError catch (error) {
      await _json(response, error.status, {
        'error': {'code': error.code}
      });
      return (error.code, null);
    }

    final WireMessage message;
    try {
      message = await membrane.request(
        wireRequest,
        type: SkinPulseTypes.restApplyRequest,
        timeout: _requestTimeout,
        deadline: _clock().add(_requestTimeout),
        context: skinPulseContext(
          principal: principal,
          baseContext: _contextBridge.resolve(principal),
          reason:
              'rest apply ${wireRequest.cellId}.${wireRequest.function}',
        ),
      );
    } on TimeoutException {
      // The serial router may still execute the command after the
      // timeout. The outcome is unknown — the ledger is the truth.
      await _json(response, HttpStatus.gatewayTimeout, {
        'error': {
          'code': 'outcome_unknown',
          'message': 'no response in time. If the command had already '
              'started, it may have run; check /skin/ledger and retry '
              'the same correlationId. If it was still queued, it was '
              'not applied.',
        }
      });
      return ('outcome_unknown', null);
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
          return (null, null);
        }
        await _json(response, HttpStatus.ok, {
          'correlationId': wireResponse.correlationId,
          'clientCorrelationId': wireResponse.clientCorrelationId,
          // The router encodes the outcome (with the ledger receipt's
          // seq/digest when the apply wrote a row). The fallback serves
          // responses built outside the router.
          'outcome': wireResponse.outcomeJson?.toJson() ??
              (wireResponse.outcome != null
                  ? wireOutcomeJson(wireResponse.outcome!)
                  : null),
          if (wireResponse.ledgerSeqs != null)
            'ledgerSeqs': wireResponse.ledgerSeqs,
        });
        final receiptSeq = wireResponse.outcomeJson?.receipt['ledgerSeq'];
        final ledgerSeqs = wireResponse.ledgerSeqs;
        final seq = receiptSeq is int
            ? receiptSeq
            : (ledgerSeqs == null || ledgerSeqs.isEmpty)
                ? null
                : ledgerSeqs.reduce((a, b) => a > b ? a : b);
        return (null, seq);
      case WireError error:
        // The frozen table: unknown codes fall back to 500, and
        // transport_error is an explicit row, not the default.
        final status = skinErrorStatus[error.code] ?? HttpStatus.internalServerError;
        await _json(response, status, {
          'error': {
            'code': error.code,
            'message': error.message,
            if (error.clientCorrelationId != null)
              'clientCorrelationId': error.clientCorrelationId,
          }
        });
        return (error.code, null);
      case WireStateChange stateChange:
        // Egress is not a reply; treat it as an unexpected response.
        await _json(response, HttpStatus.internalServerError, {
          'error': {
            'code': 'unexpected_response',
            'message': stateChange.cellId
          }
        });
        return ('unexpected_response', null);
      default:
        await _json(response, HttpStatus.internalServerError, {
          'error': {'code': 'unexpected_response'}
        });
        return ('unexpected_response', null);
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

  Future<void> _manifest(
    HttpResponse response,
    SkinPrincipal principal,
  ) async {
    final message = await membrane.request(
      const WireManifestRequest(),
      type: SkinPulseTypes.manifestRequest,
      context: skinPulseContext(
        principal: principal,
        baseContext: _contextBridge.resolve(principal),
        reason: 'rest manifest',
      ),
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
    } catch (error, stackTrace) {
      // The reason goes to onServerError only; the body has exactly the
      // two fields — no message, no runtimeType, no error.toString().
      onServerError?.call(error, stackTrace);
      await _json(response, skinErrorStatus['verify_failed']!, {
        'ok': false,
        'code': 'verify_failed',
      });
    }
  }

  Future<void> _ready(HttpResponse response) async {
    if (membrane.isClosed) {
      await _json(response, HttpStatus.serviceUnavailable, {
        'ok': false,
        'code': 'not_ready',
      });
      return;
    }
    final ledger = membrane.ledger;
    if (ledger != null) {
      try {
        await ledger.verify();
      } catch (error, stackTrace) {
        onServerError?.call(error, stackTrace);
        await _json(response, HttpStatus.serviceUnavailable, {
          'ok': false,
          'code': 'not_ready',
        });
        return;
      }
    }
    final store = membrane.idempotency;
    if (store is FileIdempotencyStore && !await store.checkReady()) {
      await _json(response, HttpStatus.serviceUnavailable, {
        'ok': false,
        'code': 'not_ready',
      });
      return;
    }
    await _json(response, HttpStatus.ok, {'ok': true});
  }

  Future<void> _observe(
    HttpRequest request,
    HttpResponse response,
    List<String> segments,
    SkinPrincipal principal,
  ) async {
    if (segments.length < 3) {
      await _json(response, HttpStatus.badRequest, {
        'error': {'code': 'missing_cell'}
      });
      return;
    }
    // `Uri.pathSegments` already decodes percent-encoding and does not
    // treat `%2F` as a separator: both `/skin/observe/home/living` and
    // `/skin/observe/home%2Fliving` address `home/living`. Clients must
    // percent-encode slashes inside a cell id.
    final cellId = segments.sublist(2).join('/');
    if (!membrane.isExposed(cellId)) {
      await _json(response, HttpStatus.notFound, {
        'error': {'code': 'unknown_tool', 'message': cellId}
      });
      return;
    }
    // A non-null authorizer filters reads too: an exposed but denied
    // cell is forbidden, distinct from a hidden cell's unknown_tool.
    if (!await membrane.mayRead(principal, cellId)) {
      await _json(response, HttpStatus.forbidden, {
        'error': {'code': 'forbidden', 'message': cellId}
      });
      return;
    }
    final type = '${SkinPulseTypes.egressPrefix}$cellId';
    // A Last-Event-ID drops changes whose ledgerSeq is <= that id.
    // Unledgered changes carry no id and stay live-only.
    final lastEventId = _lastEventId(request);
    Future<bool> liveFilter(Pulse<WireMessage> pulse) async {
      if (pulse.type != type || pulse.payload is! WireStateChange) {
        return false;
      }
      if (lastEventId == null) return true;
      final seq = (pulse.payload as WireStateChange).receipt?.ledgerSeq;
      if (seq == null) return true;
      return seq > lastEventId;
    }

    await _sse(
      response,
      membrane.responses,
      _pulseFrame,
      liveFilter: liveFilter,
    );
  }

  int? _sinceQuery(HttpRequest request) {
    final raw = request.uri.queryParameters['since'];
    if (raw == null) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      throw const _HttpError(HttpStatus.badRequest, 'invalid_since');
    }
    return parsed;
  }

  int? _lastEventId(HttpRequest request) {
    final raw = request.headers.value('Last-Event-ID');
    if (raw == null) return null;
    return int.tryParse(raw.trim());
  }

  Future<void> _ledger(
    HttpRequest request,
    HttpResponse response,
    SkinPrincipal principal,
  ) async {
    // Cursor semantics: `?since=N` is inclusive; `Last-Event-ID: N` is
    // exclusive and only used when the query is absent; omitted means
    // live-only; `since=-1` means live-only too. A garbage
    // `Last-Event-ID` is ignored (EventSource would reconnect forever
    // on a 400); a bad query is a caller bug and stays 400.
    final query = _sinceQuery(request);
    final header = query == null ? _lastEventId(request) : null;
    final liveOnly = (query == null && header == null) || query == -1;
    final exclusive = header != null;
    final origin = exclusive ? header : (query ?? -1);
    final fromSeq = liveOnly ? null : (exclusive ? origin + 1 : origin);
    final ledger = membrane.ledger;

    // The high-water mark filters the live tail so no row is sent twice:
    // rows <= highWater are dropped. It is computed from the snapshot —
    // including rows the exposure/authorizer filters will hide.
    var highWater = -1;
    Future<bool> liveFilter(Pulse<WireMessage> pulse) async {
      final payload = pulse.payload;
      if (payload is! WireLedgerEntry) return false;
      if (payload.entry.seq <= highWater) return false;
      final cellId = payload.entry.receiptCellId;
      if (!membrane.isExposed(cellId)) return false;
      return membrane.mayRead(principal, cellId);
    }

    // The session listener is registered before the store is read, so a
    // row appended during the snapshot lands in the session's buffer and
    // is delivered once after the backlog.
    await _sse(
      response,
      membrane.responses,
      _pulseFrame,
      liveFilter: liveFilter,
      loadBacklog: ledger == null || fromSeq == null
          ? null
          : (writeBacklog) async {
              final snapshot = await ledger.entriesSince(fromSeq).toList();
              if (snapshot.isEmpty) {
                highWater = exclusive ? origin : origin - 1;
              } else {
                highWater = snapshot.last.seq;
              }
              for (final entry in snapshot) {
                final cellId = entry.receiptCellId;
                if (!membrane.isExposed(cellId)) continue;
                if (!await membrane.mayRead(principal, cellId)) continue;
                writeBacklog(_ledgerEntryFrame(entry));
              }
            },
    );
  }

  /// One backlog frame. Live frames reuse the same id formatting via
  /// [_pulseFrame], so a seq is never written in two places.
  String _ledgerEntryFrame(LedgerEntry entry) {
    final json = withWire({
      'kind': 'ledgerEntry',
      'entry': entry.toJson(),
    });
    return 'id: ${entry.seq}\n'
        'event: ${SkinPulseTypes.ledgerEntry}\n'
        'data: ${jsonEncode(json)}\n\n';
  }

  /// Opens an SSE session over a detached socket.
  ///
  /// The live listener is registered **before** [loadBacklog] runs, and
  /// events that arrive during the snapshot are buffered locally (up to
  /// 64) and flushed afterwards through [liveFilter] — the broadcast
  /// stream never replays them, so nothing is lost and nothing is sent
  /// twice. `pause()` is deliberately not used: a paused broadcast
  /// listener drops events instead of buffering them.
  ///
  /// After detach the socket speaks legal HTTP/1.1: chunked transfer is
  /// enabled and every SSE event is one real chunk. On a clean shutdown
  /// the zero chunk is written before destroy; on a write error the
  /// socket is destroyed without it.
  Future<void> _sse(
    HttpResponse response,
    Stream<Pulse<WireMessage>> stream,
    String Function(Pulse<WireMessage>) frame, {
    Future<bool> Function(Pulse<WireMessage>) liveFilter = _acceptAll,
    Future<void> Function(void Function(String text) writeBacklog)?
        loadBacklog,
  }) async {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType('text', 'event-stream');
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    response.headers.chunkedTransferEncoding = true;

    // The SSE writer owns the raw socket: `HttpResponse.done` does not
    // complete on a *silent* client disconnect, `Socket.done` does.
    // All frames are written through the socket as real chunks, never
    // through the detached response.
    Socket socket;
    try {
      socket = await response.detachSocket();
    } catch (_) {
      return; // The client vanished before the handshake finished.
    }
    socket.setOption(SocketOption.tcpNoDelay, true);

    const maxQueue = 64;
    final queue = <String>[];
    final liveBuffer = <Pulse<WireMessage>>[];
    var done = false;
    var draining = false;
    var backlogDone = false;
    var liveChain = Future<void>.value();
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

    void finish() {
      if (done) return;
      done = true;
      keepAlive?.cancel();
      final sub = subscription;
      if (sub != null) {
        _subscriptions.remove(sub);
        unawaited(sub.cancel());
      }
      try {
        // The terminating chunk of a chunked body.
        socket.add(ascii.encode('0\r\n\r\n'));
        unawaited(socket.flush().then((_) {
          socket.destroy();
        }).catchError((Object _) {
          socket.destroy();
        }));
      } catch (_) {
        socket.destroy();
      }
    }

    void writeChunk(String text) {
      final bytes = utf8.encode(text);
      // One queue item writes the whole chunk: a drop can never split a
      // chunk in half.
      socket
        ..add(ascii.encode('${bytes.length.toRadixString(16)}\r\n'))
        ..add(bytes)
        ..add(ascii.encode('\r\n'));
    }

    Future<void> drain() async {
      if (draining || done) return;
      draining = true;
      try {
        while (queue.isNotEmpty && !done) {
          writeChunk(queue.removeAt(0));
          await socket.flush();
        }
      } catch (_) {
        cleanup();
      } finally {
        draining = false;
        // A drain that returned early because `draining` was already
        // true must not be the last look at the queue.
        if (!done && queue.isNotEmpty) unawaited(drain());
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

    String frameOrError(Pulse<WireMessage> pulse) {
      try {
        return frame(pulse);
      } catch (error, stackTrace) {
        // One bad payload must not cancel the subscription: log it and
        // substitute an error frame; the next good event still arrives.
        onServerError?.call(error, stackTrace);
        return 'event: skin.error.transport\n'
            'data: ${jsonEncode({'error': {'code': 'frame_failed'}})}\n\n';
      }
    }

    Future<void> processLive(Pulse<WireMessage> pulse) async {
      if (done) return;
      if (!await liveFilter(pulse)) return;
      final text = frameOrError(pulse);
      if (text.isEmpty) return;
      enqueue(text);
    }

    void onPulse(Pulse<WireMessage> pulse) {
      if (!backlogDone) {
        if (liveBuffer.length >= maxQueue) {
          // The snapshot gap overran the buffer: drop the client — a
          // reconnect with Last-Event-ID recovers.
          cleanup();
          return;
        }
        liveBuffer.add(pulse);
        return;
      }
      // The filter may be async (the ledger's read checks consult the
      // authorizer). Chain it so arrival order survives the awaits.
      liveChain = liveChain.then((_) => processLive(pulse));
    }

    subscription = stream.listen(
      onPulse,
      onDone: finish,
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
    // The first event is the retry cadence, before the backlog, so a
    // client that dies mid-replay still knows the delay.
    enqueue('retry: 1000\n\n');

    if (loadBacklog != null) {
      await loadBacklog(enqueue);
    }

    // The snapshot is done: flush buffered live events through the same
    // filter, in arrival order, on the same chain as the live path so
    // an async filter can never reorder frames.
    backlogDone = true;
    for (final pulse in liveBuffer) {
      liveChain = liveChain.then((_) => processLive(pulse));
    }
    await liveChain;
    liveBuffer.clear();
  }

  static Future<bool> _acceptAll(Pulse<WireMessage> pulse) async => true;

  String _pulseFrame(Pulse<WireMessage> pulse) {
    final payload = pulse.payload;
    if (payload == null) return '';
    String idLine = '';
    if (payload is WireLedgerEntry) {
      idLine = 'id: ${payload.entry.seq}\n';
    } else if (payload is WireStateChange) {
      final seq = payload.receipt?.ledgerSeq;
      if (seq != null) idLine = 'id: $seq\n';
    }
    final json = payload is WireLedgerEntry
        ? withWire({
            'kind': 'ledgerEntry',
            'entry': payload.entry.toJson(),
          })
        : payload is WireStateChange
            ? payload.toJson()
            : payload is WireResponse
                ? _responseFrameJson(payload)
                : payload.toJson();
    return '$idLine'
        'event: ${_safeEventName(pulse.type)}\n'
        'data: ${jsonEncode(json)}\n\n';
  }

  /// SSE event names are single-line fields — a cell id containing a
  /// newline must never break the frame.
  static String _safeEventName(Object? type) =>
      '$type'.replaceAll(RegExp(r'[\r\n]'), '_');

  Map<String, Object?> _responseFrameJson(WireResponse response) {
    if (response.pendingReceipt) {
      return withWire({
        'kind': 'response',
        'correlationId': response.correlationId,
        'pendingReceipt': true,
        if (response.receiptJson != null) 'receipt': response.receiptJson,
      });
    }
    return withWire({
      'kind': 'response',
      'correlationId': response.correlationId,
      'outcome': response.outcomeJson?.toJson() ??
          (response.outcome != null
              ? wireOutcomeJson(response.outcome!)
              : null),
      if (response.ledgerSeqs != null) 'ledgerSeqs': response.ledgerSeqs,
    });
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
