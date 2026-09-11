import 'dart:math';

import '../../../core/network/api_client.dart';
import '../../../core/utils/br_date.dart';
import '../domain/historico_medico.dart';
import '../domain/historico_medico_repository.dart';

/// Implementação de [HistoricoMedicoRepository] contra a API Spring (FASE 8).
///
/// Rotas: `/api/v1/pets/{petId}/medical-records`. Os anexos continuam
/// subindo direto para o Cloudinary (preset unsigned) — a API só guarda as
/// URLs. Como o app sobe os anexos **antes** de o registro existir, usando o
/// id do registro no caminho do arquivo, [novoId] gera um id localmente (sem
/// rede) e o backend o aceita como `_id` no `POST` (em vez de gerar um
/// `ObjectId`).
class ApiHistoricoMedicoRepository implements HistoricoMedicoRepository {
  ApiHistoricoMedicoRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  String _base(String petId) => '/pets/$petId/medical-records';

  @override
  String novoId(String petId) {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Stream<List<HistoricoMedico>> watchHistorico(String petId) => Stream.fromFuture(_list(petId));

  Future<List<HistoricoMedico>> _list(String petId) async {
    final res = await _api.get(_base(petId));
    final list = (res['data'] as List?) ?? const [];
    final registros = list.cast<Map<String, dynamic>>().map(_fromApi).toList();
    registros.sort((a, b) {
      final da = parseBrDate(a.data);
      final db = parseBrDate(b.data);
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });
    return registros;
  }

  @override
  Future<void> createHistorico(String petId, HistoricoMedico historico) async {
    await _api.post(_base(petId), _toApi(historico, incluirId: true));
  }

  @override
  Future<void> updateHistorico(String petId, HistoricoMedico historico) async {
    await _api.patch('${_base(petId)}/${historico.id}', _toApi(historico, incluirId: false));
  }

  @override
  Future<void> deleteHistorico(String petId, String historicoId) async {
    await _api.delete('${_base(petId)}/$historicoId');
  }

  Map<String, dynamic> _toApi(HistoricoMedico h, {required bool incluirId}) => {
        if (incluirId) 'id': h.id,
        'recordedAt': brToIso(h.data),
        'description': h.descricao,
        'veterinarian': h.veterinario,
        'attachments': h.anexos,
      };

  HistoricoMedico _fromApi(Map<String, dynamic> m) => HistoricoMedico(
        id: (m['id'] ?? '') as String,
        data: isoToBr(m['recordedAt'] as String?),
        descricao: (m['description'] ?? '') as String,
        veterinario: m['veterinarian'] as String?,
        anexos: (m['attachments'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
}
