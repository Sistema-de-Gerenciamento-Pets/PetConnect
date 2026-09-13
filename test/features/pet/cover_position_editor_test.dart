// Testa o editor de posição da capa (arrastar pra escolher a área visível,
// em vez do recorte automático — pedido do tutor após validar a PR de
// configurações do pet no aparelho físico).
import 'package:flutter/material.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/presentation/widgets/cover_position_editor.dart';
import 'package:pet_connect/features/pet/presentation/widgets/pet_cover_image.dart';

const _capaUrl = 'https://example.com/capa.jpg';

/// Sem pumpAndSettle: a capa tem uma URL "real" e o CachedNetworkImage
/// tenta uma requisição de verdade, que o ambiente de teste bloqueia
/// (sempre 400) sem nunca "resolver" — mesmo cuidado já usado nos outros
/// testes de capa/avatar.
Future<void> _pumpEstavel(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('CoverPositionEditor', () {
    testWidgets('abre centralizado por padrão e mostra a prévia da capa',
        (tester) async {
      double? resultado;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              resultado =
                  await CoverPositionEditor.open(context, imageUrl: _capaUrl);
            },
            child: const Text('abrir'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await _pumpEstavel(tester);

      expect(find.text('Ajustar posição da capa'), findsOneWidget);
      final cover = tester.widget<PetCoverImage>(find.byType(PetCoverImage));
      expect(cover.alignmentY, 0);
      expect(resultado, isNull, reason: 'ainda não fechou o editor');
    });

    testWidgets('arrastar move o alinhamento e SALVAR retorna o valor novo',
        (tester) async {
      double? resultado;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              resultado =
                  await CoverPositionEditor.open(context, imageUrl: _capaUrl);
            },
            child: const Text('abrir'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await _pumpEstavel(tester);

      // Arrasta pra cima (delta negativo em dy) — deve mover o
      // alinhamento pra um valor positivo (mostra mais da parte de baixo
      // da foto).
      await tester.drag(
          find.byType(CoverPositionEditor), const Offset(0, -100));
      await _pumpEstavel(tester);

      final cover = tester.widget<PetCoverImage>(find.byType(PetCoverImage));
      expect(cover.alignmentY, greaterThan(0));

      await tester.tap(find.text('SALVAR'));
      await _pumpEstavel(tester);

      expect(resultado, isNotNull);
      expect(resultado, cover.alignmentY);
    });

    testWidgets('respeita os limites -1.0 e 1.0 mesmo com arrasto grande',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const CoverPositionEditor(imageUrl: _capaUrl),
      ));
      await _pumpEstavel(tester);

      await tester.drag(
          find.byType(CoverPositionEditor), const Offset(0, -100000));
      await _pumpEstavel(tester);

      var cover = tester.widget<PetCoverImage>(find.byType(PetCoverImage));
      expect(cover.alignmentY, 1.0);

      await tester.drag(
          find.byType(CoverPositionEditor), const Offset(0, 100000));
      await _pumpEstavel(tester);

      cover = tester.widget<PetCoverImage>(find.byType(PetCoverImage));
      expect(cover.alignmentY, -1.0);
    });

    testWidgets('voltar sem tocar em SALVAR retorna null (não altera nada)',
        (tester) async {
      double? resultado = -99; // sentinela pra distinguir de "nunca setado"
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              resultado = await CoverPositionEditor.open(context,
                  imageUrl: _capaUrl, alinhamentoInicial: 0.3);
            },
            child: const Text('abrir'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await _pumpEstavel(tester);

      await tester.pageBack();
      await _pumpEstavel(tester);

      expect(resultado, isNull);
    });

    testWidgets('abre já na posição inicial recebida', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const CoverPositionEditor(
            imageUrl: _capaUrl, alinhamentoInicial: -0.6),
      ));
      await _pumpEstavel(tester);

      final cover = tester.widget<PetCoverImage>(find.byType(PetCoverImage));
      expect(cover.alignmentY, -0.6);
    });
  });
}
