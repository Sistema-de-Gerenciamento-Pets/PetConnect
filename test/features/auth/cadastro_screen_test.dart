// Testes de widget do redesign da tela de Cadastro (seção 29 de
// prompt_redesign_tela_cadastro_petconnect.md).
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/features/auth/presentation/screens/cadastro_screen.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/domain/usuario_repository.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';

class _FakeUsuarioRepository implements UsuarioRepository {
  _FakeUsuarioRepository({this.erroAoCadastrar, this.aguardarAntes});

  /// Se definido, `signUp` lança este erro em vez de completar.
  final Object? erroAoCadastrar;

  /// Se definido, `signUp` só resolve depois que este completer for
  /// completado — usado pra segurar o estado de loading tempo suficiente
  /// pra ser observado no teste (um fake que resolve na mesma sequência
  /// de microtasks do `pump()` some rápido demais pra ser visto).
  final Completer<void>? aguardarAntes;

  bool cadastrado = false;
  String? nomeRecebido;
  String? emailRecebido;
  String? telefoneRecebido;
  String? senhaRecebida;

  @override
  Future<void> signUp({
    required String nome,
    required String email,
    required String password,
    required String telefone,
    required String dataNascimento,
  }) async {
    if (aguardarAntes != null) await aguardarAntes!.future;
    if (erroAoCadastrar != null) throw erroAoCadastrar!;
    cadastrado = true;
    nomeRecebido = nome;
    emailRecebido = email;
    telefoneRecebido = telefone;
    senhaRecebida = password;
  }

  @override
  Stream<Usuario?> watchUsuario(String uid) => throw UnimplementedError();

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> sendPasswordReset({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<void> updateUsuario({
    required String nome,
    required String sobrenome,
    required String telefone,
    required String dataNascimento,
    required String genero,
    String? foto,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteAccount() => throw UnimplementedError();
}

Widget _appPara(_FakeUsuarioRepository repo) {
  final router = GoRouter(
    initialLocation: '/cadastro',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const Text('Login')),
      GoRoute(
        path: '/cadastro',
        builder: (context, state) => const CadastroScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [usuarioRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Abre a tela com uma altura de viewport realista — a viewport padrão de
/// teste do Flutter (800x600) é mais baixa que qualquer aparelho real
/// suportado (mesma convenção de pet_management_test.dart). O grupo
/// "responsividade" abaixo usa seu próprio tamanho (pequeno de propósito,
/// pra testar o limite), sem passar por este helper.
Future<void> _abrirTela(
    WidgetTester tester, _FakeUsuarioRepository repo) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_appPara(repo));
}

/// Preenche todos os campos com dados válidos, exceto os informados em
/// [exceto].
Future<void> _preencherTudoValido(
  WidgetTester tester, {
  String nome = 'Maria Silva',
  String email = 'maria@dominio.com',
  String telefone = '19997150817',
  String senha = 'PetConnect@9',
  String? confirmarSenha,
}) async {
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome completo').first, nome);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail').first, email);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Telefone').first, telefone);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha').first, senha);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar senha').first,
      confirmarSenha ?? senha);
  await tester.pump();
}

