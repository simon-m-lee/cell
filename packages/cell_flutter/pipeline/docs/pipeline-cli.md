# Pipeline CLI Contract — `mitose_flutter 0.1.0`

This document is the **CLI contract**: the three commands, the three
human-review gates, the flags, and the exit codes. Phase E implements
exactly what this document specifies; a deviation is a Phase A bug, not
a Phase E feature.

---

## 1. The three commands

### 1.1 `mitose_flutter generate <brd.md> --out <dir>`

Runs the pipeline end-to-end:

1. Validate + parse the BRD.
2. Place every requirement (`placement_rules.dart`).
3. Generate the walkthrough → **Gate 1**.
4. Generate the design → **Gate 2**.
5. Generate the code + tests.
6. Run the five-category rubric → **Gate 3**.
7. If the assessment is `verified`, write the app to `--out` and emit
   the LEDGER. If it is `notVerified`, exit 1 and write nothing.

Flags: `--out <dir>` (required), `--no-gates`, `--dry-run`,
`--schema=<path>`, `--verbose`.

### 1.2 `mitose_flutter verify <brd.md>`

Runs the pipeline end-to-end **with `--no-gates`**, then compares the
generated files byte-for-byte against the committed reference at
`pipeline/example/generated/<stem>/`.

- Exit **0** — identical (and the assessment is `verified`).
- Exit **1** — assessment failed, reference missing, or any file
  differs (a unified diff is printed).
- Used by CI as the pipeline's regression guard.

Flags: `--schema=<path>`, `--verbose`.

### 1.3 `mitose_flutter assess <brd.md> [--app <dir>]`

Runs only the rubric against an already-generated app.

- Loads the app from `--app <dir>` (defaults to
  `pipeline/example/generated/<stem>/`).
- Re-generates the walkthrough and design in memory (they are not
  stored in the app) and runs `assess`.
- Prints the assessment Markdown.
- Exit **0** if `verified`, **1** if `notVerified`, **2** if the app
  directory does not exist.

Flags: `--app <dir>`, `--schema=<path>`, `--verbose`.

---

## 2. The three human-review gates

`generate` pauses at three gates. Each gate renders an artifact, then
prompts:

```
================================================================
GATE: Walkthrough
================================================================

<rendered artifact>

Approve this walkthrough?
[a]pprove / [r]eject / [v]iew raw / [q]uit:
```

| Response | Effect |
|---|---|
| `a` / `approve` | continue to the next step |
| `r` / `reject` | stop; exit **0** (deliberate rejection); no files written |
| `v` / `view-raw` | print the artifact's raw Markdown, re-prompt |
| `q` / `quit` / `abort` | stop; exit **2** (unexpected interruption) |

The gates:

1. **Walkthrough** — the per-requirement plan (widget + assertion +
   LEDGER per requirement).
2. **Design** — the per-screen widget tree.
3. **Assessment** — the five-category rubric report. If the outcome is
   `notVerified`, the gate is **skipped**: the pipeline exits 1 before
   prompting. A failed assessment can never be approved.

Gate decisions read from `stdin` and are per-run (never persisted).

## 3. Flags

| Flag | Commands | Meaning |
|---|---|---|
| `--out, -o <dir>` | generate | Output directory (required). The writer deletes and rewrites it. |
| `--no-gates` | generate | Skip the three prompts. The assessment still runs and still gates the write. |
| `--dry-run` | generate | Run everything, write nothing. |
| `--schema=<path>` | all | Custom schema path (defaults to `docs/brd-schema.json`). |
| `--app, -a <dir>` | assess | App directory to assess. |
| `--verbose, -v` | all | Log each pipeline step with timing. |

## 4. Exit codes

| Code | Meaning |
|---|---|
| `0` | success — or deliberate rejection at a gate |
| `1` | failure — schema violation, unplaceable sentence, rule violation, structural invariant failure, or failed assessment |
| `2` | unexpected — usage errors (unknown command, missing `--out`), abort, or a pipeline bug |

## 5. Worked example

```console
$ mitose_flutter generate login.bfd.md --out ./my_login_app
mitose_flutter: parsing BRD...
  title: Login Flow
  requirements: 5
  screens: 2

mitose_flutter: placing requirements...

================================================================
GATE: Walkthrough
================================================================
# Walkthrough: Login Flow
...
[a]pprove / [r]eject / [v]iew raw / [q]uit: a

mitose_flutter: designing widget tree...

================================================================
GATE: Design
================================================================
# Design: Login Flow
...
[a]pprove / [r]eject / [v]iew raw / [q]uit: a

mitose_flutter: generating code...
mitose_flutter: assessing...

================================================================
GATE: Assessment
================================================================
# Assessment: Login Flow
- coverage — PASS
- placementCorrectness — PASS
- antiPatternCompliance — PASS
- verificationCompleteness — PASS
- structuralInvariants — PASS
...
[a]pprove / [r]eject / [v]iew raw / [q]uit: a

mitose_flutter: writing to ./my_login_app...
mitose_flutter: done.
  app: ./my_login_app
  LEDGER: ./ledgers/login_flow.md
  assessment: verified
```

## 6. The `--help` sketch

```
$ mitose_flutter --help
mitose_flutter — generate a verified Flutter app from a BRD.

Usage:
  mitose_flutter generate <brd.md> --out <dir> [--no-gates] [--dry-run] [--verbose]
  mitose_flutter verify <brd.md> [--verbose]
  mitose_flutter assess <brd.md> [--app <dir>] [--verbose]
  mitose_flutter --version
  mitose_flutter --help

Commands:
  generate  Run the pipeline end-to-end. Prompts at three gates: walkthrough,
            design, assessment. Writes the generated app to --out.
  verify    Run the pipeline with --no-gates and compare against the committed
            reference. Exits 0 if identical, 1 if different. Used by CI.
  assess    Run only the assessment rubric against an already-generated app.

Flags:
  --no-gates     Skip the human-review gates (for CI).
  --dry-run      Run the pipeline but do not write files.
  --schema=<path>  Use a custom schema (defaults to docs/brd-schema.json).
  --out <dir>    The output directory (required for `generate`).
  --app <dir>    The app directory for `assess`.
  --verbose      Log each pipeline step.

Exit codes:
  0  success (or deliberate rejection at a gate)
  1  failure (schema, placement, anti-pattern, structural, or assessment)
  2  unexpected error
```

## 7. CI usage

```yaml
- name: Verify form_heavy
  working-directory: packages/cell_flutter/pipeline
  run: dart run bin/mitose_flutter.dart verify example/brds/form_heavy.bfd.md
```

`verify` is the only command CI calls; it never prompts.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `SchemaValidationFailure` | BRD violates the schema | Read the message; fix the BRD (see `docs/failure-modes.md`) |
| `UnplaceableSentence: NoRuleMatches` | Rule gap | Report to the pipeline maintainer |
| `UnplaceableSentence: ContextCheckFailed` | BRD context incomplete | Add the missing state/screen row |
| `verify` mismatch | Output changed | Regenerate the reference intentionally (same PR) |
| Hang in CI | Gates waiting on stdin | Use `--no-gates` in CI |
