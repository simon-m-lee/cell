# HowTo: Forms with `cell_flutter`

Three pieces cover every form a production app builds:

| Need | Use |
|---|---|
| Text field bound to a cell | `CellTextField` |
| Any non-text input (dropdown, slider, checkbox, date picker) | `CellFormField<T>` |
| Direct `TextEditingController` access | `cellEditingController(cell)` |

All of them are real Flutter form widgets, so `Form`, `Form.validate()`,
`validator`, and `autovalidateMode` work exactly as they do with
`TextFormField` / `FormField`.

## Text fields

```dart
CellTextField(
  cell: email.cell,
  decoration: const InputDecoration(labelText: 'Email'),
  validator: (v) => v == null || !v.contains('@') ? 'Invalid email' : null,
);
```

- Typing updates the cell; cell updates re-render the field.
- The two-way sync is equality-guarded, so it cannot loop.
- Cell-driven updates preserve the cursor's offset from the end; a full
  replacement lands the cursor at the end.
- Focus is preserved across cell updates (the controller is not disposed
  on update, only on cell swap or unmount).

## Non-text fields

`CellFormField` gives the input's builder a standard `FormFieldState`;
the input commits values with `state.didChange(...)`:

```dart
CellFormField<bool>(
  cell: rememberMe.cell,
  builder: (state) => CheckboxListTile(
    value: state.value ?? false,
    onChanged: (v) => state.didChange(v),
    title: const Text('Remember me'),
  ),
);
```

Custom types work without codecs — `CellFormField<DateTime>` round-trips
through the cell directly.

## Direct controller access

```dart
final controller = cellEditingController(email.cell);
// Use anywhere TextEditingController is accepted. Call controller.dispose()
// when done — it releases the internal cell observation.
```

## Validation

`CellTextField` and `CellFormField` are `FormField`s; wrap them in a
`Form` and validate as usual:

```dart
final formKey = GlobalKey<FormState>();
Form(
  key: formKey,
  child: Column(children: [
    CellTextField(cell: email, validator: (v) => /* ... */),
    CellFormField<int>(cell: age, validator: (v) => /* ... */, builder: /* ... */),
    TextButton(
      onPressed: () { if (formKey.currentState!.validate()) submit(); },
      child: const Text('Submit'),
    ),
  ]),
)
```

Note: `FormField` displays validation errors through the *builder*
(`state.errorText`) — include it in your custom `CellFormField` builder.

## Restoration

Bind a `RestorableCell<String>` to `CellTextField` and register it with a
`CellRestorationScope` (see `HowTo-Restoration.md`) — the field text
survives process kill and hot restart:

```dart
late final RestorableCell<String> email;

@override
void initState() {
  super.initState();
  email = restorableState<String>(restorationId: 'email', initial: '');
  CellRestorationScope.maybeOf(context)?.register(email);
}
// build: CellTextField(cell: email)
```

`test/forms/login_form_integration_test.dart` demonstrates the full
4-field `LoginForm` (email, password, confirm, remember-me) with
validation, submission, and hot-restart preservation.