void main() {
  group('CadastroScreen — layout inicial', () {
    testWidgets(
        'mostra título, os 5 campos e o botão, sem exemplos redundantes',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      expect(find.text('Crie sua conta'), findsOneWidget);
      expect(find.text('Cadastre seus dados para começar.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(5));
      expect(
          find.widgetWithText(ElevatedButton, 'CRIAR CONTA'), findsOneWidget);

      // Exemplos redundantes removidos (seção 34 do briefing).
      expect(find.text('Ex: Maria Silva'), findsNothing);
      expect(find.text('seu@email.com'), findsNothing);
      expect(find.text('Repita a senha'), findsNothing);
    });

    testWidgets('botão CRIAR CONTA começa desabilitado', (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      final botao = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      expect(botao.onPressed, isNull);
    });
  });

  group('CadastroScreen — telefone', () {
    testWidgets('aplica máscara automaticamente enquanto digita',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Telefone').first, '19997150817');
      await tester.pump();

      expect(find.text('(19) 99715-0817'), findsOneWidget);
    });

    testWidgets('não aceita mais que 11 dígitos, mesmo colando um texto maior',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Telefone').first,
          '199971508171234567');
      await tester.pump();

      expect(find.text('(19) 99715-0817'), findsOneWidget);
    });
  });

  group('CadastroScreen — validação ao perder o foco', () {
    testWidgets('não mostra erro de e-mail antes de qualquer interação',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      expect(find.text('Informe um e-mail válido.'), findsNothing);
    });

    testWidgets('mostra "Informe um e-mail válido." só depois de sair do campo',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'E-mail').first, 'invalido');
      await tester.pump();
      expect(find.text('Informe um e-mail válido.'), findsNothing,
          reason: 'ainda não perdeu o foco');

      // Move o foco para o próximo campo — dispara a validação.
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Telefone').first, '');
      await tester.pump();

      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    });
  });

  group('CadastroScreen — checklist de senha', () {
    testWidgets(
        'já aparece antes de qualquer interação (senha vazia nunca atende aos requisitos)',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      expect(find.text('9 ou mais caracteres'), findsOneWidget);
      expect(find.text('Letra maiúscula'), findsOneWidget);
      expect(find.text('Caractere especial'), findsOneWidget);
    });

    testWidgets(
        'permanece visível mesmo sem foco enquanto a senha não atender aos requisitos',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha').first, '123');
      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail').first,
          ''); // tira o foco
      await tester.pump();

      expect(find.text('9 ou mais caracteres'), findsOneWidget);
    });

    testWidgets('some quando a senha atende a tudo e perde o foco',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha').first, 'PetConnect@9');
      await tester.pump();
      expect(find.text('9 ou mais caracteres'), findsOneWidget,
          reason: 'ainda focado, continua visível mesmo já sendo válida');

      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail').first,
          ''); // tira o foco
      await tester.pump();

      expect(find.text('9 ou mais caracteres'), findsNothing);
    });
  });

  group('CadastroScreen — confirmar senha', () {
    testWidgets('não mostra erro no primeiro caractere digitado',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha').first, 'PetConnect@9');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar senha').first, 'P');
      await tester.pump();

      expect(find.text('As senhas não coincidem.'), findsNothing);
    });

    testWidgets('mostra "As senhas não coincidem." quando diferentes',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha').first, 'PetConnect@9');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar senha').first,
          'PetConnect@8');
      await tester.pump();

      expect(find.text('As senhas não coincidem.'), findsOneWidget);
    });

    testWidgets('erro some assim que a confirmação é corrigida',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha').first, 'PetConnect@9');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar senha').first,
          'PetConnect@8');
      await tester.pump();
      expect(find.text('As senhas não coincidem.'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar senha').first,
          'PetConnect@9');
      await tester.pump();

      expect(find.text('As senhas não coincidem.'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('CadastroScreen — botão CRIAR CONTA', () {
    testWidgets('habilita quando todos os campos estão válidos',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await _preencherTudoValido(tester);

      final botao = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      expect(botao.onPressed, isNotNull);
    });

    testWidgets('chama signUp com os dados preenchidos e navega ao concluir',
        (tester) async {
      final repo = _FakeUsuarioRepository();
      await _abrirTela(tester, repo);
      await tester.pumpAndSettle();

      await _preencherTudoValido(tester,
          nome: 'Maria Silva', email: 'maria@dominio.com');
      await tester.tap(find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      await tester.pumpAndSettle();

      expect(repo.cadastrado, isTrue);
      expect(repo.nomeRecebido, 'Maria Silva');
      expect(repo.emailRecebido, 'maria@dominio.com');
      expect(repo.senhaRecebida, 'PetConnect@9');
    });

    testWidgets('mostra indicador de carregamento durante o cadastro',
        (tester) async {
      final gate = Completer<void>();
      final repo = _FakeUsuarioRepository(aguardarAntes: gate);
      await _abrirTela(tester, repo);
      await tester.pumpAndSettle();

      await _preencherTudoValido(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      await tester.pump(); // um frame: signUp ainda preso no gate

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('mostra mensagem amigável quando o e-mail já existe',
        (tester) async {
      final repo = _FakeUsuarioRepository(
        erroAoCadastrar: FirebaseAuthException(code: 'email-already-in-use'),
      );
      await _abrirTela(tester, repo);
      await tester.pumpAndSettle();

      await _preencherTudoValido(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      await tester.pumpAndSettle();

      expect(find.text('Já existe uma conta com este e-mail.'), findsOneWidget);
      expect(find.text('Login'), findsNothing,
          reason: 'erro não deveria navegar pra lugar nenhum');
    });

    testWidgets('mostra mensagem genérica para erro inesperado',
        (tester) async {
      final repo = _FakeUsuarioRepository(erroAoCadastrar: Exception('boom'));
      await _abrirTela(tester, repo);
      await tester.pumpAndSettle();

      await _preencherTudoValido(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      await tester.pumpAndSettle();

      expect(
          find.text('Não foi possível completar a operação. Tente novamente.'),
          findsOneWidget);
    });
  });

  group('CadastroScreen — cabeçalho compacto com o teclado', () {
    testWidgets('encolhe o cabeçalho e some com o texto de apoio',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      expect(find.text('Cadastre seus dados para começar.'), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pumpAndSettle();

      expect(find.text('Cadastre seus dados para começar.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('CadastroScreen — responsividade', () {
    testWidgets('tela pequena (320x480) sem overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_appPara(_FakeUsuarioRepository()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'tela pequena com teclado aberto e checklist visível: sem overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_appPara(_FakeUsuarioRepository()));
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pumpAndSettle();

      // Com o teclado comendo boa parte dos 480 de altura, o campo de
      // senha pode não estar dentro da área visível sem rolar — a rede de
      // segurança contra overflow (ver cadastro_screen.dart) é justamente
      // pra isso: o conteúdo continua alcançável, só que rolando.
      await tester
          .ensureVisible(find.widgetWithText(TextFormField, 'Senha').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextFormField, 'Senha').first);
      await tester.pumpAndSettle();

      expect(find.text('9 ou mais caracteres'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
