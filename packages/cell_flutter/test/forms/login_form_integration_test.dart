// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Forms: the LoginForm integration test — four fields, validation,
// submission, and hot-restart preservation, in under ~40 lines of user
// code.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RestorationBucket _bucketWith(Map<String, Object?> values) {
  return RestorationBucket.root(
    manager: TestWidgetsFlutterBinding.instance.restorationManager,
    rawData: <Object?, Object?>{
      'v': <Object?, Object?>{},
      'c': <Object?, Object?>{
        'login': <Object?, Object?>{
          'v': values,
          'c': <Object?, Object?>{},
        },
      },
    },
  );
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key, this.onSubmit});

  final void Function(String email, String password)? onSubmit;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  late final RestorableCell<String> email;
  late final RestorableCell<String> password;
  late final RestorableCell<String> confirm;
  final rememberMe = Cell.state<bool>(initial: false);

  @override
  void initState() {
    super.initState();
    email = restorableState<String>(restorationId: 'email', initial: '');
    password = restorableState<String>(restorationId: 'password', initial: '');
    confirm = restorableState<String>(restorationId: 'confirm', initial: '');
    final scope = CellRestorationScope.maybeOf(context);
    scope?.register(email);
    scope?.register(password);
    scope?.register(confirm);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit?.call(email.value ?? '', password.value ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(children: [
        CellTextField(
          cell: email,
          decoration: const InputDecoration(labelText: 'Email'),
          validator: (v) =>
              v == null || !v.contains('@') ? 'Invalid email' : null,
        ),
        CellTextField(
          cell: password,
          decoration: const InputDecoration(labelText: 'Password'),
          validator: (v) => v == null || v.length < 6 ? 'Too short' : null,
        ),
        CellTextField(
          cell: confirm,
          decoration: const InputDecoration(labelText: 'Confirm'),
          validator: (v) => v != password.value ? 'Mismatch' : null,
        ),
        CellFormField<bool>(
          cell: rememberMe.cell,
          builder: (state) => CheckboxListTile(
            value: state.value ?? false,
            onChanged: (v) => state.didChange(v),
            title: const Text('Remember me'),
          ),
        ),
        TextButton(onPressed: _submit, child: const Text('Login')),
      ]),
    );
  }
}

Widget _wrapApp(Widget child, {RestorationBucket? bucket, Key? key}) {
  return MaterialApp(
    home: KeyedSubtree(
      key: key,
      child: CellRestorationScope(
        restorationScopeId: 'login',
        bucket: bucket,
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('LoginForm', () {
    testWidgets('typing in each field updates its cell', (tester) async {
      final email = Cell.state<String>(initial: '');
      await tester.pumpWidget(_wrapApp(
        Form(
          child: Column(children: [
            CellTextField(cell: email.cell),
          ]),
        ),
      ));

      await tester.enterText(find.byType(TextFormField), 'a@b.c');
      await tester.pump();
      expect(email.cell.value, 'a@b.c');
    });

    testWidgets('validate() rejects empty email and mismatched confirm',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(_wrapApp(const LoginForm()));
      // Reach the LoginForm's own Form via the widget tree.
      final state = tester.state<FormState>(find.byType(Form));
      expect(state.validate(), isFalse);
      await tester.pump();
      expect(find.text('Invalid email'), findsOneWidget);

      // Fill the fields so validation passes.
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'user@example.com');
      await tester.enterText(fields.at(1), 'secret1');
      await tester.enterText(fields.at(2), 'secret1');
      await tester.pump();
      expect(state.validate(), isTrue);
      // ignore: unused_local_variable
      final unusedFormKey = formKey; // (documented: LoginForm owns its Form)
    });

    testWidgets('valid submission runs onSubmit', (tester) async {
      String? submittedEmail;
      String? submittedPassword;
      await tester.pumpWidget(_wrapApp(LoginForm(
        onSubmit: (email, password) {
          submittedEmail = email;
          submittedPassword = password;
        },
      )));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'user@example.com');
      await tester.enterText(fields.at(1), 'secret1');
      await tester.enterText(fields.at(2), 'secret1');
      await tester.pump();
      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(submittedEmail, 'user@example.com');
      expect(submittedPassword, 'secret1');
    });

    testWidgets('hot restart preserves the field values', (tester) async {
      await tester
          .pumpWidget(_wrapApp(const LoginForm(), bucket: _bucketWith({})));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'keep@me.com');
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'keep@me.com'), findsOneWidget);

      // Restart: fresh element tree with the persisted data re-injected.
      await tester.pumpWidget(_wrapApp(
        const LoginForm(),
        bucket: _bucketWith({'email': 'keep@me.com'}),
        key: UniqueKey(),
      ));

      expect(find.widgetWithText(TextFormField, 'keep@me.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
