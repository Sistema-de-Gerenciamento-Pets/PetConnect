// Testa a confirmação antes de cancelar uma consulta (correção de
// 2026-09-14 — ver docs/features/confirmacao-cancelamento-consulta.md):
// antes, tocar em "Cancelar" cancelava a consulta na hora, sem chance de
// voltar atrás.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/domain/consulta.dart';
import 'package:pet_connect/features/pet/presentation/providers/consulta_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/consulta_list_screen.dart';

import 'fake_consulta_repository.dart';

const _petId = 'pet-1';

Consulta _consultaFutura() {
  final daqui10dias = DateTime.now().add(const Duration(days: 10));
  final data =
      '${daqui10dias.day.toString().padLeft(2, '0')}/${daqui10dias.month.toString().padLeft(2, '0')}/${daqui10dias.year}';
  return Consulta(
    id: '',
    data: data,
    veterinario: 'Dra. Ana',
    motivo: 'Checape anual',
    status: ConsultaStatus.agendada,
  );
}

Widget _appPara(FakeConsultaRepository repo) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ConsultaListScreen(petId: _petId),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      consultaRepositoryProvider.overrideWithValue(repo),
      consultasProvider
          .overrideWith((ref, petId) => repo.watchConsultas(petId)),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  group('ConsultaTile — confirmação ao cancelar', () {
    testWidgets('tocar em "Cancelar" não cancela sozinho — abre um diálogo',
        (tester) async {
      final repo = FakeConsultaRepository();
      await repo.createConsulta(_petId, _consultaFutura());

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelar consulta'), findsOneWidget);
      expect(find.textContaining('Dra. Ana'), findsWidgets);
      final consulta = (await repo.watchConsultas(_petId).first).single;
      expect(consulta.status, ConsultaStatus.agendada,
          reason: 'só abriu o diálogo, ainda não cancelou nada');
    });

    testWidgets('"Voltar" fecha o diálogo sem cancelar', (tester) async {
      final repo = FakeConsultaRepository();
      await repo.createConsulta(_petId, _consultaFutura());

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelar consulta'), findsNothing);
      expect(find.text('Futuras'), findsOneWidget);
      final consulta = (await repo.watchConsultas(_petId).first).single;
      expect(consulta.status, ConsultaStatus.agendada);
    });

    testWidgets('"Sim, cancelar" confirma e move para Canceladas',
        (tester) async {
      final repo = FakeConsultaRepository();
      await repo.createConsulta(_petId, _consultaFutura());

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sim, cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Canceladas'), findsOneWidget);
      expect(find.text('Futuras'), findsNothing);
      final consulta = (await repo.watchConsultas(_petId).first).single;
      expect(consulta.status, ConsultaStatus.cancelada);
    });

    testWidgets(
        'mostra indicador de carregamento e evita duplo cancelamento durante a chamada',
        (tester) async {
      final gate = Completer<void>();
      final repo = FakeConsultaRepository(aguardarAntesDeAtualizar: gate);
      await repo.createConsulta(_petId, _consultaFutura());

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sim, cancelar'));
      await tester.pump(); // um frame: updateConsulta ainda presa no gate

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Segundo toque enquanto ainda carrega não deveria fazer nada (o
      // botão fica desabilitado — onPressed nulo).
      final botaoCancelar = tester.widget<TextButton>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(TextButton),
        ),
      );
      expect(botaoCancelar.onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Canceladas'), findsOneWidget);
    });

    testWidgets(
        'erro ao cancelar mostra aviso e mantém a consulta como agendada',
        (tester) async {
      final repo = FakeConsultaRepository(
          erroAoAtualizar: Exception('falha de rede simulada'));
      await repo.createConsulta(_petId, _consultaFutura());

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sim, cancelar'));
      await tester.pumpAndSettle();

      expect(
          find.text('Não foi possível cancelar a consulta. Tente novamente.'),
          findsOneWidget);
      expect(find.text('Futuras'), findsOneWidget,
          reason: 'erro não deveria ter cancelado a consulta');
      final consulta = (await repo.watchConsultas(_petId).first).single;
      expect(consulta.status, ConsultaStatus.agendada);
    });
  });
}
