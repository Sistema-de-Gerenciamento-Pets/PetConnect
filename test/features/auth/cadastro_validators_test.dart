// Testes unitários das regras de validação do Cadastro (seção 28 de
// prompt_redesign_tela_cadastro_petconnect.md) — funções puras, sem
// widgets.
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/auth/presentation/utils/cadastro_validators.dart';

void main() {
  group('validarNome', () {
    test('vazio é inválido', () {
      expect(validarNome(''), 'Informe seu nome.');
      expect(validarNome(null), 'Informe seu nome.');
      expect(validarNome('   '), 'Informe seu nome.');
    });

    test('preenchido é válido', () {
      expect(validarNome('Maria Silva'), isNull);
    });
  });

  group('validarEmail', () {
    test('vazio é inválido', () {
      expect(validarEmail(''), 'Informe um e-mail válido.');
    });

    test('formato incorreto é inválido', () {
      expect(validarEmail('maria'), isNotNull);
      expect(validarEmail('maria@'), isNotNull);
      expect(validarEmail('maria@dominio'), isNotNull);
      expect(validarEmail('@dominio.com'), isNotNull);
    });

    test('formato correto é válido', () {
      expect(validarEmail('maria@dominio.com'), isNull);
      expect(validarEmail('  maria@dominio.com  '), isNull);
    });
  });

  group('validarTelefone', () {
    test('menos de 10 dígitos é inválido', () {
      expect(validarTelefone('(19) 991'), isNotNull);
    });

    test('10 dígitos (fixo) é válido', () {
      expect(validarTelefone('(19) 3232-1234'), isNull);
    });

    test('11 dígitos (celular) é válido', () {
      expect(validarTelefone('(19) 99715-0817'), isNull);
    });

    test('mais de 11 dígitos é inválido', () {
      expect(validarTelefone('199971508171'), isNotNull);
    });

    test('caracteres não numéricos são ignorados na contagem', () {
      expect(validarTelefone('19997150817'), isNull); // 11 dígitos crus
    });
  });

  group('requisitos de senha individuais', () {
    test('tamanho mínimo', () {
      expect(senhaTemTamanhoMinimo('12345678'), isFalse); // 8
      expect(senhaTemTamanhoMinimo('123456789'), isTrue); // 9
    });

    test('maiúscula', () {
      expect(senhaTemMaiuscula('semmaiuscula1@'), isFalse);
      expect(senhaTemMaiuscula('ComMaiuscula1@'), isTrue);
    });

    test('minúscula', () {
      expect(senhaTemMinuscula('SEMMINUSCULA1@'), isFalse);
      expect(senhaTemMinuscula('ComMinuscula1@'), isTrue);
    });

    test('número', () {
      expect(senhaTemNumero('SemNumeroAqui@'), isFalse);
      expect(senhaTemNumero('ComNumero1Aqui@'), isTrue);
    });

    test('caractere especial', () {
      expect(senhaTemCaractereEspecial('SemEspecial123'), isFalse);
      expect(senhaTemCaractereEspecial('ComEspecial123@'), isTrue);
    });
  });

  group('senhaAtendeRequisitos / validarSenha', () {
    test('8 caracteres é inválida', () {
      expect(senhaAtendeRequisitos('Abc123@a'), isFalse); // 8 chars
    });

    test('9+ sem maiúscula é inválida', () {
      expect(senhaAtendeRequisitos('abcdef123@'), isFalse);
    });

    test('9+ sem minúscula é inválida', () {
      expect(senhaAtendeRequisitos('ABCDEF123@'), isFalse);
    });

    test('9+ sem número é inválida', () {
      expect(senhaAtendeRequisitos('AbcdefGhi@'), isFalse);
    });

    test('9+ sem caractere especial é inválida', () {
      expect(senhaAtendeRequisitos('Abcdef1234'), isFalse);
    });

    test('atendendo tudo é válida', () {
      expect(senhaAtendeRequisitos('PetConnect@9'), isTrue);
      expect(validarSenha('PetConnect@9'), isNull);
    });

    test('mensagem de erro quando não atende', () {
      expect(validarSenha('123'), 'Sua senha ainda não atende aos requisitos.');
    });
  });

  group('validarConfirmacaoSenha', () {
    test('vazia é inválida', () {
      expect(
          validarConfirmacaoSenha('PetConnect@9', ''), 'Confirme sua senha.');
    });

    test('diferente é inválida', () {
      expect(validarConfirmacaoSenha('PetConnect@9', 'PetConnect@8'),
          'As senhas não coincidem.');
    });

    test('igual é válida', () {
      expect(validarConfirmacaoSenha('PetConnect@9', 'PetConnect@9'), isNull);
    });
  });
}
