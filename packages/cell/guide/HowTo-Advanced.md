# Advanced

Optional machinery. You can ship with `Cell.state`, `Cell.observe`, and the Core operators and never open these pages.

Use this group when a write must be *justified*, *isolated*, or *short-lived* — not for counters and forms.

## What “advanced” means here

| Topic | When you actually need it |
| --- | --- |
| [Context](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-Context.md) | Domain / constraint metadata on a cell |
| [Deputy Context](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-DeputyContext.md) | A narrower proxy of the same cell |
| [Nucleus](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-Nucleus.md) | Shared immutable blueprints |
| [Pulse Context](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-PulseContext.md) | Actor / reason / purpose on a pulse |
| [Pulse Ephemeral Policy](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-PulseEphemeralPolicy.md) | TTL and hop limits on a signal |
| [Ephemeral Policy](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-EphemeralPolicy.md) | TTL and event budgets on a cell |
| [Propagation Policy](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-PropagationPolicy.md) | Debounce / throttle / batch at the synapse |
| [Transactions](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-Transaction.md) | Multi-cell buffered writes and isolation |
| [txApply](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-TransactionOnApply.md) | Staged `apply()` plus compensation |

None of this runs unless you pass the type in. `Context.describe('…')` stores text; it is not a compliance program.

## Tagging APIs

On an advanced type or factory:

```dart
/// {@category Advanced}
/// {@category Transactions}
static Transaction transaction([TransactionOptions? options]) { ... }
```

The first tag lists the member on the Advanced topic page. The second keeps the dedicated HowTo page.
