# cell_audit_demo — the live "Audit Trail" demo

One screen proves the Cell framework's core proposition in under a minute:
**auditable, reversible, governed state.**

> **Try it live:** https://simon-m-lee.github.io/cell/audit-trail/
> (deployed by `.github/workflows/audit_demo_deploy.yml`)

## What the demo shows

| Zone | What it proves |
|---|---|
| **The app** (left) | A counter with three buttons: **Add +5** (valid mutation), **Try invalid mutation** (rejected by the `TestCell` integrity gate), **Undo last change** (the recorded compensation, executed inside a real `Cell.txApply` transaction). |
| **The ledger** (right) | One card per real `ApplyReceipt` minted by the `cell` package: command label, receipt ID, timestamp, the capability-manifest `vetted` flag, before → after values, the compensation blueprint, and — for rejected commands — a red border with the gate's reason. |
| **The proof** (bottom) | *"This is the Cell difference: every state change is a record you can audit, a gate you can enforce, and a command you can undo."* |

Nothing is mocked. The ledger is populated only by receipts produced by
`Cell.apply` — the demo's cell has **no `value = …` setter** at all, which
is exactly why the ledger never stays empty.

## The three mechanisms (non-negotiable)

1. **`Cell.apply` for every mutation** — receipts only exist for commands.
   The counter extends `CellBase` and its command functions
   (`add` / `subtract` / `negative`) are the only mutation path.
2. **`TestCell` for the rejection** — an `AuditGate` overrides `action()`
   and rejects the `negative` command; the "Try invalid mutation" button
   produces a real `ApplyRejected` outcome and the state does not change.
3. **`Cell.txApply` for the undo** — the add command carries a
   `compensation` blueprint (attached through the command DSL's
   `.undo(...)`), and the undo button executes that compensation inside a
   `Cell.txApply` transaction, so the reversal gets its own receipt
   (`ApplyStaged` with a `txSequence`) alongside the original mutation.

## Run locally

```bash
cd demo/audit_trail
flutter pub get
flutter run -d chrome          # or any desktop/web device
flutter test                   # the demo's acceptance tests (5 tests)
```

The local `dependency_overrides` point at the in-repo `packages/cell` and
`packages/cell_flutter`; remove them to resolve the published versions.

## Build for deployment

```bash
flutter build web --release \
  --base-href /cell/audit-trail/ \
  --pwa-strategy=none
```

The `--base-href` matches the GitHub Pages sub-path of this monorepo, and
`--pwa-strategy=none` disables the service worker so demo updates are never
cached.

## Embedding

- **Full page**: the deployed URL above.
- **Iframe**: Flutter web embeds in full-page mode —

  ```html
  <iframe src="https://simon-m-lee.github.io/cell/audit-trail/"
          width="1024" height="600" style="border:0"></iframe>
  ```

## Learn more

- **Should you use Cell at all?** — the
  [fair comparison page](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/doc/comparison.md)
  (Cell vs Riverpod, BLoC, Provider, GetX, Signals, with a decision tree).
- **Should you migrate, and how?** — the
  [Riverpod/BLoC migration guide](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/Migrating-From-Riverpod-BLoC.md).
- **The widget for this ledger** — [`cell_flutter_audit`](https://pub.dev/packages/cell_flutter_audit).
- **The debugging surface** — [`cell_flutter_devtools`](https://github.com/simon-m-lee/cell/tree/master/packages/cell_flutter_devtools).

## pub.dev integration (from the plan)

1. Record a 10-second loop (add → invalid → undo) at ~640×480, compress
   with `ffmpeg` to under 2 MB, and place the GIF near the top of the
   `cell_flutter` README.
2. Link the "Try it live" badge next to the GIF.

## Source size

`lib/main.dart` is the entire demo (under 500 lines, heavily commented).
Read it top-to-bottom in under five minutes.

## Deployment trigger

The GitHub Pages deployment (`.github/workflows/audit_demo_deploy.yml`)
runs on pushes to `master` that touch `demo/audit_trail/**` — a trivial
commit here is enough to re-trigger it. The repository's only branch is
`master` (not `main`).
