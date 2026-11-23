// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:io';

import 'package:cell_memory_firebase/cell_memory_firebase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// One booted Firebase boundary: the app, the Firestore instance, and the
/// shared uid every kiosk signs in as.
typedef FirebaseBoot = ({FirebaseApp app, FirebaseFirestore db, String uid});

/// The kiosks' shared user. Two anonymous sign-ins would be two
/// different accounts (and two Firestore paths); the twins are one
/// venue, so both windows sign in as the same fixed user on the
/// emulator. On a real project, replace with the venue's account.
const String kioskEmail = 'kiosk@example.com';
const String kioskPassword = 'kiosk-password';

/// Boots Firebase against the emulator (defaults per `firebase.json`;
/// the host env wins when the emulator suite exports it).
Future<FirebaseBoot> bootFirebase() async {
  final emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  final firestoreHost = emulatorHost?.split(':').first ?? '127.0.0.1';
  final firestorePort = emulatorHost != null
      ? int.tryParse(emulatorHost.split(':')[1]) ?? 8088
      : 8088;

  const projectId = String.fromEnvironment('PROJECT',
      defaultValue: 'demo-cell-memory');
  const authHost =
      String.fromEnvironment('AUTH_HOST', defaultValue: '127.0.0.1');
  const authPort = int.fromEnvironment('AUTH_PORT', defaultValue: 9099);

  final app = await Firebase.initializeApp(
    name: 'kiosk-twins',
    options: FirebaseOptions(
      apiKey: 'demo',
      appId: 'demo',
      messagingSenderId: 'demo',
      projectId: projectId,
    ),
  );
  final db = FirebaseFirestore.instanceFor(app: app);
  db.settings = const Settings(persistenceEnabled: false, sslEnabled: false);
  db.useFirestoreEmulator(firestoreHost, firestorePort);

  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator(authHost, authPort);
  try {
    await auth.signInWithEmailAndPassword(
        email: kioskEmail, password: kioskPassword);
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') {
      await auth.createUserWithEmailAndPassword(
          email: kioskEmail, password: kioskPassword);
    } else {
      rethrow;
    }
  }
  final uid = auth.currentUser!.uid;
  return (app: app, db: db, uid: uid);
}

/// The demo's Firebase store: one call per process (Firebase rejects a
/// second `initializeApp` under the same name).
Future<FirebaseMemoryStore> selectFirebaseStore() async {
  final boot = await bootFirebase();
  return FirebaseMemoryStore(firestore: boot.db, uid: boot.uid);
}
