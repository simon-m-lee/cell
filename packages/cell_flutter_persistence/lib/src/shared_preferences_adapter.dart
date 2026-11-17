// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cell_persistence_adapter.dart';

/// A [CellPersistenceAdapter] over `SharedPreferencesAsync`.
///
/// The five primitive shapes (`String`, `int`, `bool`, `double`,
/// `List<String>`) are supported natively through the typed
/// `getX` / `setX` API. Custom types must provide [fromJson] /
/// [toJson] codecs:
///
/// ```dart
/// SharedPreferencesAdapter<MyState>(
///   prefs: prefs,
///   fromJson: (json) => MyState.fromJson(json as Map<String, Object?>),
///   toJson: (value) => value.toJson(),
/// );
/// ```
///
/// Use `SharedPreferencesAsync` (the non-deprecated API); obtain it in
/// production via `SharedPreferencesAsync()`, or pass
/// `InMemorySharedPreferencesAsync` in tests (from
/// `shared_preferences_platform_interface`).
class SharedPreferencesAdapter<T> implements CellPersistenceAdapter<T> {
  /// Creates the adapter.
  SharedPreferencesAdapter({
    required SharedPreferencesAsync prefs,
    T? Function(Object? json)? fromJson,
    Object? Function(T value)? toJson,
  })  : _prefs = prefs,
        _fromJson = fromJson,
        _toJson = toJson;

  final SharedPreferencesAsync _prefs;
  final T? Function(Object? json)? _fromJson;
  final Object? Function(T value)? _toJson;

  /// Adapter for [String] values.
  static SharedPreferencesAdapter<String> string(
          SharedPreferencesAsync prefs) =>
      SharedPreferencesAdapter<String>(prefs: prefs);

  /// Adapter for [int] values.
  static SharedPreferencesAdapter<int> integer(SharedPreferencesAsync prefs) =>
      SharedPreferencesAdapter<int>(prefs: prefs);

  /// Adapter for [bool] values.
  static SharedPreferencesAdapter<bool> boolean(SharedPreferencesAsync prefs) =>
      SharedPreferencesAdapter<bool>(prefs: prefs);

  /// Adapter for [double] values.
  static SharedPreferencesAdapter<double> double_(
          SharedPreferencesAsync prefs) =>
      SharedPreferencesAdapter<double>(prefs: prefs);

  /// Adapter for `List<String>` values.
  static SharedPreferencesAdapter<List<String>> stringList(
          SharedPreferencesAsync prefs) =>
      SharedPreferencesAdapter<List<String>>(prefs: prefs);

  @override
  Future<T?> read(String key) async {
    final codec = _fromJson;
    if (codec != null) {
      final raw = await _prefs.getString(key);
      if (raw == null) {
        return null;
      }
      return codec(jsonDecode(raw));
    }
    if (T == String) {
      return await _prefs.getString(key) as T?;
    }
    if (T == int) {
      return await _prefs.getInt(key) as T?;
    }
    if (T == bool) {
      return await _prefs.getBool(key) as T?;
    }
    if (T == double) {
      return await _prefs.getDouble(key) as T?;
    }
    if (T == List<String>) {
      return await _prefs.getStringList(key) as T?;
    }
    throw UnsupportedError(
      'SharedPreferencesAdapter<$T>: custom types require fromJson/toJson '
      'codecs.',
    );
  }

  @override
  Future<void> write(String key, T value) async {
    final codec = _toJson;
    if (codec != null) {
      await _prefs.setString(key, jsonEncode(codec(value)));
      return;
    }
    if (T == String) {
      await _prefs.setString(key, value as String);
    } else if (T == int) {
      await _prefs.setInt(key, value as int);
    } else if (T == bool) {
      await _prefs.setBool(key, value as bool);
    } else if (T == double) {
      await _prefs.setDouble(key, value as double);
    } else if (T == List<String>) {
      await _prefs.setStringList(key, value as List<String>);
    } else {
      throw UnsupportedError(
        'SharedPreferencesAdapter<$T>: custom types require fromJson/toJson '
        'codecs.',
      );
    }
  }

  @override
  Future<void> delete(String key) => _prefs.remove(key);
}
