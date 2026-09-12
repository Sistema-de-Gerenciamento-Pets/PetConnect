// Cobre a correção pós-validação física: o app deve sempre exigir login de
// novo ao ser reaberto, mesmo com uma sessão do Firebase Auth persistida.
//
// Não dá pra simular "sessão persistida" com um `User` de verdade sem uma
// biblioteca de mocks do Firebase (não usada no projeto — ver auditoria em
// docs/audit/post-device-validation-fixes.md) — `FirebaseAuth`/`User` são
// classes concretas do SDK, sem interface própria aqui. O que este teste
// prova é o mecanismo real da correção: a splash só decide o destino
// **depois** que [sessionBootstrapProvider] (o `signOut()` de bootstrap)
// termina — nunca antes. A cobertura de que o `signOut()` de fato limpa uma
// sessão persistida do Firebase é o próprio `auth_flow_test.dart` (e2e) +
// validação manual no aparelho físico (ver checklist da PR).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/features/auth/presentation/screens/splash_screen.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';

Widget _appComSplash({
  required Future<void> Function() bootstrap,
  required Stream<dynamic> authStateChanges,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const Text('Login')),
      GoRoute(path: '/home', builder: (context, state) => const Text('Home')),
    ],
  );

  return ProviderScope(
    overrides: [
      sessionBootstrapProvider.overrideWith((ref) => bootstrap()),
      authStateChangesProvider.overrideWith((ref) => authStateChanges.cast()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('SplashScreen — login sempre exigido ao reabrir o app', () {
    testWidgets(
        'não navega enquanto o bootstrap de sessão (signOut) não terminar',
        (tester) async {
      final bootstrapCompleter = Completer<void>();

      await tester.pumpWidget(_appComSplash(
        bootstrap: () => bootstrapCompleter.future,
        authStateChanges: Stream.value(null),
      ));

      // Passa do tempo mínimo de exibição da splash (2,5s) — se a splash
      // navegasse sem esperar o bootstrap, já teria saído daqui.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('PetConnect'), findsOneWidget,
          reason: 'ainda deveria estar na splash, esperando o signOut');
      expect(find.text('Login'), findsNothing);
      expect(find.text('Home'), findsNothing);

      bootstrapCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget,
          reason: 'só navega depois que o bootstrap de sessão termina');
    });

    testWidgets('com o bootstrap concluído e sem sessão, vai para o login',
        (tester) async {
      await tester.pumpWidget(_appComSplash(
        bootstrap: () async {},
        authStateChanges: Stream.value(null),
      ));

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });

    // O try/catch dentro de sessionBootstrapProvider (auth_providers.dart)
    // garante que um signOut() com falha nunca propaga como erro pra quem
    // aguarda `sessionBootstrapProvider.future` — não dá pra testar isso
    // via override (substituiria o próprio catch que se quer verificar) sem
    // uma forma de fazer o `FirebaseAuth.signOut()` real falhar, que exigiria
    // uma biblioteca de mocks do Firebase não usada no projeto.
  });
}
