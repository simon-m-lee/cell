// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('v1.0 acceptance', () {
    test('the fraud-detection pipeline runs end-to-end', () async {
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'example/09_acceptance.dart'],
        workingDirectory: Directory.current.path,
      );
      expect(result.exitCode, 0,
          reason: 'stderr: ${result.stderr}\nstdout: ${result.stdout}');
      final stdout = result.stdout as String;
      expect(stdout, contains('=== Acceptance pipeline complete ==='));
      expect(stdout, contains('decisions: 32'));
      expect(stdout, contains('trained: 30 resolved'));
      expect(stdout, contains('debate: accept'));
      expect(stdout, contains('explainSource: 32 decision(s)'));
      expect(stdout, contains('=== OK ==='));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
