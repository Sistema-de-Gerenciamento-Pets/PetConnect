import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/br_date.dart';
import '../domain/consulta.dart';
import '../domain/consulta_repository.dart';

class FirebaseConsultaRepository implements ConsultaRepository {
  FirebaseConsultaRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _consultas(String petId) =>
      _firestore.collection('Pets').doc(petId).collection('consultas');

  @override
  Stream<List<Consulta>> watchConsultas(String petId) {
    return _consultas(petId).snapshots().map((snapshot) {
      final consultas = snapshot.docs
          .map((doc) => Consulta.fromMap(doc.id, doc.data()))
          .toList();
      consultas.sort((a, b) {
        final dataA = parseBrDate(a.data);
        final dataB = parseBrDate(b.data);
        if (dataA == null || dataB == null) return 0;
        return dataA.compareTo(dataB);
      });
      return consultas;
    });
  }

  @override
  Future<void> createConsulta(String petId, Consulta consulta) async {
    await _consultas(petId).add(consulta.toMap());
  }

  @override
  Future<void> updateConsulta(String petId, Consulta consulta) async {
    await _consultas(petId).doc(consulta.id).update(consulta.toMap());
  }
}
