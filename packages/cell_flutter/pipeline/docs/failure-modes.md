# Failure Modes — `flutter-pipeline/v1`

This document is the pipeline's **error contract**. Every failure the
pipeline can produce is listed here with its trigger, its message
format, its fix, and its responsibility. The Phase F test suite asserts
each failure fires exactly as documented; a failure not in this
document is a pipeline bug.

## How to read an entry

```
<FailureType>: <SubType>
  BRD:        <the file the pipeline was reading>
  Location:   <where in the BRD or generated app>
  Reason:     <what went wrong>
  Fix:        <what the developer should do>
  Responsibility: <BRD_AUTHOR | PIPELINE_MAINTAINER | APP_AUTHOR>
```

**Responsibility** tells you who fixes it:

- **`BRD_AUTHOR`** — the developer who wrote the BRD; the fix is in the
  BRD.
- **`PIPELINE_MAINTAINER`** — the pipeline has a bug or a rule gap; the
  developer should report it.
- **`APP_AUTHOR`** — the developer edited the generated app; the fix is
  in the generated code.

Misattributing a failure sends a developer to the wrong place. The
pipeline's messages always carry the attribution.

---

## 1. `SchemaValidationFailure` — the BRD is not well-formed

Responsibility: **BRD_AUTHOR** (the fix is in the BRD).

### 1.1 `MissingFrontmatter`

- **Trigger:** the BRD has no `---` frontmatter block, or the block is
  empty.
- **Message:**
  ```
  SchemaValidationFailure: MissingFrontmatter
    BRD: login.bfd.md
    Location: line 1
    Reason: missing the required frontmatter block.
    Fix: Add a YAML frontmatter block with `schema: flutter-pipeline/v1`,
         `title: <name>`, and `version: 1` at the top of the file.
  ```
- **Fix:** add the frontmatter block.

### 1.2 `UnknownSchemaVersion`

- **Trigger:** the frontmatter's `schema` is not `flutter-pipeline/v1`.
- **Message:**
  ```
  SchemaValidationFailure: UnknownSchemaVersion
    BRD: login.bfd.md
    Location: frontmatter
    Reason: schema version "v2" is not supported; this pipeline supports
            "flutter-pipeline/v1".
    Fix: Change the schema version to `flutter-pipeline/v1`, or upgrade the
         pipeline to a version that supports "v2".
  ```
- **Fix:** change the schema version, or upgrade the pipeline.

### 1.3 `MissingSection`

- **Trigger:** a required section is absent. Required:
  `## Requirements`, `## Screens`, `## State`. (`## Forms` and
  `## Context` are optional.)
- **Message:**
  ```
  SchemaValidationFailure: MissingSection
    BRD: login.bfd.md
    Location: (section)
    Reason: missing the required section `## Screens`.
    Fix: Add a `## Screens` section with the table described in
         docs/brd-schema.md.
  ```
- **Fix:** add the section.

### 1.4 `MissingField`

- **Trigger:** a table row is missing a required field. Also fires when
  `Type` is `interaction` or `recovery` and `Trigger` is empty.
- **Message:**
  ```
  SchemaValidationFailure: MissingField
    BRD: login.bfd.md
    Location: ## Requirements, row 2
    Field: Trigger
    Reason: Type is "interaction" but Trigger is empty.
    Fix: Provide a Trigger value (e.g., "tap Sign in"), or change Type to
         "display".
  ```
- **Fix:** fill the field, or change `Type`.

### 1.5 `InvalidType`

- **Trigger:** a field has an illegal value — `Type` outside
  `display|interaction|recovery|atomic`, `Restorable`/`AppLevel`
  outside `yes|no`, a state name that is not an identifier, a route
  that does not start with `/`.
- **Message:**
  ```
  SchemaValidationFailure: InvalidType
    BRD: login.bfd.md
    Location: ## Requirements, row 2
    Field: Type
    Reason: "unknown" is not a legal Type value.
    Fix: Use one of: display, interaction, recovery, atomic.
  ```
- **Fix:** use a legal value.

### 1.6 `DuplicateId`

- **Trigger:** two requirements share an `ID` (or two screens share a
  `Name`, two state rows share a `Name`).
- **Message:**
  ```
  SchemaValidationFailure: DuplicateId
    BRD: login.bfd.md
    Location: ## Requirements, row 3
    Reason: duplicate requirement ID "REQ-001" (also used in row 1).
    Fix: Use a unique ID for each requirement.
  ```
- **Fix:** make the IDs unique.

### 1.7 `UnresolvedReference`

- **Trigger:** a requirement's `Screen` names a screen that is not in
  `## Screens`; a form field names a state entry that does not exist.
