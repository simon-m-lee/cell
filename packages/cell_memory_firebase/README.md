# cell_memory_firebase

Cloud Firestore backend for `cell_memory`. Flutter only.

The app calls `Firebase.initializeApp` before opening the store; the store
does not. The app signs the user in; the store is given the uid — it does
not read `FirebaseAuth.instance`, and `firebase_auth` is not a dependency.

## Install

```console
flutter pub add cell_memory_firebase
```

## Usage

```dart
import 'package:cell_memory/cell_memory.dart';
import 'package:cell_memory_firebase/cell_memory_firebase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final store = FirebaseMemoryStore(
  firestore: FirebaseFirestore.instance,
  uid: user.uid,
);

final memory = await remember<int>(
  counter.cell,
  id: 'cart',
  store: store,
  codec: JsonMemoryCodec<int>.identity(),
  project: (pulse) => pulse.payload as int? ?? 0,
);
```

The cell, the envelope, and the synapse attach stay the same as the file
store; only the `store` argument changes. For cells fed by fast pulse
streams, pass `policy: firestoreWritePolicy` to stay inside Firestore's
per-document write budget.

## Path

Every document lives at `users/{uid}/cell_memory/{id}`. `{id}` is the
memory id and uses the shared grammar `^[A-Za-z0-9._-]{1,128}$`, with `.`
and `..` rejected like the file store. Each document carries the record's
`generation` — 32 lowercase hex characters minted on the create and frozen
on every update; see the rules below and the core README's versioning
policy. A deputy is not a second Firebase user: the principal and the
deputy send the same token, and the in-process `TestCell` is the only
lesser-permission check.

## Security rules

Deploy `firestore.rules` (or the equivalent) from this package. A new
project stays deny-all until you do — do not ship `if true`. The package
never deploys rules. The rules enforce the exact key set (`hasOnly`), so
an unknown key is rejected like the strict decoder; `kind` is `value` and
`generation` must match `^[0-9a-f]{32}$` and is frozen on update, so a
stale generation after a delete-and-recreate is rejected at the server;
`payload` is always a JSON string on the wire, so the rule checks one
shape; `kind`, `codec`, and `sourceCellId` are frozen after create, `id`
and `schema` are frozen, create requires `revision == 1`, update requires
`revision == resource.data.revision + 1`, and `updatedAt == request.time`.
A client-supplied `DateTime` in `updatedAt` is rejected. Deploy the Dart
protocol and these rules in the same change: `hasOnly` rejects a client
that starts writing `generation` against the previous (0.1.0) rules.

## Offline and retries

`write` is one `runTransaction` whose compare-and-swap read is inside the
callback. `runTransaction` does not run against the offline cache: an
offline write fails with `MemoryIoException`, `lastError` is set, and the
memory cell stays dirty until a later turn reaches the server. **Writes
require connectivity** — nothing is queued while offline; the caller
decides what to retry. Reads use `Source.server` by default, so a load
never silently returns stale cached state; pass
`readSource: Source.cache` to opt back into cache reads. A stale revision
loaded before going offline becomes a real `MemoryConflict` on the next
write (the cell does not reschedule on its own).

Permission-denied is `MemoryIoException`, never `MemoryConflict`. When the
SDK retries after a lost commit response — or the caller retries a write
whose commit actually landed — the callback recognises its own payload at
`expectedRevision + 1` and returns without `set`: a second write of the
same revision would fail the update rule. The equal-revision retry shape
(the store already holds exactly this `(id, revision, payload)` row) is a
no-op too, matching the other backends. This cannot distinguish "my
retry" from "another device wrote the same value"; both are treated as
success, which is the documented, deliberately permissive choice.

Every transaction outcome — success, `MemoryConflict`, or `MemoryCorrupt`
— is returned out of the callback and thrown outside `runTransaction`, so
the failure type survives platform channels and SDK retry machinery. A
thrown `MemoryCorrupt` inside `runTransaction` is a bug, not a feature.
An existing document that fails strict decoding (newer schema, unknown
keys, foreign id) is never overwritten; a document that exists with null
data is corrupt, not absent.

`list()` fails closed: an id that fails the memory id grammar (a document
written by the Admin SDK or before the rules were deployed) fails the
whole call with `MemoryCorrupt` and deletes nothing — it is not
filtered out.

## Firestore limits

Documents are capped at 1 MiB: `write` measures the encoded document and
fails with `MemoryNotSerializable` before any transaction when it is too
large, instead of a generic `invalid-argument` from the server. One
document sustains roughly one sustained write per second; prefer
`firestoreWritePolicy` (debounced at 1 s) for cells fed by fast pulse
streams, and pass `transactionTimeout` / `transactionMaxAttempts` to tune
`runTransaction`. `list()` downloads every full document, payloads
included, and bills a read each — expected cardinality is small (one
document per memory id per user); ids that fail the memory id grammar are
filtered out. Deploy `firestore.indexes.json` to exempt `payload` from
single-field indexing.

## Number semantics across platforms

The web encodes `1.0` as `1`. `JsonMemoryCodec<double>.identity()` now
decodes an `int` payload as a `double`, so a VM client loads web-written
doubles; an `int` cell still rejects fractional payloads. For custom
codecs, prefer `(payload as num).toDouble()` in the `fromJson` mapping.

## Lifecycle

One store per session: the uid is fixed at construction. Close the store
(and its cells) on sign-out and build a fresh one after the next sign-in.
`close()` drains in-flight operations before refusing new ones. `remove`
deletes without an expected revision, so the revision history resets to 1
after a delete — the honest ABA shape that the `generation` protocol now
closes: a stale writer still carrying the previous life's generation is a
`MemoryConflict`, never a win. A hostile client that skips
`FirebaseMemoryStore` entirely stays outside the Dart CAS; the rules are
the boundary for it (see above).

## Security boundary

Firestore is plaintext: the console and the Admin SDK can read every cell,
and the security boundary is `firestore.rules`, not the Dart CAS — a
modified client or a stolen token bypasses `FirebaseMemoryStore.write`
entirely. Deploy the shipped rules (see above); add App Check at the app
level if you need to bind requests to your app builds. The Dart store's
1 MiB guard is client convenience; Firestore enforces the document limit
server-side regardless.

## No snapshot listener

v1 is request/response only. A snapshot listener is not on by default;
adding one later must ignore writes whose `sourceCellId` is the local cell,
or the listener will echo.

## Verified against

`cell_memory` 1.0.0 (monorepo path `packages/cell_memory`),
`cloud_firestore` 5.6.12, `firebase_core` 3.15.2. Resolved with
`pubspec_overrides.yaml` against the local `packages/` sources; the
published spec resolves `cell_memory ^1.0.0` from pub.dev.

## Emulator and CI

The emulator jobs are **required CI** (`.github/workflows/memory.yml`),
not scheduled-optional: `firebase emulators:exec --only firestore` runs
the rules harness, and `firebase emulators:exec --only firestore,auth`
runs the tagged two-client acceptance test — the job fails if the
acceptance test is skipped. `firebase.json` names `firestore.rules` and
`firestore.indexes.json` and pins Firestore to `127.0.0.1:8088` and Auth
to `127.0.0.1:9099`; nothing binds `0.0.0.0`. `tool/rules` is a Node
harness (`@firebase/rules-unit-testing`) that loads the canonical
`firestore.rules` file. The Dart unit tests use a scripted double that
runs the transaction handler; a green fake run does **not** prove the
rules, request.auth, or server timestamps — the emulator jobs do.
