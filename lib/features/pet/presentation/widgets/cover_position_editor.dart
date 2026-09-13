import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import 'pet_cover_image.dart';

/// Deixa o tutor arrastar a capa pra escolher a área que aparece no perfil,
/// em vez do recorte automático centralizado (pedido explícito após a
/// validação física da PR de configurações do pet).
///
/// A prévia usa o mesmo [PetCoverImage] com a mesma altura da produção
/// (140) — o que se vê aqui é exatamente o que aparece no perfil depois de
/// salvar (WYSIWYG). Como a foto sempre usa `BoxFit.cover`, qualquer
/// alinhamento entre -1.0 e 1.0 é válido e nunca deixa área vazia — só
/// muda qual parte da imagem fica visível.
class CoverPositionEditor extends StatefulWidget {
  const CoverPositionEditor({
    super.key,
    required this.imageUrl,
    this.alinhamentoInicial = 0,
  });

  final String imageUrl;
  final double alinhamentoInicial;

  /// Abre o editor e retorna o novo alinhamento (-1.0 a 1.0) se o tutor
  /// salvar, ou `null` se voltar sem salvar.
  static Future<double?> open(
    BuildContext context, {
    required String imageUrl,
    double alinhamentoInicial = 0,
  }) {
    return Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (context) => CoverPositionEditor(
          imageUrl: imageUrl,
          alinhamentoInicial: alinhamentoInicial,
        ),
      ),
    );
  }

  @override
  State<CoverPositionEditor> createState() => _CoverPositionEditorState();
}

class _CoverPositionEditorState extends State<CoverPositionEditor> {
  late double _alinhamentoY = widget.alinhamentoInicial.clamp(-1.0, 1.0);

  // 200px de arrasto = ponta a ponta do alinhamento (-1.0 a 1.0) — dá pra
  // ajustar com precisão sem exigir um arrasto enorme.
  static const _sensibilidade = 200.0;

  void _arrastar(DragUpdateDetails details) {
    setState(() {
      _alinhamentoY =
          (_alinhamentoY - details.delta.dy / _sensibilidade).clamp(-1.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Ajustar posição da capa'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_alinhamentoY),
            child: const Text('SALVAR'),
          ),
        ],
      ),
      // O gesto cobre a tela inteira, não só a prévia — mais espaço pra
      // arrastar sem precisar acertar a faixa estreita da capa.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: _arrastar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Arraste a foto para cima ou para baixo para escolher a área que aparece no perfil.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted),
              ),
            ),
            Semantics(
              label: 'Prévia da capa. Arraste na tela para reposicionar.',
              image: true,
              child: ExcludeSemantics(
                child: PetCoverImage(
                  capaUrl: widget.imageUrl,
                  height: 140,
                  alignmentY: _alinhamentoY,
                ),
              ),
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
