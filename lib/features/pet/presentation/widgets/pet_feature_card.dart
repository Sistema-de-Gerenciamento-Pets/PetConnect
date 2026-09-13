import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Card visual de uma funcionalidade principal do perfil do pet (Carteira
/// de Vacinas, Consultas, Histórico, QR Code). O card inteiro é clicável —
/// não só o ícone ou uma seta — e carrega um `Semantics` próprio para
/// leitores de tela (seção 5/11 do briefing de layout).
class PetFeatureCard extends StatelessWidget {
  const PetFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.background,
    required this.accent,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color background;
  final Color accent;
  final VoidCallback onTap;

  /// Indicador visual de atenção (ex.: dose de vacina pendente). Nunca é a
  /// única forma de transmitir o alerta — o ícone também muda.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: badge
          ? '$title. $description Atenção: requer sua atenção.'
          : '$title. $description',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: accent, size: 22),
                      ),
                      if (badge)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
