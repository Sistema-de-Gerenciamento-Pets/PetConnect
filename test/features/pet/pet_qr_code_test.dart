import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/domain/pet_qr_code.dart';

Pet _pet({String? qrCodeId}) {
  return Pet(
    id: 'pet-1',
    userId: 'uid-1',
    nome: 'Rex',
    especie: 'Cachorro',
    raca: '',
    cor: '',
    genero: '',
    porte: '',
    peso: '',
    dataNascimento: '',
    vacinado: false,
    qrCodeId: qrCodeId,
  );
}

void main() {
  test(
      'sem qrCodeId, calcula o publicId determinístico a partir do id (RF16 '
      '— causa raiz documentada em docs/fixes/qr-public-pet-not-found.md)', () {
    // 'pet-1' -> mesmo cálculo que legacy_public_id_test.dart, conferido
    // contra o algoritmo do backend (LegacyMigrationService).
    expect(publicPetUrl(_pet()),
        'https://pet-connect-c53f1.web.app/pet/b5ab5677-27c9-3f7c-98f8-370d7fcd526c');
  });

  test('usa o qrCodeId quando presente, preparando a regeneração (RF19)', () {
    expect(publicPetUrl(_pet(qrCodeId: 'qr-abc')),
        'https://pet-connect-c53f1.web.app/pet/qr-abc');
  });
}
