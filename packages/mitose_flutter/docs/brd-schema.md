# BRD Schema — `flutter-pipeline/v1`

This document specifies the input contract of the HowTo-Mitose-Flutter
pipeline: the **Business Requirements Document (BRD)** format the
pipeline reads. The machine-readable source of truth is
[`brd-schema.json`](brd-schema.json) (JSON Schema draft 2020-12); this
document explains the same contract in human terms. When the two
disagree, **the JSON wins** — it is what the pipeline executes against.

A BRD is structured Markdown: a YAML frontmatter block followed by up
to five sections. The pipeline parses tables, validates every field,
and fails loudly when the document deviates from this contract.

---

## 1. The frontmatter

Every BRD begins with a YAML frontmatter block:

```markdown
---
schema: flutter-pipeline/v1
title: Login Flow
version: 1
---
```

| Field | Required | Meaning | Constraints |
|---|---|---|---|
| `schema` | yes | The pipeline contract version | Must be exactly `flutter-pipeline/v1` |
| `title` | yes | The app's name | Non-empty; becomes `MaterialApp.title` |
| `version` | yes | The BRD's own revision | Must be `1` in v1 |

A BRD without frontmatter fails with `SchemaValidationFailure /
MissingFrontmatter`. A BRD with a different `schema` value fails with
`UnknownSchemaVersion` — the message names the version it supports.

## 2. `## Requirements`

One row per requirement. Fixed column set:

| ID | Sentence | Screen | Trigger | Outcome | Type |
|---|---|---|---|---|---|

- **ID** — unique within the BRD; shape `REQ-\d{3,}` (e.g. `REQ-001`).
- **Sentence** — a single imperative sentence in third person, e.g.
  `User sees the email field`. The placement rules match on this text;
  see `docs/placement-guide.md` for the sentence patterns.
- **Screen** — the name of a screen in `## Screens` (cross-reference
  validated).
- **Trigger** — optional; the user action that satisfies the
  requirement, e.g. `tap Sign in`. **Required** when `Type` is
  `interaction` or `recovery`; may also be present on `display`
  rows (e.g. "type in search field" on a loading-indicator
  requirement) — the pipeline reads it for the test's interaction
  sequence and the walkthrough.
- **Outcome** — what the user sees or what happens.
- **Type** — one of four enumerated values:
  - `display` — the user sees something rendered.
  - `interaction` — the user does something and the app reacts.
  - `recovery` — a failure or error state is surfaced and recoverable.
  - `atomic` — a multi-step change that must be all-or-nothing.

## 3. `## Screens`

One row per screen. Fixed column set:

| Name | Route | Widgets |
|---|---|---|

- **Name** — e.g. `Login`; referenced by requirements' `Screen`
  column. Unique within the BRD.
- **Route** — e.g. `/login`; must start with `/`.
- **Widgets** — a comma-separated list of the widget types the screen
  uses, e.g. `CellTextField, ElevatedButton, CellListener`. This is
  the screen's top-level widget inventory, consumed by the design
  generator's composition algorithm.

## 4. `## Forms` (optional)

Present only when the app has form validation. Fixed column set:

| Name | Fields | Validator |
|---|---|---|

- **Name** — e.g. `LoginForm`.
- **Fields** — comma-separated field names; each field must have a
  matching state entry in `## State`.
- **Validator** — plain English, e.g. `email contains @, password
  length >= 8`. The pipeline turns this into validation code in the
  form pattern; a missing validator means the form has no validation.

## 5. `## State`

One row per reactive cell. Fixed column set:

| Name | Type | Initial | Restorable | AppLevel |
|---|---|---|---|---|

- **Name** — e.g. `email`; a lowercase-first Dart identifier. Unique
  within the BRD.
- **Type** — a Dart type expression, e.g. `String`, `List<Todo>`,
  `AuthState`, `AsyncValue`.
- **Initial** — the initial-value expression, e.g. `''`,
  `AuthState.signedOut`, `[]`. Empty means `null`.
- **Restorable** — `yes` or `no`. `yes` generates
  `Cell.restorableState<T>` and requires a `CellRestorationScope`
  (structural invariant).
- **AppLevel** — `yes` or `no`. `yes` generates a `lib/cells/` file
  and registers the cell in the root `CellScope`.

## 6. `## Context` (optional)

Free-form prose. The pipeline reads it for the walkthrough (it is
echoed there) but never acts on it — no rule reads `## Context`.

## 7. Structural constraints enforced by the validator

The JSON schema covers field shapes; the validator additionally
enforces cross-cutting rules that JSON Schema cannot express on
Markdown directly:

1. Required sections present: `## Requirements`, `## Screens`,
   `## State` (`## Forms`, `## Context` optional).
2. Table column sets are exactly as fixed above — extra columns fail.
3. Requirement IDs unique.
4. Screen names unique; state names unique.
5. Every requirement's `Screen` resolves to a `## Screens` row.
6. Every form field resolves to a `## State` row.
7. `interaction` and `recovery` requirements have a non-empty
   `Trigger`.
8. Every `State` row's `Restorable`/`AppLevel` is `yes` or `no`.

Each violation produces a `SchemaValidationFailure` with a line-level
location and a specific fix — see `docs/failure-modes.md`.

## 8. Versioning

This contract is pinned at **`flutter-pipeline/v1`**. Any change to
the schema — a new column, a renamed field, a new `Type` value — is a
new version (`flutter-pipeline/v2`) and a **major** pipeline release.
The pipeline rejects BRDs whose schema version it does not recognize;
it never guesses.

## 9. Minimal valid BRD

```markdown
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
```

## 10. Example BRDs

`pipeline/example/brds/` contains the three reference BRDs the
pipeline is validated against:

- `form_heavy.bfd.md` — a login flow (forms, validation, submission,
  error handling).
- `list_heavy.bfd.md` — a todo list (lists, add / delete / reorder,
  persistence).
- `async_heavy.bfd.md` — a search app (debounce, async fetch,
  loading / success / error / empty / retry).

All three validate against this schema; they are the acceptance test
for every phase of the pipeline.
