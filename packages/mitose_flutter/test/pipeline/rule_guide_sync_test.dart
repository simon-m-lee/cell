// Phase B test: rule-guide sync check.
//
// Every rule in placement_rules.dart / anti_patterns.dart must have a
// `### \`ruleName\`` section in docs/placement-guide.md, and every
// such section must reference a real rule.

import 'dart:io';

import 'package:mitose_flutter/src/rules/anti_patterns.dart';
import 'package:mitose_flutter/src/rules/placement_rules.dart';
import 'package:test/test.dart';

Set<String> guideRuleSections() {
  final guide = File('docs/placement-guide.md').readAsStringSync();
  return RegExp(r'^### `(\w+)`', multiLine: true)
      .allMatches(guide)
      .map((m) => m.group(1)!)
      .toSet();
}

void main() {
  final codeRules = {
    for (final rule in allPlacementRules) rule.name,
    for (final rule in allAntiPatternRules) rule.name,
  };

  test('every rule has a section in the placement guide', () {
    final sections = guideRuleSections();
    final missing = codeRules.difference(sections);
    expect(missing, isEmpty,
        reason: 'add a `### `<rule>`` section to docs/placement-guide.md '
            'for: ${missing.join(', ')}');
  });

  test('every rule section has a rule in code', () {
    final sections = guideRuleSections();
    final orphan = sections.difference(codeRules);
    expect(orphan, isEmpty,
        reason: 'remove or implement these guide sections: '
            '${orphan.join(', ')}');
  });

  test('the guide documents all eight patterns', () {
    final guide = File('docs/placement-guide.md').readAsStringSync();
    for (final pattern in [
      'DisplayPattern',
      'SelectorPattern',
      'AsyncPattern',
      'FormPattern',
      'RestorePattern',
      'RoutePattern',
      'AuditPattern',
      'IsolationPattern',
    ]) {
      expect(guide, contains(pattern), reason: 'pattern $pattern documented');
    }
  });
}
