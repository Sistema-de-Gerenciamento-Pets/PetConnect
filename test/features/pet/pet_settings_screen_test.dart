// Testa a correção do bug em que "Configurações" no perfil do pet abria a
// tela de conta do tutor (prompt_correcao_configuracoes_perfil_pet.md,
// 2026-09-13). O upload de uma capa nova não é exercitado aqui: depende do
// plugin image_picker (canal de plataforma indisponível em `flutter
// test`) — mesma convenção já usada em historico_medico_test.dart. A
// remoção de uma capa já existente não depende do picker, então é testada
// de verdade.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/presentation/providers/anexo_providers.dart';
import 'package:pet_connect/features/pet/presentation/widgets/cover_position_editor.dart';
import 'package:pet_connect/features/pet/presentation/providers/pet_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/pet_settings_screen.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';

import 'fake_anexo_repository.dart';
import 'fake_pet_repository.dart';

const _tutor = Usuario(
  id: 'uid-1',
  usuarioID: 'uid-1',
  nome: 'Tutor Teste',
  email: 'tutor@teste.com',
  telefone: '',
  dataNascimento: '',
  genero: '',
);

Pet _pet({
  required String id,
  required String nome,
  String? capa,
  double? capaAlinhamentoY,
}) {
  return Pet(
    id: id,
    userId: 'uid-1',
    nome: nome,
    especie: 'Cachorro',
    raca: '',
    cor: '',
    genero: '',
    porte: '',
    peso: '',
    dataNascimento: '',
    vacinado: false,
    capa: capa,
    capaAlinhamentoY: capaAlinhamentoY,
  );
}

