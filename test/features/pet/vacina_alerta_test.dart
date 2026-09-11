import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/domain/vacina.dart';
import 'package:pet_connect/features/pet/domain/vacina_alerta.dart';

Vacina _vacina({String? proximaDose}) {
  return Vacina(
      id: 'v1',
      nome: 'V10',
      dataAplicacao: '01/01/2024',
      proximaDose: proximaDose);
}

void main() {
  final hoje = DateTime(2026, 1, 15);

  test('sem próxima dose registrada não gera alerta', () {
    expect(calcularAlerta(_vacina(), agora: hoje), VacinaAlerta.nenhum);
  });

  test('próxima dose vencida (RF23, CT17)', () {
    final vacina = _vacina(proximaDose: '01/01/2026');
    expect(calcularAlerta(vacina, agora: hoje), VacinaAlerta.vencida);
  });

  test('próxima dose dentro de 30 dias', () {
    final vacina = _vacina(proximaDose: '01/02/2026');
    expect(calcularAlerta(vacina, agora: hoje), VacinaAlerta.proxima);
  });

  test('próxima dose distante não gera alerta', () {
    final vacina = _vacina(proximaDose: '01/08/2026');
    expect(calcularAlerta(vacina, agora: hoje), VacinaAlerta.nenhum);
  });
}
