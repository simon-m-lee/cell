// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:flutter/material.dart';

/// The demo's palette: the plan's outcome colors plus a calm dark
/// smart-home surface.
abstract final class AppTheme {
  static const accepted = Color(0xFF4CAF50);
  static const rejected = Color(0xFFF44336);
  static const staged = Color(0xFF9C27B0);
  static const amber = Color(0xFFFFC107);
  static const thermostat = Color(0xFF2196F3);
  static const energy = Color(0xFF00BCD4);

  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.dark,
        surface: const Color(0xFF16181D),
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF101216),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF16181D),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1D2026),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2A2E36)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2E36),
        thickness: 1,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: const Color(0xFFE6E9EF),
        displayColor: const Color(0xFFE6E9EF),
        fontFamily: 'Roboto',
      ),
    );
  }
}
