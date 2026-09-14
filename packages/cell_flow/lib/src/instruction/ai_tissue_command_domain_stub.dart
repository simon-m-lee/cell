// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'ai_tissue_command_domain.dart';

/// Web/WASM stub for the live HTTP interpreter.
///
/// [HttpInterpreter] requires 'dart:io' and is only available on native
/// platforms. On web and WASM this stub keeps the public API present while
/// throwing [UnsupportedError] at construction time.
class HttpInterpreter implements Interpreter {
  /// The chat-completions endpoint (mirrored from the IO implementation).
  final Uri endpoint;

  /// The bearer token (mirrored from the IO implementation).
  final String apiKey;

  /// The model identifier (mirrored from the IO implementation).
  final String model;

  /// Per-request timeout (mirrored from the IO implementation).
  final Duration timeout;

  /// Optional extra fields merged into the request envelope.
  final Map<String, dynamic> extraBody;

  /// Not available on web/WASM. Always throws [UnsupportedError].
  HttpInterpreter({
    required Uri endpoint,
    required String apiKey,
    required String model,
    Object? client,
    Duration timeout = const Duration(seconds: 30),
    TrafficLog? log,
    Map<String, dynamic> extraBody = const {},
  })  : endpoint = endpoint,
        apiKey = apiKey,
        model = model,
        timeout = timeout,
        extraBody = extraBody {
    throw UnsupportedError(
      'HttpInterpreter requires dart:io and is not available on this platform.',
    );
  }

  @override
  String get transport => 'http';

  @override
  void injectTimeoutOnce() {}

  @override
  Future<InterpreterReply> complete({
    required String text,
    required Set<String> verbs,
  }) =>
      Future<InterpreterReply>.error(
        UnsupportedError(
          'HttpInterpreter requires dart:io and is not available on this platform.',
        ),
      );

  /// No-op on web/WASM.
  void close() {}
}

/// Web/WASM stub for [AiConfig.fromJsonFile]. Always throws.
String readJsonFileSync(String path) => throw UnsupportedError(
      'File access is not available on this platform.',
    );

/// Web/WASM stub for the demo's environment lookup. Always empty.
Map<String, String> get platformEnvironment => const {};
