// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Runs the custom_lint CLI against the example package. Every
// `// expect_lint: <code>` comment in example/lib is verified by the
// custom_lint client itself: an unmet expectation is an ERROR-level
// diagnostic, which fails the CLI run.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('every expect_lint fixture in example/ is fulfilled', () async {
    final exampleDir =
        Directory('${Directory.current.path}${Platform.pathSeparator}example');
    expect(exampleDir.existsSync(), isTrue,
        reason: 'example directory must exist');

    final result = await Process.run(
      'dart',
      ['run', 'custom_lint', '--no-fatal-infos', '--no-fatal-warnings'],
      workingDirectory: exampleDir.path,
    );

    if (result.exitCode != 0) {
      fail(
        'custom_lint failed (exit ${result.exitCode}):\n'
        '${result.stdout}\n${result.stderr}',
      );
    }
    expect(result.stdout.toString(), isNot(contains('unfulfilled_expect_lint')),
        reason: 'an expect_lint comment did not match a lint');
  });
}
