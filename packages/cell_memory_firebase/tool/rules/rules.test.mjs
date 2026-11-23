// Optional rules harness for cell_memory_firebase.
//
// Runs only when a human or CI invokes it under the Firestore emulator:
//
//   firebase emulators:exec --only firestore \
//     --project demo-cell-memory "node tool/rules/rules.test.mjs"
//
// It loads the canonical ../../firestore.rules file, so the Dart package's
// rules and this harness cannot drift. The Dart fake tests do NOT evaluate
// rules, request.auth, or request.time; this harness is what covers them.

import { readFile } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { Timestamp, serverTimestamp } from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const rules = await readFile(join(here, '..', '..', 'firestore.rules'), 'utf8');
const projectId = 'demo-cell-memory';

// Under `firebase emulators:exec`, FIRESTORE_EMULATOR_HOST is already set
// (127.0.0.1:8088 per firebase.json): point the test environment at it
// instead of starting a second emulator on that port.
const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const [host = '127.0.0.1', port = '8080'] = emulatorHost
    ? emulatorHost.split(':')
    : [];

const testEnv = await initializeTestEnvironment({
  projectId,
  firestore: {
    rules,
    host,
    port: Number.parseInt(port, 10),
  },
});

const uid = 'user-a';
const otherUid = 'user-b';
const path = (u = uid) => `users/${u}/cell_memory/counter`;
const generation = '0123456789abcdef0123456789abcdef';
const generationB = 'abcdef0123456789abcdef0123456789';

const now = () => Timestamp.now();

// Seeds revision 1 for the update-shaped cases.
const seedRev1 = () => testEnv.authenticatedContext(uid).firestore().doc(path()).set(validDoc(1));

const validDoc = (revision) => ({
  id: 'counter',
  kind: 'value',
  revision,
  generation,
  // The rules demand `updatedAt == request.time`; only the server-timestamp
  // sentinel satisfies that.
  updatedAt: serverTimestamp(),
  schema: 1,
  payload: JSON.stringify({ n: revision }),
});

const cases = [
  // Each case clears the database first: the rules verdicts depend on the
  // document being absent (create) or on a seeded revision (update), and
  // rules-unit-testing shares one project across cases.
  ['unsigned get', null, () => testEnv.unauthenticatedContext().firestore().doc(path()).get(), 'deny'],
  ['other uid get', null, () => testEnv.authenticatedContext(otherUid).firestore().doc(path()).get(), 'deny'],
  ['other uid set', null, () => testEnv.authenticatedContext(otherUid).firestore().doc(path()).set(validDoc(1)), 'deny'],
  ['owner create revision 1, string payload', null, () => testEnv.authenticatedContext(uid).firestore().doc(path()).set(validDoc(1)), 'allow'],
  ['owner create revision 2', null, () => testEnv.authenticatedContext(uid).firestore().doc(path()).set(validDoc(2)), 'deny'],
  ['owner update +1, same kind and codec', seedRev1, () => testEnv.authenticatedContext(uid).firestore().doc(path()).set(validDoc(2)), 'allow'],
  ['owner update skip revision', seedRev1, () => testEnv.authenticatedContext(uid).firestore().doc(path()).set(validDoc(3)), 'deny'],
  ['owner update changes kind', seedRev1, () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(2), kind: 'snapshot' }), 'deny'],
  ['owner update payload as list', seedRev1, () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(2), payload: [1, 2] }), 'deny'],
  ['owner update payload as map', seedRev1, () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(2), payload: { a: 1 } }), 'deny'],
  ['owner set of the same revision again', seedRev1, () => testEnv.authenticatedContext(uid).firestore().doc(path()).set(validDoc(1)), 'deny'],
  ['owner create with an extra key', null, () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(1), extra: true }), 'deny'],
  ['owner create with schema 2', null, () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(1), schema: 2 }), 'deny'],
  ['owner create with a fixed updatedAt', null, () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(1), updatedAt: now() }), 'deny'],
  ['owner delete', seedRev1, () => testEnv.authenticatedContext(uid).firestore().doc(path()).delete(), 'allow'],
];

let failed = 0;
for (const [name, seed, run, expected] of cases) {
  await testEnv.clearFirestore();
  if (seed) await seed();
  try {
    if (expected === 'deny') {
      await assertFails(run());
    } else if (expected === 'deny-any') {
      // The emulator rejects some shapes before the rules ever run
      // (e.g. the resource id '.'); any thrown error proves the denial.
      let threw = false;
      try {
        await run();
      } catch (error) {
        threw = true;
      }
      if (!threw) throw new Error('Expected request to fail, but it succeeded.');
    } else {
      await assertSucceeds(run());
    }
    console.log(`ok   ${name}`);
  } catch (error) {
    failed++;
    console.error(`FAIL ${name}: ${error}`);
  }
}

// Generation and id-grammar group on a fresh document.
await testEnv.clearFirestore();
const generationCases = [
  ['create without generation', () => {
    // The key must be omitted, not set to undefined: the SDK rejects
    // undefined field values before the rules ever run.
    const doc = validDoc(1);
    delete doc.generation;
    return testEnv.authenticatedContext(uid).firestore().doc(path()).set(doc);
  }, 'deny'],
  ['create with kind pulse', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(1), kind: 'pulse' }), 'deny'],
  ['create id "bad id"', () => testEnv.authenticatedContext(uid).firestore().doc(`users/${uid}/cell_memory/bad id`).set({ ...validDoc(1), id: 'bad id' }), 'deny'],
  ['create id "."', () => testEnv.authenticatedContext(uid).firestore().doc(`users/${uid}/cell_memory/.`).set({ ...validDoc(1), id: '.' }), 'deny-any'],
  ['create id of 129 characters', () => testEnv.authenticatedContext(uid).firestore().doc(`users/${uid}/cell_memory/${'x'.repeat(129)}`).set({ ...validDoc(1), id: 'x'.repeat(129) }), 'deny'],
  ['owner create revision 1 with generation', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set(validDoc(1)), 'allow'],
  ['owner update +1, same generation', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set(validDoc(2)), 'allow'],
  ['owner update changes generation', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(3), generation: generationB }), 'deny'],
  ['owner delete', () => testEnv.authenticatedContext(uid).firestore().doc(path()).delete(), 'allow'],
  ['recreate revision 1 with a new generation', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(1), generation: generationB }), 'allow'],
  ['update of the new row with the old generation', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(2), generation }), 'deny'],
  ['update of the new row with the new generation', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(2), generation: generationB }), 'allow'],
];
for (const [name, run, expected] of generationCases) {
  try {
    if (expected === 'deny') {
      await assertFails(run());
    } else if (expected === 'deny-any') {
      let threw = false;
      try {
        await run();
      } catch (error) {
        threw = true;
      }
      if (!threw) throw new Error('Expected request to fail, but it succeeded.');
    } else {
      await assertSucceeds(run());
    }
    console.log(`ok   ${name}`);
  } catch (error) {
    failed++;
    console.error(`FAIL ${name}: ${error}`);
  }
}

await testEnv.cleanup();
if (failed > 0) {
  console.error(`${failed} rules case(s) failed`);
  process.exit(1);
}
console.log('all rules cases passed');
