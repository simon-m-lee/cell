// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

// ignore_for_file: prefer_mixin
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: unused_element

// int? _RANDOM_PRIME;
// int get RANDOM_PRIME => _RANDOM_PRIME ??= <int>[2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97][randomBetween(0,24)];

// bool DEBUG_ENABLE = Logger.root.level <= Level.INFO;

final _relTypeMatch = RegExp('(${[
  'Relation',
  'Has',
  'HasOne',
  'BelongsTo',
  'RelationMany',
  'HasMany',
  'ManyToMany'
].join('|')})<?');
bool _isRelationType(Type type) => _relTypeMatch.hasMatch(type.toString());

const ignore = Object();

// Set<M> _extractTopLevelOne<M extends One>(Relatable source) {
//   final elements = Set<M>.identity();
//   parse(Relatable relatable) {
//     if (relatable is Many) {
//       relatable.forEach(parse);
//     } else if (relatable is RelationOne<M,M>) {
//       if (relatable is HasOne<M,M> && relatable.one != null) {
//         elements.add(relatable.one as M);
//       }
//     } else if (relatable is M) {
//       elements.add(relatable);
//     }
//   }
//   parse(source);
//   return elements;
// }

extension BetterSymbol on Symbol {
  String asString() => toString().split('"')[1];
}

String symbolAsString(Symbol symbol) => symbol.toString().split('"')[1];

class Alias {
  final List<String> tags;
  const Alias(this.tags);
}

class ConstRegExp implements RegExp {
  static final Map<Symbol, RegExp> _cache = {};

  final String _pattern;

  const ConstRegExp(this._pattern);

  RegExp get _regExp => _cache[Symbol(_pattern)] ??= RegExp(_pattern);

  @override
  Iterable<RegExpMatch> allMatches(String input, [int start = 0]) {
    return _regExp.allMatches(input, start);
  }

  @override
  RegExpMatch? firstMatch(String input) {
    return _regExp.firstMatch(input);
  }

  @override
  bool hasMatch(String input) {
    return _regExp.hasMatch(input);
  }

  @override
  bool get isCaseSensitive => _regExp.isCaseSensitive;

  @override
  bool get isDotAll => _regExp.isDotAll;

  @override
  bool get isMultiLine => _regExp.isMultiLine;

  @override
  bool get isUnicode => _regExp.isUnicode;

  @override
  Match? matchAsPrefix(String string, [int start = 0]) {
    return _regExp.matchAsPrefix(string, start);
  }

  @override
  String get pattern => _pattern;

  @override
  String? stringMatch(String input) {
    return _regExp.stringMatch(input);
  }
}
