// Testes da máscara automática de telefone (seção 10/28 de
// prompt_redesign_tela_cadastro_petconnect.md).
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/auth/presentation/utils/br_phone_formatter.dart';

void main() {
  group('BrPhoneInputFormatter.formatar (formato final)', () {
    test('celular completo (11 dígitos)', () {
      expect(BrPhoneInputFormatter.formatar('19997150817'), '(19) 99715-0817');
    });

    test('fixo completo (10 dígitos)', () {
      expect(BrPhoneInputFormatter.formatar('1932321234'), '(19) 3232-1234');
    });

    test('vazio', () {
      expect(BrPhoneInputFormatter.formatar(''), '');
    });

    test('só DDD parcial (1 dígito)', () {
      expect(BrPhoneInputFormatter.formatar('1'), '(1');
    });

    test('DDD completo, sem mais nada', () {
      expect(BrPhoneInputFormatter.formatar('19'), '(19');
    });
  });

  group('BrPhoneInputFormatter (fluxo de digitação real)', () {
    late BrPhoneInputFormatter formatter;

    setUp(() => formatter = BrPhoneInputFormatter());

    TextEditingValue digitar(TextEditingValue anterior, String textoNovo) {
      final novo = TextEditingValue(
        text: textoNovo,
        selection: TextSelection.collapsed(offset: textoNovo.length),
      );
      return formatter.formatEditUpdate(anterior, novo);
    }

    test('limita a 11 dígitos mesmo colando um número maior', () {
      var valor = const TextEditingValue();
      valor = digitar(valor, '199971508171234'); // 15 dígitos colados
      expect(valor.text, '(19) 99715-0817');
    });

    test('ignora caracteres não numéricos (colagem com parênteses/espaço)', () {
      var valor = const TextEditingValue();
      valor = digitar(valor, '(19) 99715-0817');
      expect(valor.text, '(19) 99715-0817');
    });

    test('backspace remove dígitos naturalmente', () {
      var valor = const TextEditingValue();
      valor = digitar(valor, '19997150817');
      expect(valor.text, '(19) 99715-0817');

      // Simula backspace: o framework já entrega o texto sem o último
      // caractere visível ("7").
      valor = digitar(valor, '(19) 99715-081');
      expect(valor.text, '(19) 9971-5081');
    });

    test('cursor sempre fica no final após formatar', () {
      var valor = const TextEditingValue();
      valor = digitar(valor, '1999715');
      expect(valor.selection.baseOffset, valor.text.length);
    });

    test('migra de fixo para celular ao chegar no 11º dígito', () {
      var valor = const TextEditingValue();
      valor = digitar(valor, '1932321234'); // 10 dígitos, fixo
      expect(valor.text, '(19) 3232-1234');

      valor = digitar(valor, '19323212345'); // 11º dígito adicionado
      expect(valor.text, '(19) 32321-2345');
    });
  });
}
