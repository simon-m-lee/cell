# cell_flutter_devtools_extension

The **source** of the DevTools extension web app shipped by
[`cell_flutter_devtools`](../cell_flutter_devtools). Not published — the
compiled output is copied into `cell_flutter_devtools/extension/devtools/build/`.

## Run locally

```bash
flutter pub get
flutter run -d chrome --dart-define=use_simulated_environment=true
```

The simulated environment provides a fake DevTools connection for fast
development. This package *is* the extension web app, so the runnable
surface is `lib/main.dart`; the
[`example/`](example/lib/cell_flutter_devtools_extension_example.dart)
entry boots the same UI the way DevTools does.

## Tests

```bash
flutter test
```

The widget tests inject fake fetch functions (the real `ServiceLedgerClient`
imports web-only `package:devtools_extensions` APIs and stays out of the VM
test path); `contract_test.dart` parses the provider package's real
serializer output through this UI's model. The generated
[test verification report](TEST_VERIFICATION.md) lists all 12 tests and is
regenerated with `python3 tool/generate_test_verification.py --run-tests`.

## Documentation

- [Documentation index](doc/INDEX.md) — the file map and verification notes.
- [CHANGELOG.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter_devtools_extension/CHANGELOG.md) —
  internal release history.
- [`cell_flutter_devtools` README](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter_devtools/README.md) —
  the published package this app ships inside.

## Build into the provider package

```bash
dart run devtools_extensions build_and_copy \
  --source=. \
  --dest=../cell_flutter_devtools/extension/devtools
dart run devtools_extensions validate --package=../cell_flutter_devtools
```
