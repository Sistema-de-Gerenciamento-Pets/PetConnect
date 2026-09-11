// Testa o fluxo de registro de localização/avistamento (RF31, RF32) contra
// um FakeLocalizacaoRepository em memória.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/presentation/providers/localizacao_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/localizacao_form_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/localizacao_list_screen.dart';

import 'fake_localizacao_repository.dart';

const _petId = 'pet-1';

void main() {
  testWidgets('registra um avistamento e ele aparece na lista', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeRepo = FakeLocalizacaoRepository();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
            path: '/',
            builder: (context, state) =>
                const LocalizacaoListScreen(petId: _petId)),
        GoRoute(
          path: '/pet/:id/localizacao/nova',
          builder: (context, state) =>
              LocalizacaoFormScreen(petId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localizacaoRepositoryProvider.overrideWithValue(fakeRepo),
          localizacoesProvider
              .overrideWith((ref, petId) => fakeRepo.watchLocalizacoes(petId)),
        ],
        child:
            MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.textContaining('Nenhum avistamento registrado'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Registrar avistamento'), findsOneWidget);

    // Data já vem preenchida com hoje; só descrição é obrigatória além dela.
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Visto na praça central, sem coleira',
    );
    await tester.enterText(
        find.byType(TextFormField).at(2), 'Vizinho João, (19) 99999-0000');

    await tester.tap(find.widgetWithText(ElevatedButton, 'SALVAR'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Visto na praça central'), findsOneWidget);
    expect(find.textContaining('Vizinho João'), findsOneWidget);
    expect(find.textContaining('Nenhum avistamento registrado'), findsNothing);
  });
}
