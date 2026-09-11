import 'dart:async';

import 'package:pet_connect/core/utils/br_date.dart';
import 'package:pet_connect/features/pet/domain/localizacao.dart';
import 'package:pet_connect/features/pet/domain/localizacao_repository.dart';

/// Repositório em memória para testes de widget, sem depender de um
/// Firestore real (ver "Testes" em docs/arquitetura.md).
class FakeLocalizacaoRepository implements LocalizacaoRepository {
  final Map<String, Map<String, Localizacao>> _store = {};
  final _changes = StreamController<void>.broadcast();
  int _nextId = 0;

  @override
  Stream<List<Localizacao>> watchLocalizacoes(String petId) async* {
    yield _snapshot(petId);
    await for (final _ in _changes.stream) {
      yield _snapshot(petId);
    }
  }

  @override
  Future<void> createLocalizacao(String petId, Localizacao localizacao) async {
    final id = 'localizacao-${_nextId++}';
    _store.putIfAbsent(petId, () => {})[id] =
        Localizacao.fromMap(id, localizacao.toMap());
    _changes.add(null);
  }

  List<Localizacao> _snapshot(String petId) {
    final localizacoes = (_store[petId] ?? {}).values.toList();
    localizacoes.sort((a, b) {
      final dataA = parseBrDate(a.data);
      final dataB = parseBrDate(b.data);
      if (dataA == null || dataB == null) return 0;
      return dataB.compareTo(dataA);
    });
    return localizacoes;
  }
}
