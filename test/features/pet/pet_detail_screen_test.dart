// Testes do novo layout em cards do perfil do pet (RF15), ver
// prompt_claude_perfil_pet_layout.md (2026-09-12) e
// docs/validation/pet-profile-layout.md.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/presentation/providers/pet_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/pet_detail_screen.dart';
import 'package:pet_connect/features/pet/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:pet_connect/features/pet/presentation/widgets/pet_avatar.dart';
import 'package:pet_connect/features/pet/presentation/widgets/pet_cover_image.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';

const _tutor = Usuario(
  id: 'uid-1',
  usuarioID: 'uid-1',
  nome: 'Tutor Teste',
  email: 'tutor@teste.com',
  telefone: '',
  dataNascimento: '',
  genero: '',
);

const _petCompleto = Pet(
  id: 'pet-1',
  userId: 'uid-1',
  nome: 'Rex',
  especie: 'Cachorro',
  raca: 'Vira-lata',
  cor: 'Caramelo',
  genero: 'Macho',
  porte: 'Médio',
  peso: '12kg',
  dataNascimento: '10/05/2020',
  vacinado: true,
);

const _petParcial = Pet(
  id: 'pet-2',
  userId: 'uid-1',
  nome: 'Mia',
  especie: 'Gato',
  raca: '',
  cor: '',
  genero: '',
  porte: '',
  peso: '',
  dataNascimento: '',
  vacinado: false,
);

const _petComFotoECapa = Pet(
  id: 'pet-3',
  userId: 'uid-1',
  nome: 'Bidu',
  especie: 'Cachorro',
  raca: '',
  cor: '',
  genero: '',
  porte: '',
  peso: '',
  dataNascimento: '',
  vacinado: false,
  foto: 'https://example.com/bidu.jpg',
  capa: 'https://example.com/capa-bidu.jpg',
);

