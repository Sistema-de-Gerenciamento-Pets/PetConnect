import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Badge compacto de gênero do pet (♂ Macho / ♀ Fêmea) — usado no card da
/// Home. Nunca depende só de cor: o ícone e o texto do gênero continuam
/// presentes de qualquer forma.
///
/// "Macho" reaproveita o azul cíclico já usado em outros cards do app
/// (`petCardAccents`/`petCardBackgrounds[3]`); "Fêmea" usa o par de tons
/// de rosa da paleta — não havia nenhum tom de rosa reutilizável antes
/// desta tela.
class PetGenderBadge extends StatelessWidget {
  const PetGenderBadge({super.key, required this.genero});

  final String genero;

  bool get _feminino => genero.toLowerCase().startsWith('f');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground =
        _feminino ? colors.genderFemaleForeground : colors.petCardAccents[3];
    final background = _feminino
        ? colors.genderFemaleBackground
        : colors.petCardBackgrounds[3];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_feminino ? Icons.female : Icons.male,
              size: 14, color: foreground),
          const SizedBox(width: 4),
          // Flexible por segurança: mesmo cuidado do VaccinePendingBadge
          // pra não estourar em telas estreitas quando os dois badges
          // dividem a mesma linha do Wrap.
          Flexible(
            child: Text(
              genero,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
