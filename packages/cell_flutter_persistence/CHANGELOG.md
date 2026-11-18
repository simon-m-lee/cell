# Changelog

## 0.1.1

pub.dev scoring pass — no public API changes.

- **Example** — added `example/` with a runnable `lib/main.dart`
  (in-memory persisted counter), so pub.dev's "package has an example"
  check passes.

## 0.1.0

- Initial release: CellPersistenceAdapter interface, SharedPreferencesAdapter
  (primitive + JSON codecs), InMemoryAdapter, and PersistedCell / persistedState
  with immediate / debounced / onAppPause write modes.
