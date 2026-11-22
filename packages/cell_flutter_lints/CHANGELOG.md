# Changelog

## 0.1.1

- Add the missing pub.dev example entry point (`example/lib/main.dart`,
  a rule-clean counter app) — recovers the 10 "Package has an example"
  score points.
- Widen the `analyzer` constraint to `>=8.4.0 <15.0.0` — recovers the 10
  "dependencies supported in the latest version" score points.
  Resolution still picks the 8.4.x analyzer that `custom_lint_builder`
  0.8 pins through `custom_lint_visitor`.

## 0.1.0

- Initial release: four custom_lint rules for cell_flutter anti-patterns
  (`cell_avoid_creation_in_build`, `cell_unkeyed_hook_builder`,
  `cell_forgotten_dispose`, `cell_collection_selector_without_equals`)
  with `// expect_lint:` fixture verification.
