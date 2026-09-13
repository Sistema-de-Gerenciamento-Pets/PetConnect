import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';

/// Capa do cabeçalho do perfil do pet, atrás do avatar. A maioria dos pets
/// não tem capa (nunca existiu antes desta feature) — nesse caso mostra um
/// gradiente do design system, nunca uma foto inventada nem uma área quebrada.
///
/// O gradiente de fallback ([AppColors.brandGradient]) é fixo em todos os
/// modos de aparência de propósito — é um momento de marca, não uma
/// superfície de conteúdo (mesma decisão da splash screen).
class PetCoverImage extends StatelessWidget {
  const PetCoverImage({
    super.key,
    required this.capaUrl,
    this.height = 140,
    this.borderRadius = BorderRadius.zero,
    this.alignmentY = 0,
  });

  final String? capaUrl;
  final double height;
  final BorderRadiusGeometry borderRadius;

  /// De -1.0 (topo) a 1.0 (base) — qual parte da foto fica visível dentro
  /// do recorte, escolhida pelo tutor em vez do centro automático.
  final double alignmentY;

  bool get temCapa => capaUrl != null && capaUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!temCapa) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          height: height,
          width: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: capaUrl!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment(0, alignmentY),
        placeholder: (context, url) => Container(
          height: height,
          width: double.infinity,
          color: context.colors.surface,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          height: height,
          width: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        ),
      ),
    );
  }
}
