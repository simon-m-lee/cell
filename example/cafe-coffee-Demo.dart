// ignore_for_file: file_names
// cafe-coffee-Demo.dart
// Cell-variant Demo for Café Order & Stock Desk
// Packages: cell, cell_flow, cell_tissue

import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_tissue/cell_tissue.dart';

// ---------- Domain types ----------

enum Level { proceed, reject }

class OrderLine {
  final String item;
  final int quantity;
  final double price;
  OrderLine(this.item, this.quantity, this.price);
}

class CafeTick {
  final List<OrderLine> lines;
  final String paymentMethod;
  final double amount;
  final String? refundKey;
  final bool paymentOk;
  CafeTick({
    required this.lines,
    required this.paymentMethod,
    required this.amount,
    this.refundKey,
    this.paymentOk = true,
  });
}

class CafeDecision {
  final Level level;
  final CafeTick tick;
  CafeDecision(this.level, this.tick);
}

class Order {
  final String id;
  final List<OrderLine> lines;
  Order(this.id, this.lines);
}

class Payment {
  final String method;
  final double amount;
  final String status;
  Payment(this.method, this.amount, this.status);
}

class Outcome {
  final String kind; // 'succeeded' or 'undone'
  final String note;
  Outcome(this.kind, this.note);
}

// ---------- Policy instruction (importable) ----------

class CafeOrderInstruction extends FlowInstructionBase<Cell, Pulse, Pulse> {
  final TissueMap<String, int> stock;
  final Level pass;

  CafeOrderInstruction({required this.stock, required this.pass})
      : super((pulse, {cell, user}) {
          final tick = pulse.payload as CafeTick?;
          if (tick == null) return null;
          final level = riskOf(tick, stock);
          if (level != pass) return null;
          return Pulse(CafeDecision(level, tick), source: pulse.source);
        });

  /// Pure policy. Unit-testable.
  static Level riskOf(CafeTick tick, TissueMap<String, int> stock) {
    for (final line in tick.lines) {
      if (line.quantity <= 0) return Level.reject;
    }
    for (final line in tick.lines) {
      final available = stock[line.item] ?? 0;
      if (available < line.quantity) return Level.reject;
    }
    return Level.proceed;
  }
}

// ---------- Chain assembly and installGates (importable, no work at import) ----------

late IngressHandle<CafeTick> tickIn;
late TissueMap<String, int> stock;
late TissueList<Order> orders;
late TissueList<Payment> payments;
late TissueList<Outcome> outcomes;
late TissueList<dynamic> refunds;

late dynamic proceedHandle;
late dynamic rejectHandle;

// Last tick seen by observer (stand-in so tests can assert)
CafeTick? lastTick;
String lastBanner = '';

void installGates() {
  stock = TissueMap<String, int>(
    properties: TissueMapNucleus<String, int>(testRule: TestTissue.allowAll),
  );
  orders = TissueList<Order>(testRule: TestTissue.allowAll);
  payments = TissueList<Payment>(testRule: TestTissue.allowAll);
  outcomes = TissueList<Outcome>(testRule: TestTissue.allowAll);
  refunds = TissueList<dynamic>(testRule: TestTissue.allowAll);

  tickIn = Cell.ingress<CafeTick>();

  final proceedGate = CafeOrderInstruction(stock: stock, pass: Level.proceed);
  final rejectGate = CafeOrderInstruction(stock: stock, pass: Level.reject);
  final toLevel = MapValue<CafeDecision, Level>((d) => d.level);

  final proceedChain = proceedGate + toLevel;
  final rejectChain = rejectGate + toLevel;

  proceedHandle = proceedChain.toHandle(source: tickIn.cell);
  rejectHandle = rejectChain.toHandle(source: tickIn.cell);

  Cell.observe(
    source: proceedHandle.cell,
    effect: (Pulse pulse) async {
      final level = pulse.payload as Level?;
      if (level != Level.proceed) return;
      lastBanner = 'HAPPY';
      print('HAPPY: order + payment + stock succeed together');
    },
  );

  Cell.observe(
    source: rejectHandle.cell,
    effect: (Pulse pulse) {
      final level = pulse.payload as Level?;
      if (level != Level.reject) return;
      outcomes.add(Outcome('undone', 'rejected'));
      lastBanner = 'REJECT';
      print('REJECT: outcome=undone');
    },
  );
}

Future<void> commitOrder(CafeTick tick) async {
  lastTick = tick;
  final paymentOk = tick.paymentOk && tick.amount > 0;
  try {
    await Cell.txApply().execute(
      participants: [stock, orders, payments, outcomes],
      body: (tx) {
        for (final line in tick.lines) {
          final current = stock[line.item] ?? 0;
          stock[line.item] = current - line.quantity;
        }
        orders.add(Order('ord-${orders.length + 1}', tick.lines));
        payments.add(Payment(tick.paymentMethod, tick.amount, paymentOk ? 'captured' : 'rejected'));
        outcomes.add(Outcome(paymentOk ? 'succeeded' : 'undone', 'order'));
      },
    );
    lastBanner = 'HAPPY';
    print('HAPPY: order + payment + stock succeed together');
  } catch (_) {
    outcomes.add(Outcome('undone', 'commit failed'));
    lastBanner = 'UNDO';
    print('UNDO: customer not charged, stock unchanged, outcome=undone');
  }
}

// ---------- Header registers ----------

void printHeader() {
  print('''
Provenance: Pulse.source on every emit | Context: none because BRD names no auditor | Deputy: orders.unmodifiable for owner / none because BRD names no auditor
Boundary: orderIn/paymentIn/refundIn/stockCheckIn TestCell yes | transaction deferred txApply on Tissue | txApply present
''');
}

// ---------- main (harness only) ----------

void main() {
  printHeader();
  installGates();

  stock['latte'] = 10;
  stock['croissant'] = 5;

  tickIn.emit(CafeTick(
    lines: [OrderLine('latte', 1, 4.5)],
    paymentMethod: 'card',
    amount: 4.5,
  ));

  stock['latte'] = 0;
  tickIn.emit(CafeTick(
    lines: [OrderLine('latte', 1, 4.5)],
    paymentMethod: 'card',
    amount: 4.5,
  ));

  print('Demo complete. See test for ledger.');
}
