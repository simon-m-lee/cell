import 'dart:io';

const header = '''
// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

''';

void main() {
  final dir = Directory('lib');
  for (var entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = entity.readAsStringSync();
      if (!content.contains('SPDX-License-Identifier')) {
        entity.writeAsStringSync(header + content);
        print('Added copyright to: ${entity.path}');
      }
    }
  }
}