- **Message:**
  ```
  SchemaValidationFailure: UnresolvedReference
    BRD: login.bfd.md
    Location: ## Requirements, row 2
    Reason: screen "Dashboard" is not in `## Screens`.
    Fix: Add "Dashboard" to `## Screens`, or change the requirement's
         Screen to an existing screen.
  ```
- **Fix:** add the referenced row or fix the reference.

### 1.8 `MalformedTable`

- **Trigger:** a section's table cannot be parsed (wrong column count,
  a missing header separator).
- **Message:**
  ```
  SchemaValidationFailure: MalformedTable
    BRD: login.bfd.md
    Location: ## Screens
    Reason: expected the fixed column set "Name | Route | Widgets" but the
            table has 4 columns.
    Fix: Restore the fixed column set; extra columns are not allowed in
         flutter-pipeline/v1.
  ```
- **Fix:** restore the fixed column set.

---

## 2. `UnplaceableSentence` — the BRD is well-formed but no rule can place a requirement

The BRD passed validation, but the placement rules cannot turn a
requirement into a widget choice. The pipeline **never guesses** — it
stops.

### 2.1 `NoRuleMatches`

Responsibility: **PIPELINE_MAINTAINER** (a rule gap).

- **Trigger:** no placement rule's matcher matches the sentence.
- **Message:**
  ```
  UnplaceableSentence: NoRuleMatches
    BRD: search.bfd.md
    Requirement: REQ-009
    Sentence: "User can export the results as CSV"
    Reason: no rule matches this sentence.
    Fix: Report this to the pipeline maintainer; the rule library needs a
         new rule for this sentence shape.
  ```
- **Fix:** report to the pipeline maintainer; a new rule is needed.

### 2.2 `ContextCheckFailed`

Responsibility: **BRD_AUTHOR** (the BRD's context is incomplete).

- **Trigger:** a rule matched, but its context check failed — the
  sentence names a cell / screen / form that the BRD does not define
  (or defines with the wrong type).
- **Message:**
  ```
  UnplaceableSentence: ContextCheckFailed
    BRD: login.bfd.md
    Requirement: REQ-001
    Sentence: "User sees the email field"
    Reason: the requirement names the "email" field, but `## State` has no
            entry named "email".
    Fix: Add a row to `## State` for "email", or reword the requirement to
         name an existing field.
  ```
- **Fix:** add the missing state entry, or reword the sentence.

### 2.3 `AmbiguousMatch`

Responsibility: **PIPELINE_MAINTAINER** (a rule overlap).

- **Trigger:** two or more rules match the same sentence, and the
  pipeline refuses to choose.
- **Message:**
  ```
  UnplaceableSentence: AmbiguousMatch
    BRD: login.bfd.md
    Requirement: REQ-001
    Sentence: "User sees the email field"
    Reason: two rules match: placeDisplayField and placeDisplayText.
    Fix: Report this to the pipeline maintainer; the rule library has an
         ambiguity between these two rules.
  ```
- **Fix:** report to the pipeline maintainer.

---

## 3. `RuleViolation` — the generated code violates an anti-pattern

These fire when the pipeline's own output (or a developer's edit of it)
violates a do-NOT rule. When the generated app triggers one, it is a
pipeline bug; when a hand-edited app does, it is the app author's.

### 3.1 `CellInBuild`

- **Trigger:** a `Cell` is created inside a `build` method.
- **Message:**
  ```
  RuleViolation: CellInBuild
    File: lib/screens/login_screen.dart:14
    Reason: `Cell.state` called inside `build`.
    Fix: Move the cell creation to the widget's State (initState) or to a
         `lib/cells/` file. If this is generated code, this is a pipeline
         bug — report it.
  ```
- **Fix (app author):** move the cell out of `build`.
- **Fix (pipeline maintainer):** fix the generator.

### 3.2 `WritableCellToChild`

- **Trigger:** a writable `ValueCell` is passed to a child widget that
  should not write.
- **Message:**
  ```
  RuleViolation: WritableCellToChild
    File: lib/screens/home_screen.dart:22
    Reason: writable ValueCell passed to child widget `CounterTile`.
    Fix: Pass `cell.unmodifiable` to the child, or move the write into the
         parent. If this is generated code, this is a pipeline bug — report it.
  ```
- **Fix:** pass `unmodifiable`, or report the pipeline bug.

### 3.3 `RawObserveInWidget`

- **Trigger:** `Cell.observe` is called inside a widget.
- **Message:**
  ```
  RuleViolation: RawObserveInWidget
    File: lib/screens/home_screen.dart:18
    Reason: `Cell.observe` called inside a widget.
    Fix: Use `CellListener` instead of a raw observation link. If this is
         generated code, this is a pipeline bug — report it.
  ```
- **Fix:** use `CellListener`.

### 3.4 `SetStateOnCell`

- **Trigger:** `setState` updates a value a cell already holds.
- **Message:**
  ```
  RuleViolation: SetStateOnCell
    File: lib/screens/home_screen.dart:26
    Reason: `setState` called to update a cell-held value.
    Fix: Write `cell.value = ...` instead of `setState`. If this is
         generated code, this is a pipeline bug — report it.
  ```
- **Fix:** write the cell instead of `setState`.

### 3.5 `UnkeyedHookBuilder`

- **Trigger:** an unkeyed `HookBuilder` is used where a cell swap can
  occur (heuristic — documented as such in the placement guide).
- **Message:**
  ```
  RuleViolation: UnkeyedHookBuilder
    File: lib/screens/home_screen.dart:31
    Reason: unkeyed HookBuilder around a cell-swappable binding.
    Fix: Give the HookBuilder a Key derived from the cell, or restructure
         to avoid the swap. If this is generated code, this is a pipeline
         bug — report it.
  ```
- **Fix:** key the builder, or report the pipeline bug.

---

## 4. `StructuralInvariantFailure` — the generated app violates a top-level rule

Responsibility: **PIPELINE_MAINTAINER** when the generator produced it;
**APP_AUTHOR** when an edit removed it.

### 4.1 `NoCellScopeAtRoot`

- **Trigger:** `lib/main.dart` has no `CellScope` at the root.
- **Message:**
  ```
  StructuralInvariantFailure: NoCellScopeAtRoot
    File: lib/main.dart
    Reason: no CellScope at the root of the app.
    Fix: Wrap the app in a CellScope. If this is generated code, this is a
         pipeline bug — the generator did not emit a CellScope. Report it.
  ```

### 4.2 `NoErrorBoundaryAtRoot`

- **Trigger:** `lib/main.dart` has no `CellErrorBoundary` wrapping the
  app (the rubric requires it always).
- **Message:**
  ```
  StructuralInvariantFailure: NoErrorBoundaryAtRoot
    File: lib/main.dart
    Reason: no CellErrorBoundary wrapping the app.
    Fix: Wrap the app in a CellErrorBoundary. If this is generated code,
         this is a pipeline bug — report it.
  ```

### 4.3 `RestorableWithoutScope`

- **Trigger:** a `Cell.restorableState` exists but no
  `CellRestorationScope` encloses it.
- **Message:**
  ```
  StructuralInvariantFailure: RestorableWithoutScope
    File: lib/main.dart
    Reason: restorable cells exist (## State has Restorable: yes rows) but
            there is no CellRestorationScope.
    Fix: Wrap the app in a CellRestorationScope. If this is generated code,
         this is a pipeline bug — report it.
  ```

### 4.4 `WrongOutputTree`

- **Trigger:** the generated file set does not match the canonical tree
  in `docs/output-tree.md` (`flutter-pipeline/v1`).
- **Message:**
  ```
  StructuralInvariantFailure: WrongOutputTree
    File: (tree)
    Reason: file "lib/widgets/counter.dart" is not part of the expected
            output tree `flutter-pipeline/v1`.
    Fix: This is a pipeline bug — the generator's tree is wrong. Report it.
  ```

---

## 5. The failure contract

1. Every failure names the file, the location, the reason, and the fix.
2. Every failure carries a responsibility attribution.
3. The pipeline never guesses: an unplaceable sentence stops the
   pipeline; it does not produce a best-effort app.
4. `generate` exit codes: `1` for any failure above, `2` for an
   unexpected error, `0` for success or deliberate gate rejection.
