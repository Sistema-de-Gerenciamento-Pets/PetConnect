import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Foto do pet em destaque no cabeçalho do perfil (RF15). Usa cache de
/// imagem (evita rebaixar a mesma foto a cada rebuild) e sempre cai para um
/// ícone quando não há foto ou o carregamento falha — nunca quebra a tela
/// por causa de uma URL ruim.
class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, required this.fotoUrl, this.radius = 56});

  final String? fotoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final foto = fotoUrl;
    final diametro = radius * 2;

    if (foto == null || foto.isEmpty) {
      return _Fallback(diametro: diametro, radius: radius);
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: foto,
        width: diametro,
        height: diametro,
        fit: BoxFit.cover,
        placeholder: (context, url) => SizedBox(
          width: diametro,
          height: diametro,
          child: const ColoredBox(
            color: AppColors.surface,
            child: Center(
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
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.diametro, required this.radius});

  final double diametro;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diametro,
      height: diametro,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child:
          Icon(Icons.pets, size: radius * 0.85, color: AppColors.brandMedium),
    );
  }
}
