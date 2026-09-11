import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../data/api_localizacao_repository.dart';
import '../../data/firebase_localizacao_repository.dart';
import '../../domain/localizacao.dart';
import '../../domain/localizacao_repository.dart';

final localizacaoRepositoryProvider = Provider<LocalizacaoRepository>((ref) {
  if (AppConfig.useApiForLocalizacao) {
    return ApiLocalizacaoRepository(api: ref.watch(apiClientProvider));
  }
  return FirebaseLocalizacaoRepository(firestore: ref.watch(firestoreProvider));
});

/// Registros de localização de um pet (RF32). `family` porque cada perfil
/// de pet observa a própria lista.
///
/// Com [AppConfig.useApiForLocalizacao] a fonte é
/// `GET /api/v1/pets/{petId}/locations` (emissão única, inclui o histórico
/// migrado do Firestore); as telas chamam
/// `ref.invalidate(localizacoesProvider(petId))` após registrar um novo
/// avistamento e a lista tem pull-to-refresh.
final localizacoesProvider =
    StreamProvider.family<List<Localizacao>, String>((ref, petId) {
  return ref.watch(localizacaoRepositoryProvider).watchLocalizacoes(petId);
});
