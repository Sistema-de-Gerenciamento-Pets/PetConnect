import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/br_date.dart';
import '../../domain/pet.dart';
import 'pet_avatar.dart';
import 'pet_cover_image.dart';

/// Cabeçalho de identidade do pet: capa ao fundo, avatar sobreposto e
/// deslocado para a esquerda (RF15 + mídia do perfil, 2026-09-13), nome e um
/// resumo dos dados básicos. Só mostra o que realmente existe no cadastro —
/// nunca um campo vazio ou "null".
class PetProfileHeader extends StatelessWidget {
  const PetProfileHeader({super.key, required this.pet});

  final Pet pet;

  static const _avatarRadius = 44.0;

  @override
  Widget build(BuildContext context) {
    final idade = idadeEmAnos(pet.dataNascimento);
    final especieRaca =
        [pet.especie, pet.raca].where((s) => s.isNotEmpty).join(' · ');
    final generoFeminino = pet.genero.toLowerCase().startsWith('f');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            PetCoverImage(
              capaUrl: pet.capa,
              height: 140,
              borderRadius: BorderRadius.circular(24),
            ),
            Positioned(
              left: 20,
              bottom: -_avatarRadius,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: PetAvatar(
                  fotoUrl: pet.foto,
                  radius: _avatarRadius,
                  nomeDoPet: pet.nome,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: _avatarRadius + 12),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pet.nome,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (especieRaca.isNotEmpty) _InfoChip(text: especieRaca),
                  if (idade != null)
                    _InfoChip(text: '$idade ${idade == 1 ? 'ano' : 'anos'}')
                  else if (pet.dataNascimento.isNotEmpty)
                    _InfoChip(
                        text: pet.dataNascimento, icon: Icons.cake_outlined),
                  if (pet.genero.isNotEmpty)
                    _InfoChip(
                      text: pet.genero,
                      icon: generoFeminino ? Icons.female : Icons.male,
                    ),
                  if (pet.peso.isNotEmpty)
                    _InfoChip(
                        text: pet.peso, icon: Icons.monitor_weight_outlined),
                  _InfoChip(
                    text: pet.vacinado ? 'Vacinado' : 'Não vacinado',
                    icon: pet.vacinado
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: pet.vacinado
                        ? const Color(0xFF2E7D32)
                        : AppColors.error,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cor = color ?? AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: cor),
            const SizedBox(width: 4),
          ],
          // Flexible + ellipsis: espécie/raça combinados podem ser longos —
          // nunca deixa o chip estourar a largura disponível (seção 10/29
          // do briefing de mídia do perfil, "sem overflow" em 320px).
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: cor),
            ),
          ),
        ],
      ),
    );
  }
}
