import '../../../core/network/api_client.dart';
import '../../../core/utils/br_date.dart';
import '../domain/vacina.dart';
import '../domain/vacina_repository.dart';

/// Implementação de [VacinaRepository] contra a API Spring (FASE 6).
///
/// Rotas: `/api/v1/pets/{petId}/vaccines`. A posse do pet é validada no
/// servidor. Sem stream — `watchVacinas` faz uma emissão única e as telas
/// invalidam `vacinasProvider(petId)` após mutações.
class ApiVacinaRepository implements VacinaRepository {
  ApiVacinaRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  String _base(String petId) => '/pets/$petId/vaccines';

  @override
  Stream<List<Vacina>> watchVacinas(String petId) => Stream.fromFuture(_list(petId));

  Future<List<Vacina>> _list(String petId) async {
    final res = await _api.get(_base(petId));
    final list = (res['data'] as List?) ?? const [];
    final vacinas = list.cast<Map<String, dynamic>>().map(_fromApi).toList();
    vacinas.sort((a, b) {
      final da = parseBrDate(a.dataAplicacao);
      final db = parseBrDate(b.dataAplicacao);
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });
    return vacinas;
  }

  @override
  Future<void> createVacina(String petId, Vacina vacina) async {
    await _api.post(_base(petId), _toApi(vacina));
  }

  @override
  Future<void> updateVacina(String petId, Vacina vacina) async {
    await _api.patch('${_base(petId)}/${vacina.id}', _toApi(vacina));
  }

  @override
  Future<void> deleteVacina(String petId, String vacinaId) async {
    await _api.delete('${_base(petId)}/$vacinaId');
  }

  Map<String, dynamic> _toApi(Vacina v) => {
        'name': v.nome,
        'appliedAt': brToIso(v.dataAplicacao),
        'nextDoseAt': (v.proximaDose == null || v.proximaDose!.isEmpty)
            ? null
            : brToIso(v.proximaDose!),
        'veterinarian': v.veterinario,
        'notes': v.observacoes,
      };

  Vacina _fromApi(Map<String, dynamic> m) {
    final proxima = isoToBr(m['nextDoseAt'] as String?);
    return Vacina(
      id: (m['id'] ?? '') as String,
      nome: (m['name'] ?? '') as String,
      dataAplicacao: isoToBr(m['appliedAt'] as String?),
      proximaDose: proxima.isEmpty ? null : proxima,
      veterinario: m['veterinarian'] as String?,
      observacoes: m['notes'] as String?,
    );
  }
}
