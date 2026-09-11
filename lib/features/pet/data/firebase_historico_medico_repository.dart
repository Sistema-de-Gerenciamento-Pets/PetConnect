import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/br_date.dart';
import '../domain/historico_medico.dart';
import '../domain/historico_medico_repository.dart';

class FirebaseHistoricoMedicoRepository implements HistoricoMedicoRepository {
  FirebaseHistoricoMedicoRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _historico(String petId) =>
      _firestore.collection('Pets').doc(petId).collection('historicoMedico');

  @override
  String novoId(String petId) => _historico(petId).doc().id;

  @override
  Stream<List<HistoricoMedico>> watchHistorico(String petId) {
    return _historico(petId).snapshots().map((snapshot) {
      final registros = snapshot.docs
          .map((doc) => HistoricoMedico.fromMap(doc.id, doc.data()))
          .toList();
      registros.sort((a, b) {
        final dataA = parseBrDate(a.data);
        final dataB = parseBrDate(b.data);
        if (dataA == null || dataB == null) return 0;
        return dataA.compareTo(dataB);
      });
      return registros;
    });
  }

  @override
  Future<void> createHistorico(String petId, HistoricoMedico historico) async {
    await _historico(petId).doc(historico.id).set(historico.toMap());
  }

  @override
  Future<void> updateHistorico(String petId, HistoricoMedico historico) async {
    await _historico(petId).doc(historico.id).update(historico.toMap());
  }

  @override
  Future<void> deleteHistorico(String petId, String historicoId) async {
    await _historico(petId).doc(historicoId).delete();
  }
}
