/// Espelha a coleção `Usuarios` já existente no Firestore.
///
/// [id] é o UID do Firebase Auth (mesmo valor do docId em `Usuarios`).
/// [usuarioID] é um campo separado (UUID) já presente no banco — seu uso
/// ainda não foi confirmado (ver docs/modelo-dados-firestore.md).
class Usuario {
  const Usuario({
    required this.id,
    required this.usuarioID,
    required this.nome,
    required this.email,
    required this.telefone,
    required this.dataNascimento,
    required this.genero,
    this.sobrenome = '',
    this.foto,
  });

  final String id;
  final String usuarioID;
  final String nome;

  /// Campo novo (não existia no banco original) — contas criadas antes
  /// desta versão simplesmente não têm o valor até o tutor editar o
  /// perfil (RF08). Ver docs/modelo-dados-firestore.md.
  final String sobrenome;
  final String email;
  final String telefone;

  /// Formato `dd/MM/yyyy`, como já armazenado no banco existente.
  final String dataNascimento;
  final String genero;
  final String? foto;

  /// Nome completo (nome + sobrenome), usado em saudações/exibição.
  String get nomeCompleto =>
      [nome, sobrenome].where((s) => s.isNotEmpty).join(' ');

  factory Usuario.fromMap(String id, Map<String, dynamic> map) {
    return Usuario(
      id: id,
      usuarioID: map['usuarioID'] as String? ?? '',
      nome: map['nome'] as String? ?? '',
      sobrenome: map['sobrenome'] as String? ?? '',
      email: map['email'] as String? ?? '',
      telefone: map['telefone'] as String? ?? '',
      dataNascimento: map['dataNascimento'] as String? ?? '',
      genero: map['genero'] as String? ?? '',
      foto: map['foto'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuarioID': usuarioID,
      'nome': nome,
      'sobrenome': sobrenome,
      'email': email,
      'telefone': telefone,
      'dataNascimento': dataNascimento,
      'genero': genero,
      'foto': foto,
    };
  }

  Usuario copyWith({
    String? nome,
    String? sobrenome,
    String? email,
    String? telefone,
    String? dataNascimento,
    String? genero,
    String? foto,
  }) {
    return Usuario(
      id: id,
      usuarioID: usuarioID,
      nome: nome ?? this.nome,
      sobrenome: sobrenome ?? this.sobrenome,
      email: email ?? this.email,
      telefone: telefone ?? this.telefone,
      dataNascimento: dataNascimento ?? this.dataNascimento,
      genero: genero ?? this.genero,
      foto: foto ?? this.foto,
    );
  }
}
