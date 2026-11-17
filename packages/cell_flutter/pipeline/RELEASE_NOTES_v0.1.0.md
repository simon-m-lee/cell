# mitose_flutter 0.1.0 — Release Notes (internal)

`mitose_flutter` 0.1.0 turns a structured BRD (`flutter-pipeline/v1`)
into a verified Flutter app built on cell_flutter. This is an internal
release: the package is not published anywhere (`publish_to: none`) and
no git tag is created, per the owner's standing constraint that this
working tree is never committed, pushed, or tagged.

## What ships

- The full pipeline: parse → place → walkthrough gate → design gate →
  generate code + tests → five-category assessment → LEDGER.
- CLI `generate`, `verify`, `assess` with the documented exit codes.
- Three canonical BRDs (`form_heavy`, `list_heavy`, `async_heavy`) and
  their committed reference apps.

## Verification summary (all run in this working tree)

- `dart analyze`: clean.
- `dart test`: 121 passing, 6 skipped (opt-in compile gate and heuristic
  anti-pattern samples covered by dedicated tests).
- Compile gate (`PIPELINE_COMPILE=1`): each generated app passes
  `flutter pub get` + `flutter analyze` + `flutter test`
  (5/5, 5/5, 7/7 requirements).
- `verify` on all three BRDs: byte-identical to the committed
  references.
- Fresh-project end-to-end: generate → pub get → analyze → test →
  assess prints VERIFIED for all three BRDs.
- Rubric orthogonality: five deliberate defects each fail exactly one
  category.
- Failure contract: all 18 documented failure modes fire with the
  documented subtype, fix, and responsibility.
- Publish dry-run: the pubspec has the publishable shape (hosted
  dependency, homepage/repository, LICENSE, README, CHANGELOG,
  `.pubignore`). Because the working tree is never committed, pub cannot
  see the untracked files and reports them as hidden/missing; that
  limitation disappears once the files are tracked.

## Known scope limits (v0.1)

- Generated apps depend only on `cell_flutter`; navigation is plain
  `Navigator` (no cell_flutter_router dependency).
- Anti-pattern code checks are conservative regex heuristics over the
  fixed output shape.
- Pixel goldens, accessibility, localization, and performance are out
  of the rubric's scope by design.
