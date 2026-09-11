import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../data/api_consulta_repository.dart';
import '../../data/firebase_consulta_repository.dart';
import '../../domain/consulta.dart';
import '../../domain/consulta_repository.dart';

final consultaRepositoryProvider = Provider<ConsultaRepository>((ref) {
  if (AppConfig.useApiForConsultas) {
    return ApiConsultaRepository(api: ref.watch(apiClientProvider));
  }
  return FirebaseConsultaRepository(firestore: ref.watch(firestoreProvider));
});

/// Consultas de um pet (RF28). `family` porque cada perfil de pet observa a
/// própria lista.
///
/// Com [AppConfig.useApiForConsultas] a fonte é
/// `GET /api/v1/pets/{petId}/appointments` (emissão única); as telas chamam
/// `ref.invalidate(consultasProvider(petId))` após mutações e a lista tem
/// pull-to-refresh.
final consultasProvider = StreamProvider.family<List<Consulta>, String>((ref, petId) {
  return ref.watch(consultaRepositoryProvider).watchConsultas(petId);
});
