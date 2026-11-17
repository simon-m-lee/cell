# Contributing to cell_flutter

## Development loop

```bash
cd packages/cell_flutter
flutter pub get
flutter analyze          # must be clean
flutter test             # full suite (widget tests, fuzz, soak, goldens)
dart doc .               # must be warning-free
```

Ecosystem packages live beside this one and gate the same way:

```bash
cd ../cell_flutter_router && flutter analyze && flutter test
cd ../cell_flutter_persistence && flutter analyze && flutter test
cd ../cell_flutter_lints && dart test
cd ../cell_flutter/example/production_app && flutter analyze && flutter test
```

## Quality gates

- **Tests**: every behavior change ships with tests; the suite must
  pass with `--coverage` and ≥95% line coverage of `lib/`.
- **Goldens**: run `flutter test --update-goldens test/golden` and
  review the diff when visuals intentionally change.
- **Benchmarks**: `dart run tool/benchmark.dart` must pass the 15%
  regression gate; re-baseline only deliberately
  (`--update`, reviewed in the PR).
- **Docs**: update the relevant `guide/HowTo-*.md` and, for shape
  changes, `ARCHITECTURE-flutter.md`.

## API stability (1.0.0 policy)

The public surface of `cell_flutter.dart`, `hooks.dart`, and the
documented `testing.dart` test API is frozen as of 1.0.0:

- Breaking changes require a **major** version bump.
- Deprecations warn for at least one minor version before removal.
- Features land in **minor** versions.
- Ecosystem packages version independently and may stay 0.x until
  their own 1.0.0.
- Anything not exported from a public barrel is fair game.

Never invent APIs from memory: resolve live signatures from the
package sources in this repository or from pub.dev.

## Spelling

The project name is **Mitose** (the German verb). Do not "correct" it
to "Mitosis".
