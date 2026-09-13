import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Badge "Vacina pendente" do card de pet na Home — só aparece quando o
/// pet **não tem nenhuma vacina cadastrada**. Não representa calendário
/// vacinal atrasado nem reforço vencido, só ausência total de registro
/// (ver docs/features/tutor-home.md).
///
/// Widget "burro" de propósito: quem decide `visible` (o card) é quem já
/// está observando `vacinasProvider` — evita que o próprio badge tenha
/// que lidar com loading/erro (e arriscar mostrar "pendente" errado
/// enquanto o status ainda não é conhecido).
class VaccinePendingBadge extends StatelessWidget {
  const VaccinePendingBadge({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final colors = context.colors;
    // Reaproveita o laranja cíclico já usado em outros cards do app —
    // nenhum token novo só para este badge.
    final foreground = colors.petCardAccents[1];
    final background = colors.petCardBackgrounds[1];

    return Semantics(
      label: 'Nenhuma vacina cadastrada.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 14, color: foreground),
              const SizedBox(width: 4),
              // Flexible (não Text direto): em telas estreitas, o Wrap que
              // envolve este badge pode sobrar menos espaço do que o texto
              // precisaria — sem isto o Row estoura em vez de encolher
              // (mesmo cuidado de _InfoChip no perfil do pet).
              Flexible(
                child: Text(
                  'Vacina pendente',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: foreground,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
