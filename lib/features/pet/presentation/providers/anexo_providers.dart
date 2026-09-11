import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../data/api_anexo_repository.dart';
import '../../data/cloudinary_anexo_repository.dart';
import '../../domain/anexo_repository.dart';

/// Upload/remoção de arquivos — usado para anexos de histórico médico
/// (RF24) e fotos de perfil (pet e tutor). Cloudinary em qualquer dos dois
/// casos (ver core/config/cloudinary_config.dart); o Firebase Storage não é
/// mais usado (passou a exigir o plano pago no projeto Firebase real).
///
/// Com [AppConfig.useApiForUpload] a assinatura vem do backend (FASE 10) —
/// a `delete` deixa de ser um no-op. Sem a flag, mantém o preset unsigned
/// de sempre (upload funciona, exclusão continua não fazendo nada).
final anexoRepositoryProvider = Provider<AnexoRepository>((ref) {
  if (AppConfig.useApiForUpload) {
    return ApiAnexoRepository(api: ref.watch(apiClientProvider));
  }
  return CloudinaryAnexoRepository();
});
