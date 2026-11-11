# Contributing to package:cell_tissue

- General contribution guidance lives in the repository root.
- **AI-facing doc-comment convention:** [`CONTRIBUTING-AI-DOC.md`](CONTRIBUTING-AI-DOC.md) —
  the normative spec for the `### AI Agent Guide` blocks appended to public
  doc comments (the `### AI Agent Guide` convention). Every doc-comment
  change must keep the block parseable by `tool/ai_guide_doc.dart`.
- **Checks before pushing:**
  - `dart analyze .`
  - `dart run tool/ai_preflight.dart` (exits 0; pins fresh)
  - `dart run tool/generate_ai_examples.dart` and
    `dart run tool/generate_api_chooser.dart` (generated files committed)
  - `dart test`
