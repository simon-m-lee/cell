// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The LEDGER emitter.
///
/// The LEDGER is the pipeline's verification artifact: one line per
/// requirement (`RENDER` / `INTERACT` / `RECOVER`). The `Generated:`
/// timestamp is deliberately excluded from `verify` comparisons.
library;

/// One ledger entry.
class LedgerEntry {
  const LedgerEntry({
    required this.requirementId,
    required this.kind,
    required this.evidence,
  });

  final String requirementId;
  final String kind;
  final String evidence;
}

/// The parsed/collected LEDGER for a BRD.
class Ledger {
  const Ledger({
    required this.title,
    required this.schemaVersion,
    required this.generatedAt,
    required this.entries,
  });

  final String title;
  final String schemaVersion;
  final String generatedAt;
  final List<LedgerEntry> entries;

  /// The stable body — everything except the timestamp line.
  String stableBody() {
    final buffer = StringBuffer()
      ..writeln('# LEDGER — $title')
      ..writeln()
      ..writeln('**Schema:** $schemaVersion')
      ..writeln()
      ..writeln('| Requirement | Kind | Evidence |')
      ..writeln('|---|---|---|');
    for (final entry in entries) {
      buffer.writeln(
          '| ${entry.requirementId} | ${entry.kind} | ${entry.evidence} |');
    }
    return buffer.toString();
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln(stableBody().trimRight())
      ..writeln()
      ..writeln('Generated: $generatedAt');
    return buffer.toString();
  }
}

/// Extracts ledger entries from a generated test file.
///
/// Lines look like `LEDGER('REQ-001', 'rendered via CellTextField');`.
/// The evidence prefix (`rendered via` / `interacted via` /
/// `recovered via`) decides the kind.
List<LedgerEntry> ledgerFromTests(String testFileContent) {
  final entries = <LedgerEntry>[];
  final pattern = RegExp(r"LEDGER\('(REQ-\d+)', '([^']*)'\)");
  for (final match in pattern.allMatches(testFileContent)) {
    final evidence = match.group(2)!;
    final kind = evidence.startsWith('rendered')
        ? 'RENDER'
        : evidence.startsWith('interacted')
            ? 'INTERACT'
            : evidence.startsWith('recovered')
                ? 'RECOVER'
                : 'UNKNOWN';
    entries.add(LedgerEntry(
      requirementId: match.group(1)!,
      kind: kind,
      evidence: evidence,
    ));
  }
  return entries;
}
