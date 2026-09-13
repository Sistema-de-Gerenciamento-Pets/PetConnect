import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import 'fullscreen_image_viewer.dart';

/// Foto do pet em destaque no cabeçalho do perfil (RF15). Usa cache de
/// imagem (evita rebaixar a mesma foto a cada rebuild) e sempre cai para um
/// ícone quando não há foto ou o carregamento falha — nunca quebra a tela
/// por causa de uma URL ruim.
///
/// Toque abre a visualização fullscreen (só quando há foto de verdade —
/// tocar no fallback não faz nada, e o `Semantics` avisa que não há foto).
class PetAvatar extends StatelessWidget {
  const PetAvatar({
    super.key,
    required this.fotoUrl,
    this.radius = 56,
    this.nomeDoPet = 'o pet',
  });

  final String? fotoUrl;
  final double radius;
  final String nomeDoPet;

  bool get _temFoto => fotoUrl != null && fotoUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final diametro = radius * 2;
    final colors = context.colors;

    return Semantics(
      label: _temFoto
          ? 'Foto de $nomeDoPet. Toque duas vezes para ampliar.'
          : '$nomeDoPet não possui foto cadastrada.',
      image: true,
      child: GestureDetector(
        onTap: _temFoto
            ? () => FullscreenImageViewer.open(
                  context,
                  imageUrl: fotoUrl!,
                  semanticLabel: 'Foto de $nomeDoPet',
                )
            : null,
        child: ExcludeSemantics(
          child: _temFoto
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: fotoUrl!,
                    width: diametro,
                    height: diametro,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => SizedBox(
                      width: diametro,
                      height: diametro,
                      child: ColoredBox(
                        color: colors.surface,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) =>
                        _Fallback(diametro: diametro, radius: radius),
                  ),
                )
              : _Fallback(diametro: diametro, radius: radius),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.diametro, required this.radius});

  final double diametro;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: diametro,
      height: diametro,
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.pets, size: radius * 0.85, color: colors.brandMedium),
    );
  }
}
