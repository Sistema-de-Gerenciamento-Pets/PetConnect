import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/br_date.dart';
import '../../domain/pet.dart';

/// Card de um pet na lista da Home (RF11) — foto grande, selo de espécie,
/// idade e um badge de gênero, com uma cor de destaque cíclica por posição
/// na lista (ver [AppPalette.petCardBackgrounds]).
class PetCard extends StatelessWidget {
  const PetCard(
      {super.key,
      required this.pet,
      required this.colorIndex,
      required this.onTap});

  final Pet pet;
  final int colorIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = colors
        .petCardBackgrounds[colorIndex % colors.petCardBackgrounds.length];
    final accent =
        colors.petCardAccents[colorIndex % colors.petCardAccents.length];
    final idade = idadeEmAnos(pet.dataNascimento);
    final generoFeminino = pet.genero.toLowerCase().startsWith('f');

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: colors.cardBackground,
                    backgroundImage:
                        pet.foto != null ? NetworkImage(pet.foto!) : null,
                    child: pet.foto == null
                        ? Icon(Icons.pets, color: accent, size: 32)
                        : null,
                  ),
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: accent,
                      child:
                          Icon(Icons.pets, color: colors.textOnBrand, size: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.nome,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        pet.especie,
                        if (idade != null)
                          '$idade ${idade == 1 ? 'ano' : 'anos'}'
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: TextStyle(color: colors.textMuted, fontSize: 13),
                    ),
                    if (pet.genero.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              generoFeminino ? Icons.female : Icons.male,
                              size: 14,
                              color: accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              pet.genero,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: accent,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 20,
                backgroundColor: accent,
                child: Icon(Icons.arrow_forward,
                    color: colors.textOnBrand, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
