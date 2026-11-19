# Release process — mitose_flutter (internal)

The pipeline is released internally only: `publish_to: none`, no pub.dev
publication, and no git tags.

## Per-release checklist

1. `dart pub get`
2. `dart format lib test bin tool`
3. `dart analyze`
4. `dart test`
5. `PIPELINE_COMPILE=1 dart test test/generator/compile_gate_test.dart`
6. `dart run tool/regenerate_references.dart`
7. `dart run bin/mitose_flutter.dart verify` on each canonical BRD:
   ```bash
   dart run bin/mitose_flutter.dart verify example/brds/form_heavy.bfd.md
   dart run bin/mitose_flutter.dart verify example/brds/list_heavy.bfd.md
   dart run bin/mitose_flutter.dart verify example/brds/async_heavy.bfd.md
   ```
8. Fresh-project smoke (generate → pub get → analyze → test → assess):
   ```bash
   dart run bin/mitose_flutter.dart generate example/brds/<stem>.bfd.md \
     --out /tmp/fresh-app --no-gates
   cd /tmp/fresh-app && flutter pub get && flutter analyze && flutter test
   cd ../.. && dart run bin/mitose_flutter.dart assess \
     example/brds/<stem>.bfd.md --app /tmp/fresh-app
   ```
9. `dart pub publish --dry-run` — validates the publishable shape of the
   pubspec (hosted `cell_flutter: any` dependency, homepage/repository,
   LICENSE, README, CHANGELOG). Because this working tree is never
   committed (owner constraint), pub cannot see the untracked files and
   reports them as hidden/missing; that limitation is expected and
   documented. Re-run the dry-run after the files are tracked to confirm
   zero errors.
10. Update `CHANGELOG.md` and `RELEASE_NOTES_v<version>.md`.

## Deliberately skipped

- Git tag: the owner's standing constraint forbids all git operations in
  this working tree, and a tag requires a commit. Tag the release later
  when the constraint is lifted.
- Pub.dev publication: `publish_to: none` is intentional for v0.1.
