// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The mitose_flutter pipeline library.
///
/// Turns a structured BRD (`flutter-pipeline/v1`) into a verified
/// Flutter app built on cell_flutter.
library;

export 'src/brd/ast.dart';
export 'src/brd/design.dart';
export 'src/brd/parser.dart';
export 'src/brd/schema.dart';
export 'src/brd/walkthrough.dart';
export 'src/cli/command.dart';
export 'src/cli/gates.dart';
export 'src/cli/output.dart';
export 'src/failures.dart';
export 'src/ledger/emitter.dart';
export 'src/generator/code_generator.dart';
export 'src/generator/design_generator.dart';
export 'src/generator/generated_app.dart';
export 'src/generator/test_generator.dart';
export 'src/generator/walkthrough_generator.dart';
export 'src/rubric/assessor.dart';
export 'src/rubric/categories.dart';
export 'src/rules/anti_patterns.dart';
export 'src/rules/patterns.dart';
export 'src/rules/placement_rules.dart';
