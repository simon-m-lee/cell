// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// This file is documentation only: it is not imported by application code.
// It exists solely for dartdoc `{@template}` / `{@macro}` expansion used by
// the `### AI Agent Guide` blocks in public doc comments.
//
// Convention: CONTRIBUTING-AI-DOC.md. Do not import this library.

/// Doc-only library holding the shared `{@template}` dartdoc definitions
/// expanded by the `{@macro}` references in the `### AI Agent Guide` blocks
/// of `package:cell_tissue`.
///
/// This library is not imported by application code.
// ignore: unnecessary_library_name
library cell_tissue_ai_anti_patterns;

/// Shared **anti-pattern templates** for the `### AI Agent Guide` blocks.
///
/// This class exists only to give dartdoc a public anchor for the
/// `{@template}` / `{@macro}` definitions below; it has no runtime behavior.
///
/// {@template ai-do-not-testcell-on-tissue}
/// **DON'T** put `testRule: TestCell` on any `TissueList` / `TissueMap` /
/// `TissueSet` / `TissueQueue` / `TissueValue` constructor. Use `TestTissue`.
/// This is grep-checked by the `constraint` group in `<stem>-test.dart`.
/// {@endtemplate}
///
/// {@template ai-do-not-dart-list-as-system-of-record}
/// **DON'T** keep a plain Dart `List` / `Map` as the system of record when
/// the WalkThrough named a Tissue book. Mutation signals and TestTissue
/// validation only exist on the Tissue types.
/// See `HowTo-Mitose-Tissue.md` §9 "Anti-patterns".
/// {@endtemplate}
///
/// {@template ai-do-not-drain-tissuequeue}
/// **DON'T** drain a `TissueQueue` as the only working list if you still
/// need the queue as history. The TissueQueue is the **audit enqueue**; a
/// Dart list + `_driveAlert` / `_driveRtu` is the retry-once pump.
/// See `HowTo-Mitose-Tissue.md` §2.4 "TissueQueue — outbound work".
/// {@endtemplate}
///
/// {@template ai-do-not-two-lists-for-compliance}
/// **DON'T** keep two lists "for compliance" instead of one book plus a
/// `.unmodifiable` / `.deputy` view. One book, many surfaces.
/// See `HowTo-Mitose-Tissue.md` §9 "Anti-patterns".
/// {@endtemplate}
///
/// {@template ai-do-not-invent-sixth-collection}
/// `TissueGraph`, `TissueTree`, `TissueBag` **do not exist**. The five
/// collection types are `TissueList`, `TissueSet`, `TissueMap`,
/// `TissueQueue`, `TissueValue`.
/// See `HowTo-Mitose-Tissue.md` §2 "Examine all five collections".
/// {@endtemplate}
///
/// {@template ai-do-not-put-pii-on-event-rows}
/// **DON'T** put passenger names / NHS numbers on `Event` rows when the BRD
/// names privacy (BR-04). Omit the field, or sanitize via `Cell.sanitized`.
/// See `HowTo-Mitose-Tissue.md` §9 "Anti-patterns".
/// {@endtemplate}
class AiAntiPatterns {}
