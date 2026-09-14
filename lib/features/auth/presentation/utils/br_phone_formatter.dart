import 'package:flutter/services.dart';

/// Máscara automática de telefone brasileiro: `(DD) XXXX-XXXX` (fixo, 10
/// dígitos) ou `(DD) 9XXXX-XXXX` (celular, 11) — migra sozinha para o
/// formato de celular assim que o 11º dígito é digitado, sem exigir nada
/// do usuário além de números (seção 10 do briefing).
///
/// O hífen fica ancorado nos últimos 4 dígitos (não numa posição fixa da
/// esquerda): é assim que não dá pra saber, enquanto o usuário ainda está
/// digitando, se o número final terá 10 ou 11 dígitos — mesma técnica
/// usada por apps bancários. Isso significa que a posição do hífen "pula"
/// enquanto o meio do número ainda está incompleto; o resultado final,
/// com o número completo, sempre fica correto.
///
/// Limitações aceitas (comuns a esse tipo de máscara "recalcula do zero a
/// cada edição"): o cursor sempre volta para o final do texto após cada
/// edição (não preserva posição ao editar no meio do número), e apagar
/// exatamente um caractere de máscara (o "-" ou ")") não remove nenhum
/// dígito por si só — o usuário só precisa apertar backspace mais uma vez.
class BrPhoneInputFormatter extends TextInputFormatter {
  static const _maxDigitos = 11;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digitos = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.length > _maxDigitos) {
      digitos = digitos.substring(0, _maxDigitos);
    }

    final formatado = formatar(digitos);
    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }

  /// Exposto como `static` para ser usado fora do fluxo de digitação — por
  /// exemplo, ao preencher o campo programaticamente num teste.
  static String formatar(String digitos) {
    if (digitos.isEmpty) return '';

    final ddd = digitos.substring(0, digitos.length < 2 ? digitos.length : 2);
    if (digitos.length <= 2) return '($ddd';

    final resto = digitos.substring(2);
    if (resto.length <= 4) return '($ddd) $resto';

    final primeiraParte = resto.substring(0, resto.length - 4);
    final ultimosQuatro = resto.substring(resto.length - 4);
    return '($ddd) $primeiraParte-$ultimosQuatro';
  }
}
