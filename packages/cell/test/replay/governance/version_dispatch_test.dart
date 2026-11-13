import 'package:cell/cell.dart';
import 'package:test/test.dart';

class _TestReceptor extends ReceptorBase<Cell> {
  @override
  final String version;
  _TestReceptor({required this.version}) : super();

  @override
  Receptor<Cell> get clone => _TestReceptor(version: version);
}

class _TestRule extends TestCell<Cell> {
  @override
  final String version;
  _TestRule({required this.version})
      : super((_, {host, arguments, user}) => true);
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('VersionRegistry resolves the registered version', () {
    final registry = VersionRegistry();
    final receptor = _TestReceptor(version: '1.0.0');
    final rule = _TestRule(version: '1.0.0');
    registry.register(
      cellId: 'c',
      version: '1.0.0',
      receptor: receptor,
      testRule: rule,
    );
    expect(registry.has(cellId: 'c', version: '1.0.0'), isTrue);
    expect(registry.has(cellId: 'c', version: '2.0.0'), isFalse);
    final resolved = registry.resolve(cellId: 'c', version: '1.0.0');
    expect(resolved, isNotNull);
    expect(resolved!.receptor, same(receptor));
    expect(resolved.testRule, same(rule));
  });

  test('VersionRegistry refuses mismatched versions', () {
    final registry = VersionRegistry();
    expect(
      () => registry.register(
        cellId: 'c',
        version: '1.0.0',
        receptor: _TestReceptor(version: '1.0.0'),
        testRule: _TestRule(version: '2.0.0'), // different
      ),
      throwsStateError,
    );
  });

  test('VersionRegistry refuses a second, different implementation', () {
    final registry = VersionRegistry();
    registry.register(
      cellId: 'c',
      version: '1.0.0',
      receptor: _TestReceptor(version: '1.0.0'),
      testRule: _TestRule(version: '1.0.0'),
    );
    expect(
      () => registry.register(
        cellId: 'c',
        version: '1.0.0',
        receptor: _TestReceptor(version: '1.0.0'),
        testRule: _TestRule(version: '1.0.0'),
      ),
      throwsStateError,
    );
  });

  test('cell graph exposes a version registry per graph', () {
    final cell = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', cell)).build();
    graph.registerVersion('c');
    expect(graph.versions.has(cellId: 'c', version: '0.0.0'), isTrue);

    // A second graph gets its own, empty registry.
    CellGraphRegistry.forceReset();
    final cell2 = Cell.state<int>(initial: 0);
    final graph2 = (CellGraph.builder()..registerState('c', cell2)).build();
    expect(graph2.versions.has(cellId: 'c', version: '0.0.0'), isFalse);
  });

  test('DeputyContext.version defaults to 1.0.0 and can be set', () {
    final ctx = DeputyContext(
      baseContext: Context.system,
      authority: 'UPDATE',
    );
    expect(ctx.version, '1.0.0');
    final v2 = DeputyContext(
      baseContext: Context.system,
      authority: 'UPDATE',
      version: '2.0.0',
    );
    expect(v2.version, '2.0.0');
  });

  test('ContextTranslatorRegistry translates and fails loudly when absent',
      () async {
    final registry = ContextTranslatorRegistry();
    final v1 = DeputyContext(
      baseContext: Context.system,
      authority: 'UPDATE',
      version: '1.0.0',
    );
    // Same version: identity.
    expect(await registry.translate(v1, target: '1.0.0'), same(v1));

    // Missing translator: loud failure.
    await expectLater(
      registry.translate(v1, target: '2.0.0'),
      throwsUnimplementedError,
    );

    // Registered translator bridges the gap.
    registry.register(_V1ToV2Translator());
    final translated = await registry.translate(v1, target: '2.0.0');
    expect(translated.version, '2.0.0');
  });
}

class _V1ToV2Translator implements ContextTranslator {
  @override
  String get fromVersion => '1.0.0';

  @override
  String get toVersion => '2.0.0';

  @override
  DeputyContext translate(DeputyContext source) {
    return DeputyContext(
      baseContext: Context.system,
      authority: 'UPDATE',
      version: '2.0.0',
    );
  }
}
