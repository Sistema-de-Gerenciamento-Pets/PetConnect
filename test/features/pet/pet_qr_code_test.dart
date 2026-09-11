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
  test('usa o id do pet quando não há qrCodeId (RF16)', () {
    expect(publicPetUrl(_pet()), 'https://pet-connect-c53f1.web.app/pet/pet-1');
  });

  test('usa o qrCodeId quando presente, preparando a regeneração (RF19)', () {
    expect(publicPetUrl(_pet(qrCodeId: 'qr-abc')),
        'https://pet-connect-c53f1.web.app/pet/qr-abc');
  });
}
