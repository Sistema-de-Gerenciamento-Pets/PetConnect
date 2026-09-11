import '../../../core/network/api_client.dart';
import '../../../core/utils/br_date.dart';
import '../domain/localizacao.dart';
import '../domain/localizacao_repository.dart';

/// Implementação de [LocalizacaoRepository] contra a API Spring (FASE 9).
///
/// Rotas: `/api/v1/pets/{petId}/locations` (autenticado — visão do próprio
/// tutor, RF32). Traz de brinde o histórico migrado do Firestore (avistamentos
/// antigos do QR) misturado com os novos. O relato anônimo pela página
/// pública (RF31) é um endpoint à parte (`/api/v1/public/...`), sem
/// equivalente neste repositório.
class ApiLocalizacaoRepository implements LocalizacaoRepository {
  ApiLocalizacaoRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  String _base(String petId) => '/pets/$petId/locations';

  @override
  Stream<List<Localizacao>> watchLocalizacoes(String petId) => Stream.fromFuture(_list(petId));

  Future<List<Localizacao>> _list(String petId) async {
    final res = await _api.get(_base(petId));
    final list = (res['data'] as List?) ?? const [];
    final localizacoes = list.cast<Map<String, dynamic>>().map(_fromApi).toList();
    localizacoes.sort((a, b) {
      final da = parseBrDate(a.data);
      final db = parseBrDate(b.data);
      if (da == null || db == null) return 0;
      return db.compareTo(da); // mais recente primeiro
    });
    return localizacoes;
  }

  @override
  Future<void> createLocalizacao(String petId, Localizacao localizacao) async {
    await _api.post(_base(petId), {
      if (localizacao.data.isNotEmpty) 'reportedAt': brToIso(localizacao.data),
      'description': localizacao.descricao,
      'reporterContact': localizacao.contatoReportante,
    });
  }

  Localizacao _fromApi(Map<String, dynamic> m) => Localizacao(
        id: (m['id'] ?? '') as String,
        data: isoToBr(m['reportedAt'] as String?),
        descricao: (m['description'] ?? '') as String,
        contatoReportante: m['reporterContact'] as String?,
      );
}
