# How to build a purpose-built Receptor with an InstructionChain of FlowInstructions

A **Receptor** is the gate that runs **Instructions** when a pulse hits a Cell.  
A **FlowInstruction** *is* an `Instruction`.  
`operator +` and `Instruction.chain` both produce an **InstructionChain**.  
`toHandle` wraps that chain in `Receptor.instruction(...)` and hangs it on a Nucleus.

You get **one** Receptor, **one** lock, **one** Cell — many operators inside.

```
Filter + MapValue + Tap + Distinct
        │
        ▼
_FlowInstructionChain  extends  InstructionChain
        │
        ▼
Receptor.instruction(chain)
        │
        ▼
Nucleus(bind: source, receptor: …)  →  Cell.fromNucleus
```

Fluent `source.filter().map()` is different: **each** step is its own Receptor/Cell. Use a chain when the steps should share ingress, lock, and identity.

---

## 1. Smallest purpose-built Receptor

Sanitize a string in one gate: trim → drop empty → tag.

```dart
import 'package:cell_flow/flow.dart';

final sanitize = MapValue<String, String>((s) => s.trim()) +
    Filter<String>((s) => s.isNotEmpty) +
    Tap<String>((s) => debugPrint('kept $s'));

final ingress = Cell.ingress<String>();
final handle = sanitize.toHandle(source: ingress.cell);

Cell.observe(
  source: handle.cell,
  effect: (Pulse p) => print(p.payload),
);

await ingress.emitAsync('  ada  '); // ada
await ingress.emitAsync('   ');     // dropped
```

`+` is left-associative and returns another `FlowInstruction`, so you can keep appending.

`null` from any step **stops the chain** (default strategy). That is how `Filter` drops a pulse without the later `Tap` running.

---

## 2. Named domain pipeline (many instructions)

Give the chain a name. Reuse it on several Cells.

```dart
FlowInstruction<Cell, Pulse, Pulse> searchPipeline() {
  return MapValue<String, String>((q) => q.trim().toLowerCase()) +
      Filter<String>((q) => q.length >= 2) +
      Distinct<String>() +
      Tap<String>((q) => analytics.track('query', q));
}

final box = Cell.ingress<String>();
final live = searchPipeline().toHandle(source: box.cell);
```

The same function can be bound to a widget Cell and a test ingress. The Receptor is created at `toHandle` time, not at function definition time.

---

## 3. Explicit `Instruction.chain` (same idea, listed)

`+` is sugar. When the list is long, build the chain in one place:

```dart
final checkout = Instruction.chain<Cell, Pulse, Pulse>([
  Filter<Cart>((c) => c.lines.isNotEmpty),
  MapValue<Cart, Quote>((c) => Quote.from(c)),
  Tap<Quote>((q) => log.info('quote ${q.total}')),
  Filter<Quote>((q) => q.total > 0),
]);

final cart = Cell.ingress<Cart>();
final quoted = (checkout as FlowInstruction<Cell, Pulse, Pulse>)
    .toHandle(source: cart.cell);
```

If the factory returns a plain `Instruction`, wrap with `Receptor.instruction` yourself (next section) or keep using `+` so the result stays a `FlowInstruction` with `toHandle`.

Safer pattern that stays in Flow land:

```dart
FlowInstruction<Cell, Pulse, Pulse> checkoutFlow() =>
    Filter<Cart>((c) => c.lines.isNotEmpty) +
    MapValue<Cart, Quote>((c) => Quote.from(c)) +
    Tap<Quote>((q) => log.info('quote ${q.total}')) +
    Filter<Quote>((q) => q.total > 0);
```

---

## 4. Purpose-built Receptor without `toHandle`

When you already have a Nucleus / Cell factory and want the Receptor object:

```dart
final op = Filter<int>((n) => n >= 0) +
    MapValue<int, String>((n) => '#$n') +
    Tap<String>(print);

final receptor = Receptor.instruction(op);

final nucleus = Nucleus(
  bind: source,
  receptor: receptor,
  testRule: TestCell.allowAll,
  synapses: Synapses.enabled,
);
final cell = Cell.fromNucleus(nucleus);
```

That is exactly what `FlowInstructionMixin.toHandle` does, plus `emit` / `emitAsync` helpers.

Use this form when the Receptor must be stored, tested, or swapped.

```dart
test('sanitize drops blanks', () {
  final r = Receptor.instruction(
    MapValue<String, String>((s) => s.trim()) + Filter<String>((s) => s.isNotEmpty),
  );
  expect(r.call(Pulse('  x  '))?.payload, 'x');
  expect(r.call(Pulse('   ')), isNull);
});
```

---

## 5. Custom strategy (not a straight line)

Default chain: run in order, stop on `null`.

Override `strategy` when you need skip / branch **inside one Receptor**:

