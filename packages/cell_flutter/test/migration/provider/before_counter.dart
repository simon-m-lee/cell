// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Migration fixture: Provider counter (before). The guide's accuracy
// contract — this renders the same tree as after_counter.dart.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Counter extends ChangeNotifier {
  int _count = 0;

  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

Widget buildCounterApp() {
  return ChangeNotifierProvider(
    create: (_) => Counter(),
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: Consumer<Counter>(
            builder: (context, counter, child) => TextButton(
              onPressed: counter.increment,
              child: Text('count: ${counter.count}'),
            ),
          ),
        ),
      ),
    ),
  );
}
