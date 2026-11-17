// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/avoid_cell_creation_in_build.dart';
import 'src/rules/collection_selector_without_equals.dart';
import 'src/rules/forgotten_cell_dispose.dart';
import 'src/rules/unkeyed_hook_builder.dart';

/// Creates the cell_flutter_lints plugin.
PluginBase createPlugin() => _CellFlutterLintsPlugin();

class _CellFlutterLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        AvoidCellCreationInBuildRule(),
        UnkeyedHookBuilderRule(),
        ForgottenCellDisposeRule(),
        CollectionSelectorWithoutEqualsRule(),
      ];
}
