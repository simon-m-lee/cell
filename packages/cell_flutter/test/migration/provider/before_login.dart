// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Migration fixture: Provider login (before) — a ChangeNotifier form.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginModel extends ChangeNotifier {
  String email = '';
  String password = '';

  void setEmail(String value) {
    email = value;
    notifyListeners();
  }

  void setPassword(String value) {
    password = value;
    notifyListeners();
  }

  bool get valid => email.contains('@') && password.length >= 6;
}

Widget buildLoginApp() {
  return ChangeNotifierProvider(
    create: (_) => LoginModel(),
    child: MaterialApp(
      home: Scaffold(
        body: Consumer<LoginModel>(
          builder: (context, model, child) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Email'),
                onChanged: model.setEmail,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Password'),
                onChanged: model.setPassword,
              ),
              Text(model.valid ? 'logged in' : 'not valid'),
            ],
          ),
        ),
      ),
    ),
  );
}
