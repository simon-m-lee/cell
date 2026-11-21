// Cell reference screen for the migration guide.
//
// The same todo feature as the Riverpod and BLoC references, built on
// `cell_flutter`:
//
// * state lives in a `Cell.state` + an audited `TodoBook` command cell;
// * the filtered list is a `Cell.synthesis` projection;
// * widgets rebuild through `CellBuilder`, side effects run through
//   `CellListener`;
// * submission is a **multi-step `Cell.txApply` transaction** — "add the
//   todo" + "bump the stats counter" — with recorded compensations, the
//   mechanism that has no Riverpod or BLoC equivalent.
//
// The app state lives in one plain `TodoModel` object passed down by
// constructor injection (in a larger app you would register it in a
// `CellScope` instead).
library;

import 'dart:async';

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

// ── Model ───────────────────────────────────────────────────────────────────

class Todo {
  Todo({required this.id, required this.description, this.completed = false});

  final String id;
  final String description;
  final bool completed;

  Todo copyWith({bool? completed}) => Todo(
      id: id,
      description: description,
      completed: completed ?? this.completed);
}

enum TodoFilter { all, active, completed }

// ── The audited command cell ────────────────────────────────────────────────
//
// All mutations are commands submitted through `Cell.apply`; there is no
// `value = …` setter. Every command produces an ApplyReceipt — the audit
// trail — and the submission path composes two commands into one
// `Cell.txApply` transaction.

class TodoBook extends CellBase {
  TodoBook() {
    addTodo = _addTodo;
    removeTodo = _removeTodo;
    toggleTodo = _toggleTodo;
    bumpStats = _bumpStats;
    unbumpStats = _unbumpStats;
  }

  List<Todo> todos = [];
  int statsAdded = 0;

  late final void Function(String description) addTodo;
  late final void Function(String description) removeTodo;
  late final void Function(String id) toggleTodo;
  late final void Function() bumpStats;
  late final void Function() unbumpStats;

  void _addTodo(String description) => todos = [
        ...todos,
        Todo(id: '${todos.length + 1}', description: description),
      ];

  void _removeTodo(String description) =>
      todos = [for (final t in todos) if (t.description != description) t];

  void _toggleTodo(String id) => todos = [
        for (final t in todos)
          t.id == id ? t.copyWith(completed: !t.completed) : t,
      ];

  void _bumpStats() => statsAdded++;

  void _unbumpStats() => statsAdded--;

  @override
  Iterable<Function> get modifiable =>
      {addTodo, removeTodo, toggleTodo, bumpStats, unbumpStats, apply};
}

// ── The application state ───────────────────────────────────────────────────
//
// One instance per app (or per test): the audited book plus the reactive
// projections the widgets read.

class TodoModel {
  final TodoBook book = TodoBook();

  /// The widget-visible list. Updated from accepted apply outcomes — the
  /// audited state is the book; this cell is its reactive projection.
  final StateHandle<List<Todo>> todosCell = Cell.state<List<Todo>>(initial: []);

  /// The active filter.
  final StateHandle<TodoFilter> filterCell =
      Cell.state<TodoFilter>(initial: TodoFilter.all);

  /// Derived filtered list: whenever either source pulses, recompute.
  late final Cell filteredTodos = Cell.synthesis<Pulse<List<Todo>>>(
    [todosCell.cell, filterCell.cell],
    aggregator: (cells, emit) {
      final todos = (cells.elementAt(0) as ValueCell<List<Todo>>).value ?? [];
      final filter = (cells.elementAt(1) as ValueCell<TodoFilter>).value ??
          TodoFilter.all;
      return Pulse<List<Todo>>(switch (filter) {
        TodoFilter.all => todos,
        TodoFilter.active => [for (final t in todos) if (!t.completed) t],
        TodoFilter.completed => [for (final t in todos) if (t.completed) t],
      });
    },
  );

  /// Side-effect channel: submission results are emitted here and consumed
  /// by a `CellListener` (the Flow → Tissue glue).
  final IngressHandle<String> events = Cell.ingress<String>();

  /// Receipts minted by the apply machinery, displayed as the audit count.
  final List<ApplyReceipt> receipts = [];

