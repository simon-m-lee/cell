// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Link checker for the guides and docs (Gate G9).
//
// Usage:
//   dart run tool/check_links.dart            # fail on broken local links
//
// Checks, for every `guide/*.md` and `doc/*.md`:
// - Markdown links `[text](target)` and backtick references
//   `` `guide/X.md` `` / `` `doc/X.md` `` whose target starts with
//   `guide/`, `doc/`, or `example/` — the target file must exist.
// - HTTP(S) links — HEAD request with a 10s timeout and 3 attempts.
//   Transient network failures are reported as warnings (CI without
//   network should not hard-fail the link gate); DNS/404 responses are
//   hard failures.

import 'dart:async';
import 'dart:io';

void main() async {
  final root = File.fromUri(Platform.script).parent.parent;
  final targets = <File>[
    ...Directory('${root.path}/guide').listSync().whereType<File>(),
    ...Directory('${root.path}/doc').listSync().whereType<File>(),
  ].where((f) => f.path.endsWith('.md')).toList();

  var localChecked = 0;
  var urlChecked = 0;
  final failures = <String>[];
  final warnings = <String>[];

  final markdownLink = RegExp(r'\[[^\]]*\]\(([^)\s]+)\)');
  final backtickRef = RegExp(r'`((?:guide|doc|example)/[^`\s]+)`');

  for (final file in targets) {
    final text = file.readAsStringSync();
    for (final match in markdownLink.allMatches(text)) {
      final target = match.group(1)!;
      if (target.startsWith('http://') || target.startsWith('https://')) {
        urlChecked++;
        final result = await _checkUrl(target);
        if (result == _UrlResult.ok) continue;
        if (result == _UrlResult.transient) {
          warnings.add(
            '${file.uri.pathSegments.last}: $target '
            '(network unreachable — warning only)',
          );
        } else {
          failures.add(
            '${file.uri.pathSegments.last}: $target '
            '(URL did not respond)',
          );
        }
        continue;
      }
      if (!target.startsWith('guide/') &&
          !target.startsWith('doc/') &&
          !target.startsWith('example/')) {
        continue; // anchors, absolute paths, or out-of-scope links
      }
      localChecked++;
      if (!_exists(root, target)) {
        failures.add('${file.uri.pathSegments.last}: $target (missing)');
      }
    }
    for (final match in backtickRef.allMatches(text)) {
      final target = match.group(1)!;
      if (!_looksLikeFile(target)) continue;
      localChecked++;
      if (!_exists(root, target)) {
        failures.add('${file.uri.pathSegments.last}: $target (missing)');
      }
    }
  }

  stdout.writeln('Local references checked: $localChecked');
  stdout.writeln('URLs checked: $urlChecked');
  if (warnings.isNotEmpty) {
    stdout.writeln('Warnings:');
    warnings.forEach(stdout.writeln);
  }
  if (failures.isNotEmpty) {
    stderr.writeln('Broken links:');
    failures.forEach(stderr.writeln);
    stderr.writeln('LINK CHECK FAILED: ${failures.length} broken link(s).');
    exitCode = 1;
    return;
  }
  stdout.writeln('LINK CHECK PASSED.');
}

bool _looksLikeFile(String target) =>
    target.endsWith('.md') ||
    target.endsWith('.dart') ||
    target.endsWith('.yaml');

bool _exists(Directory root, String target) {
  final f = File(
    '${root.path}${Platform.pathSeparator}'
    '${target.replaceAll('/', Platform.pathSeparator)}',
  );
  return f.existsSync();
}

enum _UrlResult { ok, transient, failed }

Future<_UrlResult> _checkUrl(String url) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.headUrl(Uri.parse(url));
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode < 400 ? _UrlResult.ok : _UrlResult.failed;
      } finally {
        client.close(force: true);
      }
    } on SocketException {
      // Fall through to retry; last failure is transient.
    } on TimeoutException {
      // Fall through to retry; last failure is transient.
    } on HttpException {
      return _UrlResult.failed;
    }
  }
  return _UrlResult.transient;
}
