# Changelog

## 1.0.0

The first public release; the `Unreleased` notes from the protocol and
store workstreams become this section. The breaking list: documents carry
`generation` (frozen on update), `kind == 'value'` only, the canonical
payload string, generation-matched set branches with `MemoryConflict`
carrying `stored`, transaction outcomes returned rather than thrown,
the shared `StoreLifecycle` shutdown barrier, and fail-closed `list`.
The `0.1.0` section below is history, kept for reference.


- **Breaking (protocol):** documents carry `generation`
  (`^[0-9a-f]{32}$`); a document without one does not decode, and 0.1.0
  rules reject writes from this change until the updated `firestore.rules`
  is deployed (ship both together). `kind == 'value'` only. The payload
  string is the canonical JSON (`JsonPayloadKey.canonical`), so a
  reversed-key retry matches the stored string. `firestore.rules` freezes
  `generation` on update and enforces the id grammar.
- **Breaking (CAS):** the set branch requires
  `stored.generation == envelope.generation`; every other
  present-document outcome is `MemoryConflict(..., stored: storedRow)`,
  returned out of the transaction callback. A stale generation after
  remove-and-recreate conflicts instead of winning the revision.
- **Breaking (stores):** the shared `StoreLifecycle` is the admission and
  shutdown barrier (a call that entered `run` finishes; a late call and a
  second `close` throw `StateError`). `MemoryCorrupt` is **returned**
  out of the transaction callback — a thrown `MemoryCorrupt` inside
  `runTransaction` is a bug; `FirebaseException` stays the only
  exception mapped to `MemoryIoException`. `list` fails closed: an id
  that fails the grammar fails the whole call and deletes nothing.

## 0.1.0

- Initial release.
- `FirebaseMemoryStore`: request/response Firestore backend for
  `cell_memory` 0.1.0. One document per memory id at
  `users/{uid}/cell_memory/{id}`.
- Compare-and-swap `write(expectedRevision:)` inside one `runTransaction`;
  the read that decides the swap is inside the callback. The idempotent
  retry recognises this writer's own payload at `expectedRevision + 1` and
  does not `set` again.
- `payload` is always a JSON string on the wire; `updatedAt` is a server
  timestamp on write and a UTC `DateTime` on read. Missing documents read
  as `null`.
- `firestore.rules` ships in the package (deny-by-default owner rules for
  the fixed path); the app deploys it — the package does not.
- No snapshot listener, no `firebase_auth`, no `firebase_database`. The app
  signs in and calls `Firebase.initializeApp`; the store is given the uid.
- Code review remediation: memory ids `.` and `..` are rejected like the
  file store; `read` and `list` wrap `FirebaseException` into
  `MemoryIoException` like `write` and `remove`; `decodeDocument` rejects
  unknown keys, matching the strict file envelope; the shared
  `MemoryStoreCas.checkNumbering` is reused instead of a local copy.
- Second review remediation (Grok): `MemoryConflict` is returned out of
  the transaction handler and translated outside `runTransaction` — never
  thrown inside a callback the SDK may re-run; `_isOwnPayload` compares
  exactly `MemoryEnvelope.sameContent`'s fields (payload, kind, codec) and
  no longer `sourceCellId`; `AUTHORS` added. A cached read whose
  `updatedAt` has not resolved is treated as corrupt (fail closed),
  matching the strict decode policy.
- Third review remediation (firebase review): reads use `Source.server` by
  default (constructor option `readSource`) so offline loads fail loudly
  instead of silently returning stale cache; an existing document is
  strictly decoded inside the transaction before it can be overwritten
  (a newer-schema record is `MemoryCorrupt`, never overwritten); encoding
  happens once before any I/O with a 1 MiB size guard and
  `MemoryNotSerializable` for unencodable payloads; `transactionTimeout`
  and `transactionMaxAttempts` are exposed; `list` filters ids that fail
  the shared `MemoryIdGrammar`; `close` drains in-flight operations; the
  shared id validator `MemoryIdGrammar` is exported from `cell_memory` and
  used by both stores; the identity codec decodes int payloads as doubles
  (web writes `1.0` as `1`); `firestoreWritePolicy` (1 s debounce) and
  `firestore.indexes.json` (payload single-field index exemption) ship;
  the rules harness gains extra-key, wrong-schema, and fixed-`updatedAt`
  cases and writes `serverTimestamp()` sentinels.
- Fourth review remediation (Grok firebase review): `list()` reads with the
  configured `readSource` too; a document that exists with null data is
  corrupt, not absent; every transaction outcome — including
  `MemoryCorrupt` from strict decoding — is returned out of the callback
  and thrown outside `runTransaction`; the equal-revision retry shape
  (stored row equals the envelope exactly) is a no-op, matching the other
  backends; `schema` must be an `int` (a double `1.0` is corrupt, not
  schema 1); in-process per-id serialisation chains order reads, writes,
  and removes like the other stores, and `list()` returns a settled
  snapshot; `encodeDocument` / `decodeDocument` are exported as the wire
  contract; `toString` added; the scripted double records `GetOptions` and
  tests pin `Source.server`/`Source.cache` and permission-denied on read
  and list.
