import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Réplica em Dart de `java.util.UUID.nameUUIDFromBytes(byte[])`, usado pelo
/// backend (`LegacyMigrationService`) para gerar o `publicId` determinístico
/// de um pet migrado: `UUID.nameUUIDFromBytes(("pet:" + legacyFirestoreId))`.
///
/// Corrige a causa raiz do QR code não encontrar pets: `Pet.qrCodeId` só é
/// preenchido pela API (`USE_API_PETS=true`); no modo legado (Firestore
/// direto, o padrão hoje) o app não tem como saber o `publicId` real sem
/// chamar a API. Calculando o mesmo valor aqui, o QR aponta pro `publicId`
/// certo mesmo antes/sem uma flag ligada — desde que a migração tenha
/// rodado (ou rode depois) para aquele pet. Ver
/// docs/fixes/qr-public-pet-not-found.md.
///
/// Não é um UUID v3 "puro" da RFC 4122 (que exigiria um namespace UUID
/// prefixado ao nome) — é especificamente o algoritmo não-padrão do
/// `UUID.nameUUIDFromBytes` do Java: MD5 direto dos bytes informados, com os
/// bits de versão/variant ajustados depois. Reproduzir isso exatamente é
/// obrigatório para bater com o valor que o backend já persistiu.
String legacyPublicIdFor(String legacyFirestoreId) {
  final bytes = utf8.encode('pet:$legacyFirestoreId');
  final digest = Uint8List.fromList(md5.convert(bytes).bytes);

  digest[6] = (digest[6] & 0x0f) | 0x30; // versão 3
  digest[8] = (digest[8] & 0x3f) | 0x80; // variant IETF

  String hex(int start, int end) => digest
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
