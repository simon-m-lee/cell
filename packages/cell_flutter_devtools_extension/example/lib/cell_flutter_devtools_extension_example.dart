// The canonical named example program for cell_flutter_devtools_extension.
//
// This package *is* the extension web app, so the example simply boots
// the extension UI the way DevTools does:
//
//   flutter run -d chrome --dart-define=use_simulated_environment=true
//
// `example/lib/main.dart` is the thin entry point that delegates here.
library;

import 'package:cell_flutter_devtools_extension/main.dart';
import 'package:flutter/material.dart';

/// Runs the extension UI (delegated to from `example/lib/main.dart`).
void runCellFlutterDevtoolsExtensionExample() =>
    runApp(const CellDevToolsExtension());
