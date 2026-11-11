// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Phase 3.3 of CONTRIBUTING-AI-DOC.md: `dart run tool/ai_preflight.dart`
// must exit 0 on master. This test imports the same logic so CI fails the
// moment a pin drifts.

import 'package:test/test.dart';

import '../tool/ai_preflight.dart';

void main() {
  test('all doc-comment and HowTo pins match resolved versions', () async {
    final exitCode = await runPreflight();
    expect(exitCode, 0,
        reason: 'A Live signature: / HowTo pin is stale. Run '
            '`dart run tool/ai_preflight.dart` for the report.');
  });
}
