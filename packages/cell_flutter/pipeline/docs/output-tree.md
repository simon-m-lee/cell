# Output Tree — `flutter-pipeline/v1`

This document pins the **canonical directory tree** the pipeline
writes. The structural-invariants rubric category checks every
generated file against this tree; a file outside it fails the pipeline
(`StructuralInvariantFailure / WrongOutputTree`). Any change to this
tree is a schema version bump (`flutter-pipeline/v2`) and a major
pipeline release.

## The tree

```
<out>/
  lib/
    main.dart                # CellScope, CellRestorationScope, CellErrorBoundary, MaterialApp
    screens/
      <screen_name>.dart     # one file per screen in ## Screens
    cells/
      <cell_name>.dart       # one file per cell in ## State with AppLevel: yes
  test/
    app_test.dart            # the testWidgets file with LEDGER lines
  pubspec.yaml               # the generated app's pubspec, depending on cell_flutter
  analysis_options.yaml      # the lint config with cell_flutter_lints enabled
  README.md                  # a minimal README describing how to run the app
```

## File purposes and required contents

### `lib/main.dart`

- Imports `cell_flutter`, `flutter/material`, the `cells/` files for
  app-level cells, and the `screens/` files.
- `void main()` calls `runApp(const App())`.
- `App.build` contains, in order, outermost to innermost:
  1. `CellScope` — required whenever `## State` has `AppLevel: yes`
     rows; registers every app-level cell.
  2. `CellRestorationScope` — required whenever `## State` has
     `Restorable: yes` rows.
  3. `CellErrorBoundary` — **always** required.
  4. `MaterialApp` — `title` from the BRD's `title`; `routes` from
     `## Screens`; `initialRoute` = the first screen's route.

### `lib/screens/<screen_name>.dart`

- One `StatelessWidget` per screen, named `<ScreenName>Screen`
  (`LoginScreen`, `HomeScreen`, …).
- Contains the widgets placed by the rules for that screen's
  requirements, assembled by the design generator's composition
  algorithm (Scaffold + AppBar + body Column in v0.1).

### `lib/cells/<cell_name>.dart`

- One top-level cell per `AppLevel: yes` state row.
- `Cell.restorableState<T>` when `Restorable: yes`, `Cell.state<T>`
  otherwise; the initial value comes from the BRD's `Initial` column.

### `test/app_test.dart`

- One `testWidgets` per requirement, in `REQ-###` order.
- Each test contains exactly one `LEDGER('REQ-###', '…')` line whose
  kind matches the requirement's `Type` (see `docs/rubric.md`).

### `pubspec.yaml`

- `name:` from the BRD title, sanitized to a Dart package name.
- `dependencies: cell_flutter: ^1.0.0, flutter (sdk)`; the code
  generator adds `cell_flutter_router` when any requirement uses the
  route pattern.
- `dev_dependencies: flutter_test, cell_flutter_lints ^0.1.0`.

### `analysis_options.yaml`

- Includes the `cell_flutter_lints` recommended set.

### `README.md`

- Minimal: what the app is, `flutter pub get` / `flutter run` /
  `flutter test`.

## Properties the writer guarantees

1. **Deterministic bytes** — LF line endings, trailing newline, stable
   file ordering (sorted by path). `verify` diffs byte-for-byte.
2. **Complete tree** — exactly the files above for the BRD's shapes;
   no extra files.
3. **Validated before writing** — the writer refuses a file outside
   this tree.
4. **Atomic-ish** — the writer writes to a temp directory and renames,
   so a partial write never leaves a half-app.

## Not part of the tree

- The LEDGER (`LEDGER.md`) is a **pipeline artifact**, written to a
  sibling `ledgers/` directory — not into the app.
- `example/generated/` reference apps (repository artifacts, not
  generator output at runtime).
- `.dart_tool/`, `build/`, platform folders (created by `flutter pub
  get` / `flutter run`, never by the pipeline).
