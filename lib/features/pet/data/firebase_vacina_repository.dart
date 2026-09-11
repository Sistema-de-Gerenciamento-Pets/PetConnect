import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/br_date.dart';
import '../domain/vacina.dart';
import '../domain/vacina_repository.dart';

class FirebaseVacinaRepository implements VacinaRepository {
  FirebaseVacinaRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _vacinas(String petId) =>
      _firestore.collection('Pets').doc(petId).collection('vacinas');

  @override
  Stream<List<Vacina>> watchVacinas(String petId) {
    return _vacinas(petId).snapshots().map((snapshot) {
      final vacinas = snapshot.docs
          .map((doc) => Vacina.fromMap(doc.id, doc.data()))
          .toList();
      vacinas.sort((a, b) {
        final dataA = parseBrDate(a.dataAplicacao);
        final dataB = parseBrDate(b.dataAplicacao);
        if (dataA == null || dataB == null) return 0;
        return dataA.compareTo(dataB);
      });
      return vacinas;
    });
  }

  @override
  Future<void> createVacina(String petId, Vacina vacina) async {
    await _vacinas(petId).add(vacina.toMap());
  }

  @override
  Future<void> updateVacina(String petId, Vacina vacina) async {
    await _vacinas(petId).doc(vacina.id).update(vacina.toMap());
  }

  @override
  Future<void> deleteVacina(String petId, String vacinaId) async {
    await _vacinas(petId).doc(vacinaId).delete();
  }
}
