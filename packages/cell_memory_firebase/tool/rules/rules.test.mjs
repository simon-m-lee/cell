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
  ['unsigned get', () => testEnv.unauthenticatedContext().firestore().doc(path()).get(), 'deny'],
  ['other uid get', () => testEnv.authenticatedContext(otherUid).firestore().doc(path()).get(), 'deny'],
  ['other uid set', () => testEnv.authenticatedContext(otherUid).firestore().doc(path()).set(validDoc(1)), 'deny'],
  ['owner create revision 1, string payload', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set(validDoc(1)), 'allow'],
  ['owner create revision 2', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set(validDoc(2)), 'deny'],
  ['owner update +1, same kind and codec', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set(validDoc(2)), 'allow'],
  ['owner update skip revision', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set(validDoc(3)), 'deny'],
  ['owner update changes kind', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(2), kind: 'snapshot' }), 'deny'],
  ['owner update payload as list', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(2), payload: [1, 2] }), 'deny'],
  ['owner update payload as map', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(2), payload: { a: 1 } }), 'deny'],
  ['owner set of the same revision again', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set(validDoc(2)), 'deny'],
  ['owner create with an extra key', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(1), extra: true }), 'deny'],
  ['owner create with schema 2', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(1), schema: 2 }), 'deny'],
  ['owner create with a fixed updatedAt', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(1), updatedAt: now() }), 'deny'],
  ['owner delete', () => testEnv.authenticatedContext(uid).firestore().doc(path()).delete(), 'allow'],
];

let failed = 0;
for (const [name, run, expected] of cases) {
  try {
    if (expected === 'deny') {
      await assertFails(run());
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
  ['create without generation', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(1), generation: undefined }), 'deny'],
  ['create with kind pulse', () => testEnv.authenticatedContext(uid).firestore().doc(path()).set({ ...validDoc(1), kind: 'pulse' }), 'deny'],
  ['create id "bad id"', () => testEnv.authenticatedContext(uid).firestore().doc(`users/${uid}/cell_memory/bad id`).set({ ...validDoc(1), id: 'bad id' }), 'deny'],
  ['create id "."', () => testEnv.authenticatedContext(uid).firestore().doc(`users/${uid}/cell_memory/.`).set({ ...validDoc(1), id: '.' }), 'deny'],
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
