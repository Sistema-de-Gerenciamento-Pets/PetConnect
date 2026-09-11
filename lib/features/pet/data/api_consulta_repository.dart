import '../../../core/network/api_client.dart';
import '../../../core/utils/br_date.dart';
import '../domain/consulta.dart';
import '../domain/consulta_repository.dart';

/// Implementação de [ConsultaRepository] contra a API Spring (FASE 7).
///
/// Rotas: `/api/v1/pets/{petId}/appointments`. Sem `DELETE` — cancelar é uma
/// mudança de `status` (RF29), como já é a interface do app. Sem stream:
/// `watchConsultas` faz uma emissão única.
class ApiConsultaRepository implements ConsultaRepository {
  ApiConsultaRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const _statusParaApi = {
    ConsultaStatus.agendada: 'CONFIRMED',
    ConsultaStatus.realizada: 'COMPLETED',
    ConsultaStatus.cancelada: 'CANCELLED',
  };
  static const _statusDaApi = {
    'CONFIRMED': ConsultaStatus.agendada,
    'REQUESTED': ConsultaStatus.agendada,
    'PENDING': ConsultaStatus.agendada,
    'COMPLETED': ConsultaStatus.realizada,
    'CANCELLED': ConsultaStatus.cancelada,
    'CANCELLATION_REQUESTED': ConsultaStatus.agendada,
    'REJECTED': ConsultaStatus.cancelada,
  };

  String _base(String petId) => '/pets/$petId/appointments';

  @override
  Stream<List<Consulta>> watchConsultas(String petId) =>
      Stream.fromFuture(_list(petId));

  Future<List<Consulta>> _list(String petId) async {
    final res = await _api.get(_base(petId));
    final list = (res['data'] as List?) ?? const [];
    final consultas = list.cast<Map<String, dynamic>>().map(_fromApi).toList();
    consultas.sort((a, b) {
      final da = parseBrDate(a.data);
      final db = parseBrDate(b.data);
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });
    return consultas;
  }

  @override
  Future<void> createConsulta(String petId, Consulta consulta) async {
    await _api.post(_base(petId), _toApi(consulta));
  }

  @override
  Future<void> updateConsulta(String petId, Consulta consulta) async {
    await _api.patch('${_base(petId)}/${consulta.id}', _toApi(consulta));
  }

  Map<String, dynamic> _toApi(Consulta c) => {
        'scheduledDate': brToIso(c.data),
        'scheduledTime': _horaParaApi(c.horario),
        'veterinarian': c.veterinario,
        'reason': c.motivo,
        'status': _statusParaApi[c.status],
      };

  Consulta _fromApi(Map<String, dynamic> m) => Consulta(
        id: (m['id'] ?? '') as String,
        data: isoToBr(m['scheduledDate'] as String?),
        horario: _horaDaApi(m['scheduledTime'] as String?),
        veterinario: (m['veterinarian'] ?? '') as String,
        motivo: (m['reason'] ?? '') as String,
        status: _statusDaApi[m['status']] ?? ConsultaStatus.agendada,
      );

  /// `HH:mm` (do app) → `HH:mm:ss` (a API espera `LocalTime`). Vazio → `null`.
  static String? _horaParaApi(String? horario) {
    if (horario == null || horario.isEmpty) return null;
    return horario.length == 5 ? '$horario:00' : horario;
  }

  /// `HH:mm:ss` (da API) → `HH:mm`. `null` → `null`.
  static String? _horaDaApi(String? scheduledTime) {
    if (scheduledTime == null || scheduledTime.isEmpty) return null;
    return scheduledTime.length >= 5
        ? scheduledTime.substring(0, 5)
        : scheduledTime;
  }
}