  ApplyCommand _command(
    Function function,
    List<Object?>? args, {
    Function? compensation,
    List<Object?>? compensationArgs,
  }) =>
      (
        function: function,
        arguments: (positionalArguments: args, namedArguments: null),
        compensation: compensation == null
            ? null
            : (
                function: compensation,
                arguments: (
                  positionalArguments: compensationArgs,
                  namedArguments: null,
                ),
                cell: null,
              ),
      );

  /// Submits a new todo: validate, then commit **two** commands atomically —
  /// add the todo and bump the stats counter — each with a recorded
  /// compensation. This is `Cell.txApply`; Riverpod and BLoC have no
  /// equivalent mechanism.
  Future<void> submitTodo(String description) async {
    final trimmed = description.trim();
    if (trimmed.isEmpty) {
      events.emit('error: Description must not be empty.');
      return;
    }
    if (trimmed.length > 60) {
      events.emit('error: Description must be 60 characters or fewer.');
      return;
    }

    final addCommand = _command(book.addTodo, [trimmed],
        compensation: book.removeTodo, compensationArgs: [trimmed]);
    final statsCommand = _command(book.bumpStats, const [],
        compensation: book.unbumpStats, compensationArgs: const []);

    final tx = Cell.txApply();
    final staged = <ApplyStaged>[];
    // The body must enqueue synchronously: `apply(..., tx: scope)` returns
    // `ApplyStaged` directly, and `txApply.execute` commits right after
    // the body returns.
    await tx.execute(participants: [book], body: (scope) {
      staged.add(book.apply<Never>(addCommand, tx: scope) as ApplyStaged);
      staged.add(book.apply<Never>(statsCommand, tx: scope) as ApplyStaged);
    });

    // The commit landed: refresh the projections and the audit list.
    todosCell.update(List.of(book.todos));
    receipts.addAll(staged.map((s) => s.receipt));
    events.emit('saved: $trimmed added (+1 stats).');
  }

  Future<void> toggleTodo(String id) async {
    final outcome = await book.apply<void>(_command(book.toggleTodo, [id]));
    if (outcome is ApplyAccepted) {
      receipts.add(outcome.receipt);
      todosCell.update(List.of(book.todos));
    }
  }
}

// ── UI ──────────────────────────────────────────────────────────────────────

void main() => runApp(const TodoApp());

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  final TodoModel model = TodoModel();

  @override
  Widget build(BuildContext context) =>
      MaterialApp(home: TodoListScreen(model: model));
}

class TodoListScreen extends StatelessWidget {
  const TodoListScreen({required this.model, super.key});

  final TodoModel model;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cell todos'),
        actions: [
          // The live audit counter — every command mints a receipt.
          CellBuilder<List<Todo>>(
            cell: model.todosCell.cell,
            builder: (context, value) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('${model.receipts.length} receipts')),
            ),
          ),
        ],
      ),
      // Side effects: submission results become snackbars. The child is
      // not rebuilt when events fire.
      body: CellListener<String>(
        cell: model.events.cell,
        onPulse: (context, pulse) {
          final message = pulse.payload as String;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.replaceFirst('saved: ', ''))),
          );
        },
        child: Column(
          children: [
            CellBuilder<TodoFilter>(
              cell: model.filterCell.cell,
              builder: (_, filter) => SegmentedButton<TodoFilter>(
                segments: const [
                  ButtonSegment(value: TodoFilter.all, label: Text('All')),
                  ButtonSegment(value: TodoFilter.active, label: Text('Active')),
                  ButtonSegment(
                      value: TodoFilter.completed, label: Text('Done')),
                ],
                selected: {filter ?? TodoFilter.all},
                onSelectionChanged: (s) => model.filterCell.update(s.first),
              ),
            ),
            Expanded(
              child: CellValueBuilder<List<Todo>>(
                cell: model.filteredTodos,
                builder: (_, todos) => ListView.builder(
                  itemCount: todos?.length ?? 0,
                  itemBuilder: (_, i) {
                    final todo = todos![i];
                    return CheckboxListTile(
                      key: Key('todo-${todo.id}'),
                      title: Text(todo.description),
                      value: todo.completed,
                      onChanged: (_) => model.toggleTodo(todo.id),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('open-form'),
        onPressed: () => _showTodoForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showTodoForm(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add todo'),
        content: TextField(
          key: const Key('description-field'),
          controller: controller,
          decoration: const InputDecoration(hintText: 'Description'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('submit-button'),
            onPressed: () async {
              await model.submitTodo(controller.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
