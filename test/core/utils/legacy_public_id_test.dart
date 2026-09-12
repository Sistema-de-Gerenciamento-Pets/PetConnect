import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/utils/legacy_public_id.dart';

void main() {
  // Vetores de referência REAIS: publicId de fato persistido no MongoDB
  // pela migração (LegacyMigrationService), conferido diretamente no banco
  // antes de escrever este teste — não são valores inventados. Cobre pets
  // legados (migrados antes) e um pet criado depois da migração original
  // (Aleks), migrado de novo na correção do QR code
  // (docs/fixes/qr-public-pet-not-found.md).
  test('bate com o publicId real da Nymeria (pet legado)', () {
    expect(legacyPublicIdFor('G58iMXlRw7jbach4qZMX'),
        '7cd148f7-07b3-3505-b721-4e256d24cdef');
  });

  test('bate com o publicId real da Felícia (pet legado)', () {
    expect(legacyPublicIdFor('SagiwDNXvwv0XRBCt1Qj'),
        '120be11d-c25d-3a9e-a018-659f3da8fcff');
  });

  test('bate com o publicId real do Aleks (pet criado depois da 1ª migração)',
      () {
    expect(legacyPublicIdFor('GDjlbLE2PbatnjwoH5Ch'),
        'ecd2daf7-1279-3785-ac70-d06dfd03ee18');
  });

  test('é determinístico — mesmo id sempre gera o mesmo resultado', () {
    final a = legacyPublicIdFor('abc123');
    final b = legacyPublicIdFor('abc123');
    expect(a, b);
  });

  test('ids diferentes geram valores diferentes', () {
    expect(legacyPublicIdFor('abc123'), isNot(legacyPublicIdFor('xyz789')));
  });
}
