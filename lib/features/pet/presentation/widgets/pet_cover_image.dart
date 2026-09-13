import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Capa do cabeçalho do perfil do pet, atrás do avatar. A maioria dos pets
/// não tem capa (nunca existiu antes desta feature) — nesse caso mostra um
/// gradiente do design system, nunca uma foto inventada nem uma área quebrada.
class PetCoverImage extends StatelessWidget {
  const PetCoverImage({
    super.key,
    required this.capaUrl,
    this.height = 140,
    this.borderRadius = BorderRadius.zero,
  });

  final String? capaUrl;
  final double height;
  final BorderRadiusGeometry borderRadius;

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
        placeholder: (context, url) => Container(
          height: height,
          width: double.infinity,
          color: AppColors.surface,
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
