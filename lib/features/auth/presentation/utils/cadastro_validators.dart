/// Regras de validação da tela de Cadastro — funções puras, sem qualquer
/// dependência de widget, pra serem testadas isoladamente (seção 28 de
/// prompt_redesign_tela_cadastro_petconnect.md).
library;

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _caractereEspecialRegex =
    RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]/\\;`~]');

/// "Informe seu nome." — obrigatório, sem exigir um mínimo de caracteres
/// artificial (rejeitaria nomes curtos legítimos).
String? validarNome(String? value) {
  final nome = (value ?? '').trim();
  if (nome.isEmpty) return 'Informe seu nome.';
  return null;
}

/// "Informe um e-mail válido." — formato simples (usuário@domínio.algo),
/// não tenta replicar a RFC inteira de e-mail (isso é trabalho do backend/
/// Firebase Auth, que rejeita formatos realmente inválidos).
String? validarEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty || !_emailRegex.hasMatch(email)) {
    return 'Informe um e-mail válido.';
  }
  return null;
}

/// Só dígitos, sem máscara — usado tanto pra validar quanto para o que é
/// de fato enviado à conta (o texto mascarado é só apresentação).
String telefoneSomenteDigitos(String value) =>
    value.replaceAll(RegExp(r'[^0-9]'), '');

/// "Informe um telefone válido." — exige 10 dígitos (fixo) ou 11
/// (celular), igual à regra de máscara de [BrPhoneInputFormatter].
String? validarTelefone(String? value) {
  final digitos = telefoneSomenteDigitos(value ?? '');
  if (digitos.length != 10 && digitos.length != 11) {
    return 'Informe um telefone válido.';
  }
  return null;
}

// --- Senha ---------------------------------------------------------------

bool senhaTemTamanhoMinimo(String senha) => senha.length >= 9;
bool senhaTemMaiuscula(String senha) => senha.contains(RegExp(r'[A-Z]'));
bool senhaTemMinuscula(String senha) => senha.contains(RegExp(r'[a-z]'));
bool senhaTemNumero(String senha) => senha.contains(RegExp(r'[0-9]'));
bool senhaTemCaractereEspecial(String senha) =>
    senha.contains(_caractereEspecialRegex);

/// Política de senha (seção 11/35): mínimo 9 caracteres, com maiúscula,
/// minúscula, número e caractere especial — todos obrigatórios.
bool senhaAtendeRequisitos(String senha) =>
    senhaTemTamanhoMinimo(senha) &&
    senhaTemMaiuscula(senha) &&
    senhaTemMinuscula(senha) &&
    senhaTemNumero(senha) &&
    senhaTemCaractereEspecial(senha);

/// "Sua senha ainda não atende aos requisitos." — mensagem única e
/// amigável; o detalhe de qual requisito falta fica por conta do
/// checklist visual (PasswordRequirementsChecklist), não desta mensagem.
String? validarSenha(String? value) {
  final senha = value ?? '';
  return senhaAtendeRequisitos(senha)
      ? null
      : 'Sua senha ainda não atende aos requisitos.';
}

/// "Confirme sua senha." / "As senhas não coincidem."
String? validarConfirmacaoSenha(String senha, String? value) {
  final confirmacao = value ?? '';
  if (confirmacao.isEmpty) return 'Confirme sua senha.';
  if (confirmacao != senha) return 'As senhas não coincidem.';
  return null;
}
