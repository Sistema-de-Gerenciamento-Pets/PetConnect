/// Espelha a coleção `Pets` já existente no Firestore, com o campo
/// [vacinado] adicionado nesta fase (ver docs/modelo-dados-firestore.md).
///
/// [dono] é mantido por compatibilidade com documentos existentes, mas sua
/// função é redundante com [userId] — ainda não confirmada.
class Pet {
  const Pet({
    required this.id,
    required this.userId,
    required this.nome,
    required this.especie,
    required this.raca,
    required this.cor,
    required this.genero,
    required this.porte,
    required this.peso,
    required this.dataNascimento,
    required this.vacinado,
    this.dono,
    this.telefone,
    this.foto,
    this.capa,
    this.qrCodeId,
  });

  final String id;
  final String userId;
  final String nome;
  final String especie;
  final String raca;
  final String cor;
  final String genero;
  final String porte;

  /// Armazenado como string no banco existente (ex: `"12kg"`), não número.
  final String peso;

  /// Formato `dd/MM/yyyy`, pode ser vazio.
  final String dataNascimento;

  final bool vacinado;
  final String? dono;

  /// Contato a exibir na página pública do QR code; se nulo, usa o
  /// telefone do usuário dono (Usuario.telefone).
  final String? telefone;

  final String? foto;

  /// Foto de capa do cabeçalho do perfil (fica atrás do avatar). Pets
  /// legados não têm — nula/vazia é o caso normal, tratado com fallback
  /// visual, nunca um erro.
  final String? capa;

  /// Identificador usado na URL pública do QR code (RF16/RF19). Pode ser
  /// igual a [id] até que a regeneração de QR code (RF19) seja implementada.
  final String? qrCodeId;

  factory Pet.fromMap(String id, Map<String, dynamic> map) {
    return Pet(
      id: id,
      userId: map['userId'] as String? ?? '',
      nome: map['nome'] as String? ?? '',
      especie: map['especie'] as String? ?? '',
      raca: map['raca'] as String? ?? '',
      cor: map['cor'] as String? ?? '',
      genero: map['genero'] as String? ?? '',
      porte: map['porte'] as String? ?? '',
      peso: map['peso'] as String? ?? '',
      dataNascimento: map['dataNascimento'] as String? ?? '',
      vacinado: map['vacinado'] as bool? ?? false,
      dono: map['dono'] as String?,
      telefone: map['telefone'] as String?,
      foto: map['foto'] as String?,
      capa: map['capa'] as String?,
      qrCodeId: map['qrCodeId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'nome': nome,
      'especie': especie,
      'raca': raca,
      'cor': cor,
      'genero': genero,
      'porte': porte,
      'peso': peso,
      'dataNascimento': dataNascimento,
      'vacinado': vacinado,
      'dono': dono,
      'telefone': telefone,
      'foto': foto,
      'capa': capa,
      'qrCodeId': qrCodeId,
    };
  }

  Pet copyWith({
    String? nome,
    String? especie,
    String? raca,
    String? cor,
    String? genero,
    String? porte,
    String? peso,
    String? dataNascimento,
    bool? vacinado,
    String? dono,
    String? telefone,
    String? foto,
    String? capa,
    String? qrCodeId,
  }) {
    return Pet(
      id: id,
      userId: userId,
      nome: nome ?? this.nome,
      especie: especie ?? this.especie,
      raca: raca ?? this.raca,
      cor: cor ?? this.cor,
      genero: genero ?? this.genero,
      porte: porte ?? this.porte,
      peso: peso ?? this.peso,
      dataNascimento: dataNascimento ?? this.dataNascimento,
      vacinado: vacinado ?? this.vacinado,
      dono: dono ?? this.dono,
      telefone: telefone ?? this.telefone,
      foto: foto ?? this.foto,
      capa: capa ?? this.capa,
      qrCodeId: qrCodeId ?? this.qrCodeId,
    );
  }
}
