// Testa o fluxo de carteira de vacina (RF20-RF23 — CT16/CT17 em
// docs/casos-de-teste.md) contra um FakeVacinaRepository em memória.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/domain/vacina.dart';
import 'package:pet_connect/features/pet/presentation/providers/vacina_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/vacina_form_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/vacina_list_screen.dart';

import 'fake_vacina_repository.dart';

const _petId = 'pet-1';

/// Os campos de data são `readOnly` e só aceitam valor via `showDatePicker`
/// (não dá pra usar `tester.enterText` neles) — abre o calendário a partir
/// do campo de índice [campoIndex] e seleciona o dia [dia] do mês atual.
Future<void> _selecionarDia(
    WidgetTester tester, int campoIndex, int dia) async {
  await tester.tap(find.byType(TextFormField).at(campoIndex));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$dia'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('registra, edita e exclui uma vacina, com alerta de próxima dose',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeRepo = FakeVacinaRepository();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
            path: '/',
            builder: (context, state) => const VacinaListScreen(petId: _petId)),
        GoRoute(
          path: '/pet/:id/vacinas/nova',
          builder: (context, state) =>
              VacinaFormScreen(petId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/pet/:id/vacinas/:vacinaId/editar',
          builder: (context, state) => VacinaFormScreen(
            petId: state.pathParameters['id']!,
            vacina: state.extra as Vacina?,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vacinaRepositoryProvider.overrideWithValue(fakeRepo),
          vacinasProvider
              .overrideWith((ref, petId) => fakeRepo.watchVacinas(petId)),
        ],
        child:
            MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhuma vacina registrada'), findsOneWidget);

    // Registrar vacina (RF20, CT16): data de aplicação hoje, próxima dose
    // daqui a alguns dias — dentro da janela de alerta "próxima" (RF23).
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Registrar vacina'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'V10'); // nome

    final hoje = DateTime.now();
    await _selecionarDia(tester, 1, hoje.day); // data de aplicação
    await _selecionarDia(tester, 2,
        hoje.day); // próxima dose (mesmo dia = "hoje", já dentro da janela)

    await tester.tap(find.widgetWithText(ElevatedButton, 'SALVAR'));
    await tester.pumpAndSettle();

    // Volta para a lista (RF21) com o alerta visível (RF23).
    expect(find.text('V10'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    // Editar (RF22).
    await tester.tap(find.text('V10'));
    await tester.pumpAndSettle();

    expect(find.text('Editar vacina'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'V10 Editada');

    await tester.tap(find.widgetWithText(ElevatedButton, 'SALVAR'));
    await tester.pumpAndSettle();

    expect(find.text('V10 Editada'), findsOneWidget);

    // Excluir, com confirmação (RF22).
    await tester.tap(find.byTooltip('Excluir vacina'));
    await tester.pumpAndSettle();

    expect(find.textContaining('excluir o registro de "V10 Editada"'),
        findsOneWidget);

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhuma vacina registrada'), findsOneWidget);
  });
}