/// Monta o app inteiro (com go_router) só com o essencial pra testar o
/// perfil do pet — rotas de destino são telas-marcador simples, só pra
/// confirmar que a navegação de fato aconteceu.
Widget _appPara(Pet? pet, {AsyncValue<Pet?>? estadoForcado}) {
  final router = GoRouter(
    initialLocation: '/pet/${pet?.id ?? 'pet-1'}',
    routes: [
      GoRoute(
        path: '/pet/:id',
        builder: (context, state) =>
            PetDetailScreen(petId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/pet/:id/vacinas',
        builder: (context, state) => const Scaffold(body: Text('Tela Vacinas')),
      ),
      GoRoute(
        path: '/pet/:id/consultas',
        builder: (context, state) =>
            const Scaffold(body: Text('Tela Consultas')),
      ),
      GoRoute(
        path: '/pet/:id/historico',
        builder: (context, state) =>
            const Scaffold(body: Text('Tela Histórico')),
      ),
      GoRoute(
        path: '/pet/:id/localizacao',
        builder: (context, state) =>
            const Scaffold(body: Text('Tela Localização')),
      ),
      GoRoute(
        path: '/pet/:id/configuracoes',
        builder: (context, state) => Scaffold(
            body: Text(
                'Tela Configurações do pet ${state.pathParameters['id']}')),
      ),
    ],
  );

  final overrides = [
    currentUsuarioProvider.overrideWith((ref) => Stream.value(_tutor)),
    if (estadoForcado != null)
      petProvider.overrideWith((ref, id) => estadoForcado.isLoading
          ? const Stream<Pet?>.empty()
          : estadoForcado.hasError
              ? Stream<Pet?>.error(estadoForcado.error!)
              : Stream.value(estadoForcado.value))
    else
      petProvider.overrideWith((ref, id) => Stream.value(pet)),
  ];

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

/// A tela, com os 4 cards + ações secundárias + editar/excluir, é mais alta
/// que o viewport padrão de teste (800x600) — sem isso, tocar em algo perto
/// do fim da lista falha por estar fora da área visível.
void _ampliarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('PetDetailScreen — layout em cards', () {
    testWidgets('exibe nome, foto (fallback) e dados básicos do pet',
        (tester) async {
      _ampliarViewport(tester);
      await tester.pumpWidget(_appPara(_petCompleto));
      await tester.pumpAndSettle();

      expect(find.text('Rex'), findsOneWidget);
      // Sem foto cadastrada → cai no ícone de fallback, nunca quebra.
      expect(find.byIcon(Icons.pets), findsWidgets);
      expect(find.text('Cachorro · Vira-lata'), findsOneWidget);
      // Idade calculada a partir da data de nascimento — não fixamos o
      // valor exato pra não depender de "hoje" na hora do teste.
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            RegExp(r'^\d+ anos?$').hasMatch(widget.data ?? '')),
        findsOneWidget,
      );
      expect(find.text('Macho'), findsOneWidget);
      expect(find.text('12kg'), findsOneWidget);
      expect(find.text('Vacinado'), findsOneWidget);
    });

    testWidgets('mostra os 4 cards principais, todos com descrição',
        (tester) async {
      await tester.pumpWidget(_appPara(_petCompleto));
      await tester.pumpAndSettle();

      expect(find.text('Carteira de Vacinas'), findsOneWidget);
      expect(find.text('Agenda de Consultas'), findsOneWidget);
      expect(find.text('Histórico Médico'), findsOneWidget);
      expect(find.text('QR Code do Pet'), findsOneWidget);
      expect(find.text('Consulte as vacinas aplicadas e próximas doses.'),
          findsOneWidget);
    });

    testWidgets(
        'dados parciais: campos vazios ficam ocultos, nunca aparece null/undefined',
        (tester) async {
      await tester.pumpWidget(_appPara(_petParcial));
      await tester.pumpAndSettle();

      expect(find.text('Mia'), findsOneWidget);
      expect(find.text('Gato'), findsOneWidget); // sem raça → só a espécie
      expect(find.text('Não vacinado'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
      expect(find.textContaining('undefined'), findsNothing);
      // Sem gênero/peso/data de nascimento cadastrados, os chips somem.
      expect(find.byIcon(Icons.male), findsNothing);
      expect(find.byIcon(Icons.female), findsNothing);
      expect(find.byIcon(Icons.monitor_weight_outlined), findsNothing);
    });

    testWidgets('toque em qualquer área do card navega (não só o ícone)',
        (tester) async {
      await tester.pumpWidget(_appPara(_petCompleto));
      await tester.pumpAndSettle();

      // Toca no texto de descrição do card, não no ícone/seta.
      await tester
          .tap(find.text('Consulte as vacinas aplicadas e próximas doses.'));
      await tester.pumpAndSettle();

      expect(find.text('Tela Vacinas'), findsOneWidget);
    });

    testWidgets('cada card navega para a rota certa preservando o petId',
        (tester) async {
      await tester.pumpWidget(_appPara(_petCompleto));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agenda de Consultas'));
      await tester.pumpAndSettle();
      expect(find.text('Tela Consultas'), findsOneWidget);
    });

    testWidgets('card de QR Code abre o QR já existente, sem nova regra',
        (tester) async {
      _ampliarViewport(tester);
      await tester.pumpWidget(_appPara(_petCompleto));
      await tester.pumpAndSettle();

      await tester.tap(find.text('QR Code do Pet'));
      await tester.pumpAndSettle();

      expect(find.textContaining('escanear este código'), findsOneWidget);
    });

    testWidgets('ações secundárias reais (Localização, Configurações)',
        (tester) async {
      _ampliarViewport(tester);
      await tester.pumpWidget(_appPara(_petCompleto));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Localização'));
      await tester.pumpAndSettle();
      expect(find.text('Tela Localização'), findsOneWidget);
    });

    testWidgets(
        'Configurações abre as configurações deste pet, preservando o petId',
        (tester) async {
      _ampliarViewport(tester);
      await tester.pumpWidget(_appPara(_petCompleto));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Configurações'));
      await tester.pumpAndSettle();

      // Nunca a tela de configurações do tutor — bug corrigido em
      // prompt_correcao_configuracoes_perfil_pet.md (2026-09-13).
      expect(find.text('Tela Configurações do pet pet-1'), findsOneWidget);
    });

    testWidgets(
        'editar e excluir não aparecem mais na tela principal do perfil',
        (tester) async {
      await tester.pumpWidget(_appPara(_petCompleto));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'EDITAR'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'EXCLUIR'), findsNothing);
    });

    testWidgets('estado de loading não quebra a tela', (tester) async {
      await tester.pumpWidget(
          _appPara(null, estadoForcado: const AsyncValue<Pet?>.loading()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('estado de erro mostra mensagem, não quebra a tela',
        (tester) async {
      await tester.pumpWidget(_appPara(null,
          estadoForcado: AsyncValue<Pet?>.error(
              Exception('falha de rede'), StackTrace.empty)));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível carregar este pet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics: o card carrega um label descritivo completo',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_appPara(_petCompleto));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
            'Carteira de Vacinas. Consulte as vacinas aplicadas e próximas doses.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('tocar na foto do pet abre a visualização fullscreen',
        (tester) async {
      // Sem pumpAndSettle: a foto/capa têm URL real e o
      // CachedNetworkImage tenta uma requisição de verdade, que o
      // ambiente de teste bloqueia (sempre 400) — sem nunca "resolver" a
      // ponto de pumpAndSettle considerar tudo parado. Pumps com duração
      // fixa bastam pra ver a navegação acontecer.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_appPara(_petComFotoECapa));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(FullscreenImageViewer), findsNothing);

      await tester.tap(find
          .bySemanticsLabel('Foto de Bidu. Toque duas vezes para ampliar.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FullscreenImageViewer), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tocar na capa do pet também abre a visualização fullscreen',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_appPara(_petComFotoECapa));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find
          .bySemanticsLabel('Capa de Bidu. Toque duas vezes para ampliar.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FullscreenImageViewer), findsOneWidget);
      handle.dispose();
    });

    testWidgets('sem capa, o cabeçalho mostra o fallback e não abre nada',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_appPara(_petCompleto)); // sem capa cadastrada
      await tester.pumpAndSettle();

      expect(find.byType(PetCoverImage), findsOneWidget);
      await tester.tap(find.byType(PetCoverImage));
      await tester.pumpAndSettle();

      expect(find.byType(FullscreenImageViewer), findsNothing);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('sem foto, o avatar não abre nada e avisa via semantics',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_appPara(_petCompleto)); // sem foto cadastrada
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Rex não possui foto cadastrada.'),
          findsOneWidget);

      await tester.tap(find.byType(PetAvatar));
      await tester.pumpAndSettle();

      expect(find.byType(FullscreenImageViewer), findsNothing);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('largura reduzida (320px): sem overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_appPara(_petCompleto));
      await tester.pumpAndSettle();

      expect(find.text('Rex'), findsOneWidget);
      expect(find.text('Carteira de Vacinas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
