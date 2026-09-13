// Testa o componente compartilhado de menus de configurações (RF de
// tema/menus, 2026-09-13): ícone, título, chevron, linha inteira
// clicável, sem depender só de cor pra estados destrutivo/desabilitado.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/widgets/settings_menu_tile.dart';

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('SettingsMenuTile', () {
    testWidgets('mostra ícone, título e o chevron padrão', (tester) async {
      await tester.pumpWidget(_app(SettingsMenuTile(
        icon: Icons.person_outline,
        title: 'Editar perfil',
        onTap: () {},
      )));

      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.text('Editar perfil'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('a linha inteira é clicável, não só o ícone/chevron',
        (tester) async {
      var tocou = false;
      await tester.pumpWidget(_app(SettingsMenuTile(
        icon: Icons.person_outline,
        title: 'Editar perfil',
        onTap: () => tocou = true,
      )));

      // Toca no texto do título, não no ícone nem no chevron.
      await tester.tap(find.text('Editar perfil'));
      expect(tocou, isTrue);
    });

    testWidgets('touch target tem pelo menos 48 de altura', (tester) async {
      await tester.pumpWidget(_app(SettingsMenuTile(
        icon: Icons.person_outline,
        title: 'Editar perfil',
        onTap: () {},
      )));

      final size = tester.getSize(find.byType(SettingsMenuTile));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('trailing customizado substitui o chevron', (tester) async {
      await tester.pumpWidget(_app(SettingsMenuTile(
        icon: Icons.delete_forever_outlined,
        title: 'Excluir conta',
        onTap: () {},
        trailing: const SizedBox(
            width: 16, height: 16, child: CircularProgressIndicator()),
      )));

      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('desabilitado não responde ao toque', (tester) async {
      var tocou = false;
      await tester.pumpWidget(_app(SettingsMenuTile(
        icon: Icons.delete_forever_outlined,
        title: 'Excluir conta',
        isEnabled: false,
        onTap: () => tocou = true,
      )));

      await tester.tap(find.text('Excluir conta'), warnIfMissed: false);
      expect(tocou, isFalse);
    });

    testWidgets('sem onTap, também não responde (mesmo isEnabled true)',
        (tester) async {
      await tester.pumpWidget(_app(const SettingsMenuTile(
        icon: Icons.info_outline,
        title: 'Versão do app',
      )));

      // Não deveria lançar nem quebrar ao tocar numa tile sem ação.
      await tester.tap(find.text('Versão do app'), warnIfMissed: false);
      expect(tester.takeException(), isNull);
    });

    testWidgets('avisa estado destrutivo além de só pela cor (Semantics)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(SettingsMenuTile(
        icon: Icons.delete_forever_outlined,
        title: 'Excluir conta',
        isDestructive: true,
        semanticLabel: 'Excluir conta, ação destrutiva',
        onTap: () {},
      )));

      expect(find.bySemanticsLabel('Excluir conta, ação destrutiva'),
          findsOneWidget);
      handle.dispose();
    });
  });
}
