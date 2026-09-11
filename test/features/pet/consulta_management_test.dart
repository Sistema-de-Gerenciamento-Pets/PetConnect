// Testa o fluxo de agendamento de consultas (RF27-RF30 — CT19/CT20 em
// docs/casos-de-teste.md) contra um FakeConsultaRepository em memória.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/domain/consulta.dart';
import 'package:pet_connect/features/pet/presentation/providers/consulta_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/consulta_form_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/consulta_list_screen.dart';

import 'fake_consulta_repository.dart';

const _petId = 'pet-1';

void main() {
  testWidgets('agenda uma consulta (CT19) e cancela (CT20)', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeRepo = FakeConsultaRepository();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
            path: '/',
            builder: (context, state) =>
                const ConsultaListScreen(petId: _petId)),
        GoRoute(
          path: '/pet/:id/consultas/nova',
          builder: (context, state) =>
              ConsultaFormScreen(petId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/pet/:id/consultas/:consultaId/editar',
          builder: (context, state) => ConsultaFormScreen(
            petId: state.pathParameters['id']!,
            consulta: state.extra as Consulta?,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consultaRepositoryProvider.overrideWithValue(fakeRepo),
          consultasProvider
              .overrideWith((ref, petId) => fakeRepo.watchConsultas(petId)),
        ],
        child:
            MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhuma consulta agendada'), findsOneWidget);

    // Agendar consulta para hoje (RF27, CT19).
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Agendar consulta'), findsOneWidget);

    final campos = find.byType(TextFormField);
    // data(0, date picker), horario(1, opcional, deixado em branco),
    // veterinario(2), motivo(3).
    await tester.tap(campos.at(0));
    await tester.pumpAndSettle();
    final hoje = DateTime.now();
    await tester.tap(find.text('${hoje.day}'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(campos.at(2), 'Dra. Ana');
    await tester.enterText(campos.at(3), 'Checape anual');

    await tester.tap(find.widgetWithText(ElevatedButton, 'SALVAR'));
    await tester.pumpAndSettle();

    // Volta para a lista (RF28), na seção "Futuras", com alerta (RF30, data
    // é hoje = dentro da janela de "próxima").
    expect(find.text('Futuras'), findsOneWidget);
    expect(find.text('Dra. Ana'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text('Concluídas'), findsNothing);
    expect(find.text('Canceladas'), findsNothing);

    // Cancelar (RF29, CT20).
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Canceladas'), findsOneWidget,
        reason: 'deveria mover para a seção de canceladas');
    expect(find.text('Futuras'), findsNothing,
        reason: 'não deveria mais contar como pendente');
  });
}
