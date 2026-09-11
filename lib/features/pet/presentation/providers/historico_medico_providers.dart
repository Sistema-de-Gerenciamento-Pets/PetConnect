import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../data/api_historico_medico_repository.dart';
import '../../data/firebase_historico_medico_repository.dart';
import '../../domain/historico_medico.dart';
import '../../domain/historico_medico_repository.dart';

final historicoMedicoRepositoryProvider =
    Provider<HistoricoMedicoRepository>((ref) {
  if (AppConfig.useApiForHistorico) {
    return ApiHistoricoMedicoRepository(api: ref.watch(apiClientProvider));
  }
  return FirebaseHistoricoMedicoRepository(
      firestore: ref.watch(firestoreProvider));
});

/// Histórico médico de um pet (RF25). `family` porque cada perfil de pet
/// observa a própria lista.
///
/// Com [AppConfig.useApiForHistorico] a fonte é
/// `GET /api/v1/pets/{petId}/medical-records` (emissão única); as telas
/// chamam `ref.invalidate(historicoMedicoProvider(petId))` após mutações e a
/// lista tem pull-to-refresh.
final historicoMedicoProvider =
    StreamProvider.family<List<HistoricoMedico>, String>((ref, petId) {
  return ref.watch(historicoMedicoRepositoryProvider).watchHistorico(petId);
});
