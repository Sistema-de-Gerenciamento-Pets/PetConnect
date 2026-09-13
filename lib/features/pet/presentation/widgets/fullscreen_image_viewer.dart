import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Visualizador fullscreen de uma imagem do pet (avatar ou capa), com zoom
/// e pan via [InteractiveViewer] — sem dependência nova. Empurrado como uma
/// rota comum (não uma rota nomeada do go_router): é uma visão efêmera, sem
/// necessidade de deep link nem de entrar no histórico de navegação do app.
/// Back do Android e gesto de voltar funcionam de graça, por ser uma rota
/// normal do [Navigator].
class FullscreenImageViewer extends StatelessWidget {
  const FullscreenImageViewer(
      {super.key, required this.imageUrl, this.semanticLabel});

  final String imageUrl;
  final String? semanticLabel;

  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    String? semanticLabel,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: FullscreenImageViewer(
              imageUrl: imageUrl, semanticLabel: semanticLabel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Semantics(
        label: semanticLabel,
        image: true,
        child: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const CircularProgressIndicator(
                color: Colors.white,
              ),
              errorWidget: (context, url, error) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