/// Monta o app com go_router só com o essencial pra testar as
/// configurações do pet — a rota de "editar" é uma tela-marcador, só pra
/// confirmar que a navegação preserva o pet certo.
Widget _appPara(FakePetRepository repo, String petIdInicial) {
  final router = GoRouter(
    initialLocation: '/pet/$petIdInicial/configuracoes',
    routes: [
      GoRoute(
        path: '/pet/:id/configuracoes',
        builder: (context, state) =>
            PetSettingsScreen(petId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/pet/:id/editar',
        builder: (context, state) {
          final pet = state.extra as Pet?;
          return Scaffold(body: Text('Tela Editar: ${pet?.nome}'));
        },
      ),
      GoRoute(path: '/home', builder: (context, state) => const Text('Home')),
    ],
  );

  return ProviderScope(
    overrides: [
      currentUsuarioProvider.overrideWith((ref) => Stream.value(_tutor)),
      petRepositoryProvider.overrideWithValue(repo),
      petsProvider.overrideWith((ref) => repo.watchPets(_tutor.id)),
      petProvider.overrideWith((ref, id) => repo.watchPet(id)),
      anexoRepositoryProvider.overrideWithValue(FakeAnexoRepository()),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  group('PetSettingsScreen — configurações do pet (nunca do tutor)', () {
    testWidgets('mostra "Configurações de <nome>", nunca uma tela genérica',
        (tester) async {
      final repo = FakePetRepository();
      final id = await repo.createPet(_pet(id: '', nome: 'Felícia'));

      await tester.pumpWidget(_appPara(repo, id));
      await tester.pumpAndSettle();

      expect(find.text('Configurações de Felícia'), findsOneWidget);
    });

    testWidgets('cada pet abre as próprias configurações, nunca a de outro',
        (tester) async {
      final repo = FakePetRepository();
      final idFelicia = await repo.createPet(_pet(id: '', nome: 'Felícia'));
      final idAleks = await repo.createPet(_pet(id: '', nome: 'Aleks'));

      await tester.pumpWidget(_appPara(repo, idFelicia));
      await tester.pumpAndSettle();
      expect(find.text('Configurações de Felícia'), findsOneWidget);
      expect(find.text('Configurações de Aleks'), findsNothing);

      await tester.pumpWidget(_appPara(repo, idAleks));
      await tester.pumpAndSettle();
      expect(find.text('Configurações de Aleks'), findsOneWidget);
      expect(find.text('Configurações de Felícia'), findsNothing);
    });

    testWidgets('nenhuma opção do tutor aparece aqui', (tester) async {
      final repo = FakePetRepository();
      final id = await repo.createPet(_pet(id: '', nome: 'Felícia'));

      await tester.pumpWidget(_appPara(repo, id));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta'), findsNothing);
      expect(find.text('Excluir conta'), findsNothing);
      expect(find.text('Editar perfil do tutor'), findsNothing);
    });

    testWidgets('Editar perfil abre o formulário do mesmo pet', (tester) async {
      final repo = FakePetRepository();
      final id = await repo.createPet(_pet(id: '', nome: 'Felícia'));

      await tester.pumpWidget(_appPara(repo, id));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar perfil'));
      await tester.pumpAndSettle();

      expect(find.text('Tela Editar: Felícia'), findsOneWidget);
    });

    testWidgets('Excluir perfil do pet pede confirmação e some da lista',
        (tester) async {
      final repo = FakePetRepository();
      final id = await repo.createPet(_pet(id: '', nome: 'Felícia'));

      await tester.pumpWidget(_appPara(repo, id));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Excluir perfil do pet'));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('Excluir o perfil de Felícia'), findsOneWidget);

      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect((await repo.watchPet(id).first), isNull);
    });

    testWidgets('cancelar a exclusão mantém o pet', (tester) async {
      final repo = FakePetRepository();
      final id = await repo.createPet(_pet(id: '', nome: 'Felícia'));

      await tester.pumpWidget(_appPara(repo, id));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Excluir perfil do pet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Configurações de Felícia'), findsOneWidget);
      expect((await repo.watchPet(id).first), isNotNull);
    });

    testWidgets(
        'pet sem capa mostra "Adicionar capa", sem Remover nem Ajustar posição',
        (tester) async {
      final repo = FakePetRepository();
      final id = await repo.createPet(_pet(id: '', nome: 'Felícia'));

      await tester.pumpWidget(_appPara(repo, id));
      await tester.pumpAndSettle();

      expect(find.text('Adicionar capa'), findsOneWidget);
      expect(find.text('Remover'), findsNothing);
      expect(find.text('Ajustar posição'), findsNothing);
    });

    testWidgets('Ajustar posição abre o editor e salva o alinhamento novo',
        (tester) async {
      // Sem pumpAndSettle: a capa tem URL "real" (CachedNetworkImage
      // bloqueado no ambiente de teste) — ver mesmo cuidado nos outros
      // testes de capa/avatar.
      final repo = FakePetRepository();
      final id = await repo.createPet(
          _pet(id: '', nome: 'Felícia', capa: 'https://fake.storage/capa.jpg'));

      await tester.pumpWidget(_appPara(repo, id));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Ajustar posição'), findsOneWidget);
      await tester.tap(find.text('Ajustar posição'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ajustar posição da capa'), findsOneWidget);

      await tester.drag(
          find.byType(CoverPositionEditor), const Offset(0, -100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('SALVAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final pet = await repo.watchPet(id).first;
      expect(pet!.capaAlinhamentoY, isNotNull);
      expect(pet.capaAlinhamentoY, greaterThan(0));
    });

    testWidgets('voltar do editor sem salvar não altera o alinhamento salvo',
        (tester) async {
      final repo = FakePetRepository();
      final id = await repo.createPet(_pet(
          id: '',
          nome: 'Felícia',
          capa: 'https://fake.storage/capa.jpg',
          capaAlinhamentoY: 0.4));

      await tester.pumpWidget(_appPara(repo, id));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Ajustar posição'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final pet = await repo.watchPet(id).first;
      expect(pet!.capaAlinhamentoY, 0.4);
    });

    testWidgets('Remover capa limpa o campo (sem depender do image_picker)',
        (tester) async {
      // Sem pumpAndSettle: a capa tem uma URL "real" e o
      // CachedNetworkImage tenta uma requisição de verdade, que o
      // ambiente de teste bloqueia (sempre 400) sem nunca "resolver" — ver
      // o mesmo cuidado em pet_detail_screen_test.dart.
      final repo = FakePetRepository();
      final id = await repo.createPet(
          _pet(id: '', nome: 'Felícia', capa: 'https://fake.storage/capa.jpg'));

      await tester.pumpWidget(_appPara(repo, id));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Alterar'), findsOneWidget);
      expect(find.text('Remover'), findsOneWidget);

      await tester.tap(find.text('Remover'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final pet = await repo.watchPet(id).first;
      expect(pet!.capa, anyOf(isNull, isEmpty));
      expect(find.text('Adicionar capa'), findsOneWidget);
    });
  });
}
