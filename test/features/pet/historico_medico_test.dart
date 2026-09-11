// Testa o fluxo de histórico médico (RF24-RF26 — CT18 em
// docs/casos-de-teste.md) contra um FakeHistoricoMedicoRepository em
// memória. O upload de anexos não é exercitado aqui: depende do plugin
// image_picker (canal de plataforma indisponível em `flutter test`) — ver
// FakeAnexoRepository.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/domain/historico_medico.dart';
import 'package:pet_connect/features/pet/presentation/providers/anexo_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/historico_medico_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/historico_form_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/historico_list_screen.dart';

import 'fake_anexo_repository.dart';
import 'fake_historico_medico_repository.dart';

const _petId = 'pet-1';

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
  testWidgets('registra, edita e exclui uma entrada de histórico médico',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeHistoricoRepo = FakeHistoricoMedicoRepository();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
            path: '/',
            builder: (context, state) =>
                const HistoricoListScreen(petId: _petId)),
        GoRoute(
          path: '/pet/:id/historico/novo',
          builder: (context, state) =>
              HistoricoFormScreen(petId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/pet/:id/historico/:historicoId/editar',
          builder: (context, state) => HistoricoFormScreen(
            petId: state.pathParameters['id']!,
            historico: state.extra as HistoricoMedico?,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historicoMedicoRepositoryProvider
              .overrideWithValue(fakeHistoricoRepo),
          anexoRepositoryProvider.overrideWithValue(FakeAnexoRepository()),
          historicoMedicoProvider.overrideWith(
              (ref, petId) => fakeHistoricoRepo.watchHistorico(petId)),
        ],
        child:
            MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhum registro ainda'), findsOneWidget);

    // Registrar entrada (RF24, CT18).
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Novo registro'), findsOneWidget);

    final hoje = DateTime.now();
    await _selecionarDia(tester, 0, hoje.day); // data
    await tester.enterText(find.byType(TextFormField).at(1),
        'Consulta de rotina, exame de sangue normal.');
    await tester.enterText(find.byType(TextFormField).at(2), 'Dra. Ana');

    await tester.tap(find.widgetWithText(ElevatedButton, 'SALVAR'));
    await tester.pumpAndSettle();

    // Volta para a lista (RF25), ordenada cronologicamente.
    expect(find.textContaining('Consulta de rotina'), findsOneWidget);

    // Editar (RF26).
    await tester.tap(find.textContaining('Consulta de rotina'));
    await tester.pumpAndSettle();

    expect(find.text('Editar histórico'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Consulta de retorno, tudo normal.');

    await tester.tap(find.widgetWithText(ElevatedButton, 'SALVAR'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Consulta de retorno'), findsOneWidget);

    // Excluir, com confirmação (RF26).
    await tester.tap(find.byTooltip('Excluir registro'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir registro'), findsOneWidget);

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhum registro ainda'), findsOneWidget);
  });
}
