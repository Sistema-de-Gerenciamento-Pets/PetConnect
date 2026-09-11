import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../data/api_vacina_repository.dart';
import '../../data/firebase_vacina_repository.dart';
import '../../domain/vacina.dart';
import '../../domain/vacina_repository.dart';

final vacinaRepositoryProvider = Provider<VacinaRepository>((ref) {
  if (AppConfig.useApiForVacinas) {
    return ApiVacinaRepository(api: ref.watch(apiClientProvider));
  }
  return FirebaseVacinaRepository(firestore: ref.watch(firestoreProvider));
});

/// Vacinas de um pet (RF21). `family` porque cada perfil de pet observa a
/// própria lista.
///
/// Com [AppConfig.useApiForVacinas] a fonte é `GET /api/v1/pets/{petId}/vaccines`
/// (emissão única); as telas chamam `ref.invalidate(vacinasProvider(petId))`
/// após mutações e a lista tem pull-to-refresh.
final vacinasProvider =
    StreamProvider.family<List<Vacina>, String>((ref, petId) {
  return ref.watch(vacinaRepositoryProvider).watchVacinas(petId);
});
