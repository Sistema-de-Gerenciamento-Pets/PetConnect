import '../../../core/utils/legacy_public_id.dart';
import 'pet.dart';

/// URL que o QR code de um pet codifica (RF16), consumida pela página
/// pública em `pet-connect-c53f1.web.app` (Firebase Hosting, FASE 9).
///
/// [pet.qrCodeId] só vem preenchido quando o pet foi carregado pela API
/// (`USE_API_PETS=true`) — é o `publicId` do Mongo. No modo legado
/// (Firestore direto, ainda o padrão), [pet.qrCodeId] é sempre nulo, e usar
/// [pet.id] (o id do documento Firestore) faz o QR apontar pra um valor que
/// o endpoint público nunca reconhece — causa raiz documentada em
/// docs/fixes/qr-public-pet-not-found.md. Em vez de cair em [pet.id],
/// calculamos aqui o mesmo `publicId` determinístico que a migração
/// (`LegacyMigrationService`) gera pra esse pet — assim o QR já aponta pro
/// valor certo, mesmo enquanto a flag da API estiver desligada.
String publicPetUrl(Pet pet) {
  final id = pet.qrCodeId ?? legacyPublicIdFor(pet.id);
  return 'https://pet-connect-c53f1.web.app/pet/$id';
}
