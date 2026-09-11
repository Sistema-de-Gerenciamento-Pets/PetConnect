import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/br_date.dart';
import '../domain/usuario.dart';
import '../domain/usuario_repository.dart';

/// Implementação de [UsuarioRepository] contra a API Spring (FASE 4).
///
/// Autenticação (login, cadastro, reset, logout) continua no **Firebase Auth**.
/// Só o *perfil* do tutor passa a vir de `GET`/`PATCH`/`DELETE /api/v1/me`.
class ApiUsuarioRepository implements UsuarioRepository {
  ApiUsuarioRepository({required FirebaseAuth auth, required ApiClient api})
      : _auth = auth,
        _api = api;

  final FirebaseAuth _auth;
  final ApiClient _api;

  static const _generoParaApi = {
    'Homem': 'MALE',
    'Mulher': 'FEMALE',
    'Outro': 'OTHER',
  };
  static const _generoDaApi = {
    'MALE': 'Homem',
    'FEMALE': 'Mulher',
    'OTHER': 'Outro',
    'UNDISCLOSED': '',
  };

  @override
  Stream<Usuario?> watchUsuario(String uid) => Stream.fromFuture(_fetchMe());

  Future<Usuario?> _fetchMe() async {
    try {
      final json = await _api.get('/me');
      return _usuarioFromApi(json);
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signUp({
    required String nome,
    required String email,
    required String password,
    required String telefone,
    required String dataNascimento,
  }) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);

    // 1ª chamada provisiona o documento `users` no MongoDB.
    await _api.get('/me');

    // Grava os campos coletados no cadastro (o provisionamento só usa o
    // displayName do token, que aqui é vazio).
    await _api.patch('/me', {
      'firstName': nome,
      if (telefone.isNotEmpty) 'phone': telefone,
      if (dataNascimento.isNotEmpty) 'birthDate': _brParaIso(dataNascimento),
    });
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> updateUsuario({
    required String nome,
    required String sobrenome,
    required String telefone,
    required String dataNascimento,
    required String genero,
    String? foto,
  }) async {
    await _api.patch('/me', {
      'firstName': nome,
      'lastName': sobrenome,
      'phone': telefone,
      if (dataNascimento.isNotEmpty) 'birthDate': _brParaIso(dataNascimento),
      if (_generoParaApi[genero] != null) 'gender': _generoParaApi[genero],
      if (foto != null) 'photoUrl': foto,
    });
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _api.delete('/me'); // cascata de pets/localizações + Firebase Auth
    } on ApiException catch (e) {
      // 401: a conta/usuário do Auth já foi removida no servidor — segue.
      if (!e.isUnauthorized) rethrow;
    }
    try {
      await _auth.currentUser?.delete();
    } catch (_) {
      // servidor sem Admin SDK, ou requires-recent-login — o signOut abaixo
      // já tira o usuário da sessão.
    }
    await _auth.signOut();
  }

  // ---------------------------------------------------------------- mapeamento

  Usuario _usuarioFromApi(Map<String, dynamic> m) {
    return Usuario(
      id: (m['firebaseUid'] ?? m['id'] ?? '') as String,
      usuarioID: (m['id'] ?? '') as String,
      nome: (m['firstName'] ?? '') as String,
      sobrenome: (m['lastName'] ?? '') as String,
      email: (m['email'] ?? '') as String,
      telefone: (m['phone'] ?? '') as String,
      dataNascimento: _isoParaBr(m['birthDate'] as String?),
      genero: _generoDaApi[m['gender']] ?? '',
      foto: m['photoUrl'] as String?,
    );
  }

  /// `dd/MM/yyyy` → `yyyy-MM-dd` (ISO 8601). Assume entrada válida.
  static String _brParaIso(String br) {
    final d = parseBrDate(br);
    if (d == null) return br;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// `yyyy-MM-dd` → `dd/MM/yyyy`. Vazio/nulo → `''`.
  static String _isoParaBr(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    return d == null ? '' : formatBrDate(d);
  }
}
