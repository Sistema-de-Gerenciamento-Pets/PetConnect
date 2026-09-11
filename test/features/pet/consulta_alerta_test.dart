import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/domain/consulta.dart';
import 'package:pet_connect/features/pet/domain/consulta_alerta.dart';

Consulta _consulta(
    {required String data, ConsultaStatus status = ConsultaStatus.agendada}) {
  return Consulta(
      id: 'c1',
      data: data,
      veterinario: 'Dra. Ana',
      motivo: 'Checape',
      status: status);
}

void main() {
  final hoje = DateTime(2026, 1, 15);

  test('consulta agendada dentro de 7 dias está próxima (RF30)', () {
    expect(consultaEstaProxima(_consulta(data: '20/01/2026'), agora: hoje),
        isTrue);
  });

  test('consulta agendada para hoje está próxima', () {
    expect(consultaEstaProxima(_consulta(data: '15/01/2026'), agora: hoje),
        isTrue);
  });

  test('consulta agendada distante não está próxima', () {
    expect(consultaEstaProxima(_consulta(data: '01/03/2026'), agora: hoje),
        isFalse);
  });

  test('consulta já no passado não conta como próxima', () {
    expect(consultaEstaProxima(_consulta(data: '01/01/2026'), agora: hoje),
        isFalse);
  });

  test('consulta cancelada nunca está próxima, mesmo com data próxima', () {
    expect(
      consultaEstaProxima(
          _consulta(data: '16/01/2026', status: ConsultaStatus.cancelada),
          agora: hoje),
      isFalse,
    );
  });

  test('consulta já realizada nunca está próxima', () {
    expect(
      consultaEstaProxima(
          _consulta(data: '16/01/2026', status: ConsultaStatus.realizada),
          agora: hoje),
      isFalse,
    );
  });
}
