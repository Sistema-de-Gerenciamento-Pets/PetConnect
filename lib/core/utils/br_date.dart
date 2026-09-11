import 'package:intl/intl.dart';

/// Formato de data usado em todo o banco existente (`dd/MM/yyyy`), ver
/// "Convenção de datas" em docs/modelo-dados-firestore.md.
final _formatter = DateFormat('dd/MM/yyyy');

DateTime? parseBrDate(String value) {
  if (value.isEmpty) return null;
  try {
    return _formatter.parseStrict(value);
  } catch (_) {
    return null;
  }
}

String formatBrDate(DateTime date) => _formatter.format(date);

/// `dd/MM/yyyy` → `yyyy-MM-dd` (ISO 8601, usado nos payloads da API).
/// Devolve a própria string se não for uma data válida.
String brToIso(String br) {
  final d = parseBrDate(br);
  if (d == null) return br;
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// `yyyy-MM-dd` (ou ISO completo) → `dd/MM/yyyy`. Vazio/nulo → `''`.
String isoToBr(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  return d == null ? '' : formatBrDate(d);
}

/// Idade em anos completos a partir de uma data de nascimento `dd/MM/yyyy`,
/// ou `null` se a data estiver vazia/inválida.
int? idadeEmAnos(String dataNascimento, {DateTime? agora}) {
  final nascimento = parseBrDate(dataNascimento);
  if (nascimento == null) return null;

  final hoje = agora ?? DateTime.now();
  var idade = hoje.year - nascimento.year;
  final aniversarioJaPassouEsteAno =
      hoje.month > nascimento.month || (hoje.month == nascimento.month && hoje.day >= nascimento.day);
  if (!aniversarioJaPassouEsteAno) idade--;
  return idade < 0 ? null : idade;
}
