import 'dart:async';

import 'package:pet_connect/core/utils/br_date.dart';
import 'package:pet_connect/features/pet/domain/consulta.dart';
import 'package:pet_connect/features/pet/domain/consulta_repository.dart';

/// Repositório em memória para testes de widget, sem depender de um
/// Firestore real (ver "Testes" em docs/arquitetura.md).
class FakeConsultaRepository implements ConsultaRepository {
  FakeConsultaRepository({this.erroAoAtualizar, this.aguardarAntesDeAtualizar});

  /// Se definido, `updateConsulta` lança este erro em vez de aplicar a
  /// mudança — usado pra testar o feedback de erro ao cancelar (ver
  /// docs/features/confirmacao-cancelamento-consulta.md).
  final Object? erroAoAtualizar;

  /// Se definido, `updateConsulta` só resolve depois que este completer for
  /// completado — segura o estado de loading tempo suficiente pra ser
  /// observado no teste.
  final Completer<void>? aguardarAntesDeAtualizar;

  final Map<String, Map<String, Consulta>> _store = {};
  final _changes = StreamController<void>.broadcast();
  int _nextId = 0;

  @override
  Stream<List<Consulta>> watchConsultas(String petId) async* {
    yield _snapshot(petId);
    await for (final _ in _changes.stream) {
      yield _snapshot(petId);
    }
  }

  @override
  Future<void> createConsulta(String petId, Consulta consulta) async {
    final id = 'consulta-${_nextId++}';
    _store.putIfAbsent(petId, () => {})[id] =
        Consulta.fromMap(id, consulta.toMap());
    _changes.add(null);
  }

  @override
  Future<void> updateConsulta(String petId, Consulta consulta) async {
    if (aguardarAntesDeAtualizar != null) {
      await aguardarAntesDeAtualizar!.future;
    }
    if (erroAoAtualizar != null) throw erroAoAtualizar!;
    _store.putIfAbsent(petId, () => {})[consulta.id] = consulta;
    _changes.add(null);
  }

  List<Consulta> _snapshot(String petId) {
    final consultas = (_store[petId] ?? {}).values.toList();
    consultas.sort((a, b) {
      final dataA = parseBrDate(a.data);
      final dataB = parseBrDate(b.data);
      if (dataA == null || dataB == null) return 0;
      return dataA.compareTo(dataB);
    });
    return consultas;
  }
}
