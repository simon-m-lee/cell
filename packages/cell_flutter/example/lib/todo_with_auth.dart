// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// A realistic end-to-end example: auth + todos + derived count +
/// validation + a saved snackbar.
///
/// Exercises together:
/// - `Cell.state` with a `testRule` validation gate (auth idempotency)
/// - `Cell.ingress` with a `refine` pre-transformation hook (todo
///   validation — the derive-compatible path; see `todosState`)
/// - `Cell.derive` + the `CellValueBuilder` bridge
/// - `CellBuilder`, `CellSelector`, `CellListener`, `CellScope`
///
/// The cells are public so tests can attach `recordPulses()` — an app
/// would keep them where they belong, not expose them.
library;

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// The auth state: signed out, or signed in as [SignedIn.user].
sealed class AuthState {
  const AuthState();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn(this.user);

  final String user;
}

/// A single todo item.
class Todo {
  const Todo({required this.id, required this.title, this.completed = false});

  final int id;
  final String title;
  final bool completed;

  Todo copyWith({bool? completed}) =>
      Todo(id: id, title: title, completed: completed ?? this.completed);
}

// ---------------------------------------------------------------------------
// Cells (public for the example's tests)
// ---------------------------------------------------------------------------

/// The auth cell. The `testRule` rejects the idempotent
/// `SignedOut -> SignedOut` transition. Non-pulse validations (link and
/// action gates) pass through — the rule only gates state pulses.
final authState = Cell.state<AuthState>(
  initial: const SignedOut(),
  testRule: TestCell((object, {host, arguments, user}) {
    final next = object is Pulse ? object.payload : null;
    if (next == null) return true; // links/actions pass
    final current = host is ValueCell<AuthState> ? host.value : null;
    return !(next is SignedOut && current is SignedOut);
  }),
);

/// The todo list cell.
///
/// Deliberately **without** a `testRule`: in `cell` 1.1.0, a state cell
/// with a custom `testRule` commits updates but does not fan the pulse
/// out to downstream `Cell.derive` links (`update`, `updateAsync`, and
/// `ingest` all behave this way). The example derives the incomplete
/// count from this cell, so todo validation lives in the ingress
/// `refine` hook instead — the derive-compatible path.
final todosState = Cell.state<List<Todo>>(
  initial: const [],
);

/// The ingress for new-todo events. The `refine` hook trims the title
/// and silently drops empty ones before they enter the graph.
final todoEvents = Cell.ingress<Todo>(
  refine: (host, input) {
    final raw = input.payload?.title.trim() ?? '';
    if (raw.isEmpty) return null; // validation: drop empty titles
    return Pulse<Todo>(
      Todo(id: input.payload?.id ?? 0, title: raw),
      type: 'todo.add',
    );
  },
);

/// The most recently saved todo title, used by the snackbar listener.
final lastSaved = Cell.state<String?>(initial: null);

/// The derived incomplete count. Returns a `Cell`, not a `ValueCell`;
/// display it with `CellValueBuilder` (or bridge with `asValueCell`).
final incompleteCount = Cell.derive<Pulse<List<Todo>>, Pulse<int>>(
  source: todosState.cell,
  project: (p) => Pulse<int>(
    (p.payload ?? const <Todo>[]).where((t) => !t.completed).length,
  ),
);

EgressHandle<Pulse<Todo>>? _todoWiring;
var _nextTodoId = 1;

/// Wires the todo ingress into the todo list once per process. The
/// `refine` hook is the validation gate; everything that reaches this
/// effect is already non-empty and is appended. The saved title is
/// published to [lastSaved] for the snackbar listener.
void _ensureWiring() {
  if (_todoWiring != null) return;
  _todoWiring = Cell.observe<Pulse<Todo>>(
    source: todoEvents.cell,
    effect: (p) {
      if (p.payload == null) return;
      final todo = p.payload!;
      todosState.update([...?todosState.cell.value, todo]);
      lastSaved.update(todo.title);
    },
  );
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

/// The full example app: `CellScope` at the root, declarative auth gate.
class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  @override
  void initState() {
    super.initState();
    _ensureWiring();
  }

  @override
  void dispose() {
    // The cells are module-level; only the wiring egress is app-owned.
    _todoWiring?.stop();
    _todoWiring = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CellScope(
      cells: {#auth: authState.cell, #todos: todosState.cell},
      child: const MaterialApp(home: AuthGate()),
    );
  }
}

/// Declarative navigation: the widget tree follows the auth cell.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return CellBuilder<AuthState>(
      cell: authState.cell.unmodifiable,
      builder: (_, state) => switch (state) {
        SignedIn(:final user) => TodoListScreen(user: user),
        _ => const LoginScreen(),
      },
    );
  }
}

/// Signs in by updating the auth cell.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Sign in',
          button: true,
          child: ElevatedButton(
            onPressed: () => authState.update(const SignedIn('Ada')),
            child: const Text('Sign in'),
          ),
        ),
      ),
    );
  }
}

/// The todo list: builder for the list, selector for the count,
/// listener for the saved snackbar.
class TodoListScreen extends StatelessWidget {
  const TodoListScreen({super.key, required this.user});

  final String user;

  Future<void> _addTodo(BuildContext context) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const AddTodoDialog(),
    );
    if (title == null) return;
    todoEvents.emit(Todo(id: _nextTodoId++, title: title));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Signed in as $user'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CellValueBuilder<int>(
                cell: incompleteCount,
                initial: _currentIncomplete(),
                builder: (_, count) => Semantics(
                  label: 'Incomplete count',
                  child: Text('$count left'),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          CellSelector<List<Todo>, int>(
            cell: todosState.cell,
            select: (list) =>
                (list ?? const <Todo>[]).where((t) => !t.completed).length,
            builder: (context, count) => Semantics(
              label: 'Incomplete count',
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text('$count incomplete'),
              ),
            ),
          ),
          Expanded(
            child: CellBuilder<List<Todo>>(
              cell: todosState.cell,
              builder: (_, todos) {
                final list = todos ?? const <Todo>[];
                if (list.isEmpty) {
                  return const Center(child: Text('No todos yet'));
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final todo = list[index];
                    return Semantics(
                      label: 'Complete ${todo.title}',
                      child: CheckboxListTile(
                        value: todo.completed,
                        title: Text(todo.title),
                        onChanged: (done) {
                          final next = [
                            for (final t in list)
                              if (t.id == todo.id)
                                t.copyWith(completed: done)
                              else
                                t,
                          ];
                          todosState.update(next);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // The saved snackbar, driven by pulses.
          CellListener<String?>(
            cell: lastSaved.cell,
            onPulse: (context, pulse) {
              final payload = pulse.payload;
              if (payload == null) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saved "$payload"')),
              );
            },
            child: const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add todo',
        onPressed: () => _addTodo(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

int _currentIncomplete() =>
    (todosState.cell.value ?? const <Todo>[]).where((t) => !t.completed).length;

/// Captures a new todo title and emits it into the ingress.
class AddTodoDialog extends StatefulWidget {
  const AddTodoDialog({super.key});

  @override
  State<AddTodoDialog> createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends State<AddTodoDialog> {
  final _controller = TextEditingController();
  var _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add todo'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Todo title',
          errorText: _showError ? 'Title must not be empty' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
