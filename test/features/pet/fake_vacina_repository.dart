import 'dart:async';

import 'package:pet_connect/core/utils/br_date.dart';
import 'package:pet_connect/features/pet/domain/vacina.dart';
import 'package:pet_connect/features/pet/domain/vacina_repository.dart';

/// Repositório em memória para testes de widget, sem depender de um
/// Firestore real (ver "Testes" em docs/arquitetura.md).
class FakeVacinaRepository implements VacinaRepository {
  final Map<String, Map<String, Vacina>> _store = {};
  final _changes = StreamController<void>.broadcast();
  int _nextId = 0;

  @override
  Stream<List<Vacina>> watchVacinas(String petId) async* {
    yield _snapshot(petId);
    await for (final _ in _changes.stream) {
      yield _snapshot(petId);
    }
  }

  @override
  Future<void> createVacina(String petId, Vacina vacina) async {
    final id = 'vacina-${_nextId++}';
    _store.putIfAbsent(petId, () => {})[id] =
        Vacina.fromMap(id, vacina.toMap());
    _changes.add(null);
  }

  @override
  Future<void> updateVacina(String petId, Vacina vacina) async {
    _store.putIfAbsent(petId, () => {})[vacina.id] = vacina;
    _changes.add(null);
  }

  @override
  Future<void> deleteVacina(String petId, String vacinaId) async {
    _store[petId]?.remove(vacinaId);
    _changes.add(null);
  }

  List<Vacina> _snapshot(String petId) {
    final vacinas = (_store[petId] ?? {}).values.toList();
    vacinas.sort((a, b) {
      final dataA = parseBrDate(a.dataAplicacao);
      final dataB = parseBrDate(b.dataAplicacao);
      if (dataA == null || dataB == null) return 0;
      return dataA.compareTo(dataB);
    });
    return vacinas;
  }
}
