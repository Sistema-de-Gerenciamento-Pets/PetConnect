import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/br_date.dart';
import '../domain/localizacao.dart';
import '../domain/localizacao_repository.dart';

class FirebaseLocalizacaoRepository implements LocalizacaoRepository {
  FirebaseLocalizacaoRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _localizacoes(String petId) =>
      _firestore.collection('Pets').doc(petId).collection('localizacoes');

  @override
  Stream<List<Localizacao>> watchLocalizacoes(String petId) {
    return _localizacoes(petId).snapshots().map((snapshot) {
      final localizacoes = snapshot.docs
          .map((doc) => Localizacao.fromMap(doc.id, doc.data()))
          .toList();
      localizacoes.sort((a, b) {
        final dataA = parseBrDate(a.data);
        final dataB = parseBrDate(b.data);
        if (dataA == null || dataB == null) return 0;
        return dataB.compareTo(dataA); // mais recente primeiro
      });
      return localizacoes;
    });
  }

  @override
  Future<void> createLocalizacao(String petId, Localizacao localizacao) async {
    await _localizacoes(petId).add(localizacao.toMap());
  }
}
