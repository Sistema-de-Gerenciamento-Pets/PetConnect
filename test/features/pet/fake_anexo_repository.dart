import 'dart:typed_data';

import 'package:pet_connect/features/pet/domain/anexo_repository.dart';

/// Fake sem operação real — nos testes de widget, o fluxo de seleção de
/// arquivo (image_picker) não é exercido, pois depende de um canal de
/// plataforma indisponível em `flutter test`. Isto só evita que os
/// providers de histórico médico toquem o Firebase Storage real.
class FakeAnexoRepository implements AnexoRepository {
  @override
  Future<String> upload(
      {required String path,
      required Uint8List bytes,
      required String contentType}) async {
    return 'https://fake.storage/$path';
  }

  @override
  Future<void> delete(String url) async {}
}
