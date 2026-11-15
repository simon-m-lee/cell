// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// The aggregated debate result — a typed, versioned journal effect.
/// ### When to use
/// Serialized into journal maps (`toMap` / `fromMap`); constructed by
/// the bridge layer, read by audit code.
///
/// ### How it works
/// An immutable value object over the journal-safe encodable form.
///
/// ### Non-obvious
/// - `at` is truncated to milliseconds for replay fingerprints.
/// - Reconstruction goes through `bridgeEffectFromMap`.
///
/// ### See also
/// - [debate], `guide/08-Agents.md`
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them.
///
/// {@category Organ}
/// {@category Agent}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class MindDebateEffect {
  final String winner;
  final int rounds;
  final Map<String, Map<String, String>> votesByRound;
  final bool consensusReached;
  final DateTime at;

  const MindDebateEffect({
    required this.winner,
    required this.rounds,
    required this.votesByRound,
    required this.consensusReached,
    required this.at,
  });

  Map<String, dynamic> toMap() => {
        'type': 'mind.debate',
        'version': '1.0.0',
        'winner': winner,
        'rounds': rounds,
        'votesByRound': votesByRound,
        'consensusReached': consensusReached,
        'at': _isoAt(at),
      };

  static MindDebateEffect fromMap(Map<String, dynamic> map) => MindDebateEffect(
        winner: map['winner'] as String,
        rounds: map['rounds'] as int,
        votesByRound: (map['votesByRound'] as Map).map(
          (k, v) => MapEntry(
            k as String,
            (v as Map).map(
              (k2, v2) => MapEntry(k2 as String, v2 as String),
            ),
          ),
        ),
        consensusReached: map['consensusReached'] as bool,
        at: DateTime.parse(map['at'] as String),
      );
}
