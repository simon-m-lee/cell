// Phase B tests: schema validator (positive + negative).

import 'dart:io';

import 'package:mitose_flutter/src/brd/schema.dart';
import 'package:mitose_flutter/src/failures.dart';
import 'package:test/test.dart';

String _example(String stem) =>
    File('example/brds/$stem.bfd.md').readAsStringSync();

String _minimalBrd({String extra = ''}) => '''
---
schema: flutter-pipeline/v1
title: Hello World
version: 1
---

## Requirements

| ID | Sentence | Screen | Trigger | Outcome | Type |
|---|---|---|---|---|---|
| REQ-001 | User sees the greeting | Home | | Greeting rendered | display |

## Screens

| Name | Route | Widgets |
|---|---|---|
| Home | / | CellBuilder |

## State

| Name | Type | Initial | Restorable | AppLevel |
|---|---|---|---|---|
| greeting | String | 'Hello, world!' | no | yes |
$extra''';

void main() {
  group('positive', () {
    for (final stem in ['form_heavy', 'list_heavy', 'async_heavy']) {
      test('$stem.bfd.md validates', () {
        expect(() => validateBrd(_example(stem), sourcePath: '$stem.bfd.md'),
            returnsNormally);
      });
    }

    test('a minimal BRD validates', () {
      expect(
        () => validateBrd(_minimalBrd(), sourcePath: 'min.bfd.md'),
        returnsNormally,
      );
    });

    test('a BRD with optional sections validates', () {
      final withForms = _minimalBrd(extra: '''
## Forms

| Name | Fields | Validator |
|---|---|---|
| GreetingForm | greeting | non-empty |

## Context

Free-form notes.
''');
      expect(
        () => validateBrd(withForms, sourcePath: 'forms.bfd.md'),
        returnsNormally,
      );
    });
  });

  group('negative', () {
    Matcher failsWith(String subtype, {List<String>? fixContains}) {
      var base = isA<SchemaValidationFailure>().having(
        (e) => e.errors.map((x) => x.subtype),
        'subtypes',
        contains(subtype),
      );
      if (fixContains != null) {
        for (final fragment in fixContains) {
          base = base.having(
            (e) => e.fix,
            'fix contains "$fragment"',
            contains(fragment),
          );
        }
      }
      return throwsA(base);
    }

    test('MissingFrontmatter', () {
      expect(
        () => validateBrd('# No frontmatter\n', sourcePath: 'x.bfd.md'),
        failsWith('MissingFrontmatter', fixContains: ['frontmatter']),
      );
    });

    test('UnknownSchemaVersion', () {
      final brd = _minimalBrd().replaceFirst(
          'schema: flutter-pipeline/v1', 'schema: flutter-pipeline/v2');
      expect(
        () => validateBrd(brd, sourcePath: 'x.bfd.md'),
        failsWith('UnknownSchemaVersion',
            fixContains: ['flutter-pipeline/v1', 'v2']),
      );
    });

    test('MissingSection — Screens', () {
      final brd = _minimalBrd().replaceAll('## Screens', '## OldScreens');
      expect(
        () => validateBrd(brd, sourcePath: 'x.bfd.md'),
        failsWith('MissingSection', fixContains: ['## Screens']),
      );
    });

    test('MissingField — interaction without Trigger', () {
      final brd = _minimalBrd().replaceFirst('display', 'interaction');
      expect(
        () => validateBrd(brd, sourcePath: 'x.bfd.md'),
        failsWith('MissingField', fixContains: ['Trigger']),
      );
    });

    test('InvalidType — bad Type value', () {
      final brd = _minimalBrd().replaceFirst('display', 'unknown');
      expect(
        () => validateBrd(brd, sourcePath: 'x.bfd.md'),
        failsWith('InvalidType', fixContains: ['display, interaction']),
      );
    });

    test('InvalidType — bad Restorable/AppLevel value', () {
      final brd = _minimalBrd().replaceFirst('no | yes', 'maybe | yes');
      expect(
        () => validateBrd(brd, sourcePath: 'x.bfd.md'),
        failsWith('InvalidType', fixContains: ['yes', 'no']),
      );
    });

    test('DuplicateId — requirement', () {
      const extraRow =
          '\n| REQ-001 | User sees the greeting again | Home | | Rendered | display |';
      final brd = _minimalBrd().replaceFirst(
          '| REQ-001 | User sees the greeting | Home | | Greeting rendered | display |',
          '| REQ-001 | User sees the greeting | Home | | Greeting rendered | display |$extraRow');
      expect(
        () => validateBrd(brd, sourcePath: 'x.bfd.md'),
        failsWith('DuplicateId', fixContains: ['unique']),
      );
    });

    test('DuplicateId — screen name', () {
      final brd = _minimalBrd().replaceFirst('| Home | / | CellBuilder |',
          '| Home | / | CellBuilder |\n| Home | /home | CellBuilder |');
      expect(
        () => validateBrd(brd, sourcePath: 'x.bfd.md'),
        failsWith('DuplicateId'),
      );
    });

    test('DuplicateId — state name', () {
      final brd = _minimalBrd().replaceFirst(
          "| greeting | String | 'Hello, world!' | no | yes |",
          "| greeting | String | 'Hello, world!' | no | yes |\n| greeting | int | 0 | no | no |");
      expect(
        () => validateBrd(brd, sourcePath: 'x.bfd.md'),
        failsWith('DuplicateId'),
      );
    });

    test('UnresolvedReference — screen', () {
      final brd = _minimalBrd().replaceFirst('| Home |', '| Dashboard |');
      expect(
        () => validateBrd(brd, sourcePath: 'x.bfd.md'),
        failsWith('UnresolvedReference', fixContains: ['Dashboard']),
      );
    });

    test('MalformedTable — extra column', () {
      final brd = _minimalBrd().replaceFirst(
        '| Name | Route | Widgets |',
        '| Name | Route | Widgets | Extra |',
      );
      expect(
        () => validateBrd(brd, sourcePath: 'x.bfd.md'),
        failsWith('MalformedTable', fixContains: ['Name | Route | Widgets']),
      );
    });

    test('frontmatter without title', () {
      final brd = _minimalBrd().replaceFirst('title: Hello World\n', '');
      expect(
        () => validateBrd(brd, sourcePath: 'x.bfd.md'),
        failsWith('MissingField', fixContains: ['title']),
      );
    });

    test('multiple violations are aggregated', () {
      final brd = _minimalBrd()
          .replaceFirst('display', 'unknown')
          .replaceFirst('| Home |', '| Dashboard |');
      try {
        validateBrd(brd, sourcePath: 'x.bfd.md');
        fail('should have thrown');
      } on SchemaValidationFailure catch (e) {
        expect(e.errors.map((x) => x.subtype),
            containsAll(['InvalidType', 'UnresolvedReference']));
        expect(e.report(), contains('x.bfd.md'));
      }
    });
  });
}
