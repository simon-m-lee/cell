# Changelog

## 0.1.0

Initial (repository-internal) release — the DevTools extension web app
source shipped by `cell_flutter_devtools`. `publish_to: none`: this
package exists in the repository only; its compiled output is copied into
`cell_flutter_devtools/extension/devtools/build/`.

### Added

- `DevToolsExtension` root widget and `LedgerView` — summary panel,
  filter bar (command / vetted / time range), collapsible receipt rows
  with full JSON, and 500ms live polling.
- `ServiceLedgerClient` — the VM-service fetch path (web-only imports,
  isolated from the VM test path via injected fakes).
- `DevtoolsLedgerEntry` / `DevtoolsRejectionEntry` /
  `DevtoolsLedgerSnapshot` — the client-side wire model.
- 12 tests including `contract_test.dart`, which pins this UI's model to
  `cell_flutter_devtools`'s serializer output.
- `tool/generate_test_verification.py` → `TEST_VERIFICATION.md` — the
  generated test report.
- `example/` — boots the extension UI the way DevTools does.
- `doc/INDEX.md` — the documentation index.