```dart
final trim = MapValue<String, String>((s) => s.trim());
final validate = Filter<String>((s) => s.contains('@'));
final log = Tap<String>((s) => print('email $s'));

final emailGate = Instruction.chain<Cell, Pulse, Pulse>(
  [trim, validate, log],
  user: const {'strict': true},
  strategy: (pulse, {cell, user}) {
    final trimmed = trim.call(pulse, cell: cell);
    if (trimmed == null) return null;

    final strict = user is Map && user['strict'] == true;
    if (strict) {
      final ok = validate.call(trimmed, cell: cell);
      if (ok == null) return null;
      return log.call(ok, cell: cell);
    }
    return log.call(trimmed, cell: cell);
  },
);
```

The strategy still receives the same instruction instances. It decides **whether** to call them. Individual FlowInstructions stay small and testable.

---

## 6. Mixing sync chain links with async instructions

A chain’s default walk is **synchronous**. `Filter` / `MapValue` / `Tap` / `Distinct` / `Skip` / `Take` belong there.

Instructions built with `FlowInstructionBase.future` (`Delay`, `AsyncMap`, `Debounce`, …) emit later through the `future:` sink. Putting several of those in **one** `+` chain is possible but easy to get wrong: the next link may run before the async result exists.

Practical split:

| In the InstructionChain (one Receptor) | Own Cell / fluent step |
|---|---|
| trim, filter, map, tap, distinct, take, skip | delay, debounce, asyncMap, switchMap, buffer |

```dart
// Sync policy in one Receptor
final admit = MapValue<String, String>((q) => q.trim()) +
    Filter<String>((q) => q.length >= 2) +
    Distinct<String>();

final queries = Cell.ingress<String>();
final admitted = admit.toHandle(source: queries.cell);

// Async work as the next node
final results = admitted.cell.asyncMapLatest<String, List<Hit>>(
  mapper: api.search,
);
```

Two Receptors, two Cells. The first is purpose-built policy; the second is I/O.

---

## 7. Larger example: “moderation gate”

One Receptor that encodes product rules. Downstream Cells never see rejected pulses.

```dart
FlowInstruction<Cell, Pulse, Pulse> moderationGate({
  required Set<String> blocked,
  required void Function(String) onDrop,
}) {
  return MapValue<String, String>((s) => s.trim()) +
      Filter<String>((s) => s.isNotEmpty) +
      FilterBlocked<String>(blocked: blocked) +
      Filter<String>((s) {
        if (s.length > 280) {
          onDrop('too-long');
          return false;
        }
        return true;
      }) +
      Distinct<String>() +
      Tap<String>((s) => audit.pass(s));
}

final drafts = Cell.ingress<String>();
final published = moderationGate(
  blocked: {'spam', 'scam'},
  onDrop: (why) => metrics.inc(why),
).toHandle(source: drafts.cell);
```

Swap `blocked` in tests; the Receptor shape stays the same.

---

## 8. Composing purpose-built chains

A chain is an Instruction, so you can nest them.

```dart
final normalize = MapValue<String, String>((s) => s.trim().toLowerCase()) +
    Filter<String>((s) => s.isNotEmpty);

final dedupe = Distinct<String>() + Tap<String>((s) => cache.remember(s));

final ingest = normalize + dedupe; // InstructionChain of two chains

final handle = ingest.toHandle(source: raw.cell);
```

Keep each piece under ~5 links so the default “null stops the line” stays readable.

---

## 9. When to use which style

| Goal | Mechanism |
|---|---|
| One identity, one lock, reusable policy | `FlowInstruction + FlowInstruction` → `toHandle` / `Receptor.instruction` |
| Long named list, optional custom control flow | `Instruction.chain([...], strategy: …)` |
| Each operator visible as its own Cell | fluent `cell.filter().map().debounce()` |
| Async flatten / HTTP / timers | own node after the sync gate |

Fluent operators and InstructionChains are complementary, not substitutes.

```dart
final gate = Filter<int>((n) => n > 0) + MapValue<int, int>((n) => n * 2);
final doubled = gate.toHandle(source: raw.cell);

final shown = doubled.cell
    .debounce<int>(duration: const Duration(milliseconds: 50))
    .tap<int>(onValue: (n) => setState(() => value = n));
```

---

## 10. Checklist

1. Write small `FlowInstruction`s (one job each).
2. Join with `+` (or `Instruction.chain`) until the **policy** is complete.
3. Bind once: `toHandle(source:)` or `Receptor.instruction` + `Nucleus`.
4. Drive with `IngressHandle.emitAsync`.
5. Leave timers and HTTP off that Receptor; chain those as the next Cell.
6. Assert the Receptor in unit tests by calling it with a `Pulse` — you do not need a full graph for the sync gate.

That is a purpose-built Receptor: many FlowInstructions, one InstructionChain, one gate.
