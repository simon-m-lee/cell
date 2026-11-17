// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Visualisation for [CellGraph] and [Ledger].
///
/// ### When to use
/// The visualisation tooling ships two modes for each:
///
/// * **`cells`** — the graph's topology. Nodes are cells; edges are
///   `bind`/`Synapses` links. This is the *structural* view: "what
///   depends on what".
/// * **`deltas`** — the ledger's causal chain. Nodes are deltas; edges
///   are pulse order. This is the *forensic* view: "what changed, in
///   what order".
///
/// The two views answer different questions and both are useful. A
/// forensic audit typically starts with `deltas` (what happened) and
/// cross‑references against `cells` (who could have made it happen).
///
/// See also:
/// * [CellGraphVisualise] — renders a graph's topology.
/// * [LedgerVisualise] — renders a ledger's causal chain.
/// {@category Replay}
extension CellGraphVisualise on CellGraph {
  /// Renders this graph as a mermaid or DOT document.
  ///
  /// ### Parameters:
  /// - [format]: `'mermaid'` (default) or `'dot'`.
  ///
  /// ### Returns:
  /// The rendered document.
  String visualise({String format = 'mermaid'}) {
    final entries = roots;
    switch (format) {
      case 'mermaid':
        final buf = StringBuffer('graph LR\n');
        for (final r in entries) {
          buf.writeln('  ${_mmId(r.name)}["${r.name}"]');
          final upstream = r.cell._nucleus.bind;
          if (upstream != null) {
            buf.writeln(
              '  ${_mmId(upstream.id)} --> ${_mmId(r.name)}',
            );
          }
        }
        return buf.toString();
      case 'dot':
        final buf = StringBuffer('digraph CellGraph {\n  rankdir=LR;\n');
        for (final r in entries) {
          buf.writeln('  ${_dotId(r.name)} [label="${r.name}"];');
          final upstream = r.cell._nucleus.bind;
          if (upstream != null) {
            buf.writeln('  ${_dotId(upstream.id)} -> ${_dotId(r.name)};');
          }
        }
        buf.writeln('}');
        return buf.toString();
      default:
        throw ArgumentError.value(format, 'format', 'must be mermaid or dot');
    }
  }

  static String _mmId(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');

  static String _dotId(String s) => '"${s.replaceAll('"', '\\"')}"';
}

/// Visualisation for a [Ledger]'s entries (also used by the CLI).
extension LedgerVisualise on Ledger {
  /// Renders the ledger as a mermaid or DOT document.
  ///
  /// ### Parameters:
  /// - [format]: `'mermaid'` (default) or `'dot'`.
  /// - [mode]: Controls node type: `'deltas'` (default) or `'cells'`.
  ///
  /// ### Returns:
  /// The rendered document.
  Future<String> visualise({
    String format = 'mermaid',
    String mode = 'deltas',
  }) async {
    final entries = await entriesSince(0).toList();
    if (entries.isEmpty) {
      return format == 'mermaid' ? '%% Empty ledger' : '// Empty ledger';
    }
    final buf = StringBuffer();
    switch (format) {
      case 'mermaid':
        buf.writeln('graph LR');
        _renderMermaid(buf, entries, mode);
        break;
      case 'dot':
        buf.writeln('digraph Ledger {');
        buf.writeln('  rankdir=LR;');
        _renderDot(buf, entries, mode);
        buf.writeln('}');
        break;
      default:
        throw ArgumentError.value(format, 'format', 'must be mermaid or dot');
    }
    return buf.toString();
  }

  static void _renderMermaid(
    StringBuffer buf,
    List<LedgerEntry> entries,
    String mode,
  ) {
    switch (mode) {
      case 'deltas':
        // The naive `e${seq - 1}_0 --> id` edge assumes every entry has
        // a delta; ledgers can contain delta-less entries (the fork's
        // synthetic seq 0, hand-crafted appends). Track the previous
        // delta node instead so edges never dangle.
        String? previousNode;
        for (final e in entries) {
          for (var i = 0; i < e.deltas.length; i++) {
            final d = e.deltas[i];
            final id = 'e${e.seq}_$i';
            buf.writeln('  $id["seq ${e.seq}: ${d.cellId}"]');
            if (previousNode != null) {
              buf.writeln('  $previousNode --> $id');
            }
            previousNode = id;
          }
        }
        break;
      case 'cells':
        final seen = <String>{};
        for (final e in entries) {
          for (final d in e.deltas) {
            if (seen.add(d.cellId)) {
              buf.writeln(
                '  ${CellGraphVisualise._mmId(d.cellId)}["${d.cellId}"]',
              );
            }
          }
        }
        break;
      default:
        throw ArgumentError.value(mode, 'mode', 'must be deltas or cells');
    }
  }

  static void _renderDot(
    StringBuffer buf,
    List<LedgerEntry> entries,
    String mode,
  ) {
    switch (mode) {
      case 'deltas':
        String? previousNode;
        for (final e in entries) {
          for (var i = 0; i < e.deltas.length; i++) {
            final d = e.deltas[i];
            final id = 'e${e.seq}_$i';
            buf.writeln('  $id [label="seq ${e.seq}: ${d.cellId}"];');
            if (previousNode != null) {
              buf.writeln('  $previousNode -> $id;');
            }
            previousNode = id;
          }
        }
        break;
      case 'cells':
        final seen = <String>{};
        for (final e in entries) {
          for (final d in e.deltas) {
            if (seen.add(d.cellId)) {
              buf.writeln(
                '  ${CellGraphVisualise._dotId(d.cellId)} '
                '[label="${d.cellId}"];',
              );
            }
          }
        }
        break;
      default:
        throw ArgumentError.value(mode, 'mode', 'must be deltas or cells');
    }
  }
}
