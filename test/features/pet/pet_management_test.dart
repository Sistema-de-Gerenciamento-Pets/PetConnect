// Testa o fluxo de gestão de pets (RF10, RF11, RF13, RF14, RF15 —
// CT09/CT11 em docs/casos-de-teste.md) contra um FakePetRepository em
// memória, sem depender de um Firestore real (ver "Testes" em
// docs/arquitetura.md).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/presentation/providers/pet_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/pet_detail_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/pet_form_screen.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';
import 'package:pet_connect/features/usuario/presentation/screens/home_screen.dart';

import 'fake_pet_repository.dart';

const _tutorTeste = Usuario(
  id: 'uid-teste',
  usuarioID: 'uid-teste',
  nome: 'Tutor Teste',
  email: 'tutor@teste.com',
  telefone: '',
  dataNascimento: '',
  genero: '',
);

void main() {
  testWidgets('cria, edita e exclui um pet', (tester) async {
    // Viewport maior que o padrão (800x600) — os formulários de pet, dentro
    // de um SingleChildScrollView, têm campos suficientes para o botão
    // SALVAR ficar fora da área padrão de teste.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeRepo = FakePetRepository();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
            path: '/pet/novo',
            builder: (context, state) => const PetFormScreen()),
        GoRoute(
          path: '/pet/:id',
          builder: (context, state) =>
              PetDetailScreen(petId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/pet/:id/editar',
          builder: (context, state) => PetFormScreen(pet: state.extra as Pet?),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUsuarioProvider
              .overrideWith((ref) => Stream.value(_tutorTeste)),
          petRepositoryProvider.overrideWithValue(fakeRepo),
          petsProvider
              .overrideWith((ref) => fakeRepo.watchPets(_tutorTeste.id)),
          petProvider.overrideWith((ref, id) => fakeRepo.watchPet(id)),
        ],
        child:
            MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Home vazia (nenhum pet cadastrado ainda).
    expect(find.textContaining('Você ainda não cadastrou nenhum pet'),
        findsOneWidget);

    // Criar pet (RF10, CT09).
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Novo pet'), findsOneWidget);

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Rex'); // nome
    await tester.enterText(campos.at(1), 'Cachorro'); // espécie

    await tester.tap(find.widgetWithText(ElevatedButton, 'SALVAR'));
    await tester.pumpAndSettle();

    // Volta para a Home e o pet aparece na lista (RF11).
    expect(find.text('Meus Pets'), findsOneWidget);
    expect(find.text('Rex'), findsOneWidget);
    expect(find.textContaining('Você ainda não cadastrou'), findsNothing);

    // Abrir o perfil do pet (RF15).
    await tester.tap(find.text('Rex'));
    await tester.pumpAndSettle();

    expect(find.text('Cachorro'), findsOneWidget);

    // Editar pet (RF13).
    await tester.tap(find.widgetWithText(ElevatedButton, 'EDITAR'));
    await tester.pumpAndSettle();

    expect(find.text('Editar pet'), findsOneWidget);
    final camposEdicao = find.byType(TextFormField);
    expect(camposEdicao, findsNWidgets(6));
    await tester.enterText(camposEdicao.at(0), 'Rex Editado');

    await tester.tap(find.widgetWithText(ElevatedButton, 'SALVAR'));
    await tester.pumpAndSettle();

    expect(find.text('Rex Editado'), findsOneWidget);

    // Excluir pet, com confirmação (RF14, CT11).
    await tester.tap(find.widgetWithText(OutlinedButton, 'EXCLUIR'));
    await tester.pumpAndSettle();

    expect(find.textContaining('excluir Rex Editado'), findsOneWidget);

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Meus Pets'), findsOneWidget);
    expect(find.textContaining('Você ainda não cadastrou nenhum pet'),
        findsOneWidget);
  });
}
