// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The walkthrough generator — places every requirement and renders
/// the Gate 1 artifact.
library;

import '../brd/ast.dart';
import '../brd/walkthrough.dart';
import '../rules/placement_rules.dart';

/// Generates the walkthrough for [brd] by placing each requirement.
///
/// Throws [UnplaceableSentence] if any requirement cannot be placed.
Walkthrough generateWalkthrough(Brd brd) {
  final steps = <WalkthroughStep>[];
  for (final req in brd.requirements) {
    final choice = place(req, brd);
    final testTemplate = choice.pattern.toTestTemplate(req);
    steps.add(WalkthroughStep(
      requirementId: req.id,
      type: req.type,
      screen: req.screen,
      description: req.sentence,
      widget: choice.widget,
      widgetDetails: choice.pattern.widgetDetails(),
      trigger: req.trigger,
      assertion: testTemplate.assertion,
      ledger: testTemplate.ledger,
    ));
  }
  return Walkthrough(title: brd.title, steps: steps);
}
