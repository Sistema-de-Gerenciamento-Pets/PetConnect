import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/br_date.dart';
import '../../domain/pet.dart';
import 'pet_avatar.dart';

/// Cabeçalho de identidade do pet: foto em destaque, nome e um resumo dos
/// dados básicos (RF15). Só mostra o que realmente existe no cadastro —
/// nunca um campo vazio ou "null" (ver seção 4/16 do briefing de layout).
class PetProfileHeader extends StatelessWidget {
  const PetProfileHeader({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final idade = idadeEmAnos(pet.dataNascimento);
    final especieRaca =
        [pet.especie, pet.raca].where((s) => s.isNotEmpty).join(' · ');
    final generoFeminino = pet.genero.toLowerCase().startsWith('f');

    return Column(
      children: [
        Semantics(
          label: 'Foto de ${pet.nome}',
          image: true,
          child: PetAvatar(fotoUrl: pet.foto, radius: 56),
        ),
        const SizedBox(height: 16),
        Text(
          pet.nome,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (especieRaca.isNotEmpty) _InfoChip(text: especieRaca),
            if (idade != null)
              _InfoChip(text: '$idade ${idade == 1 ? 'ano' : 'anos'}')
            else if (pet.dataNascimento.isNotEmpty)
              _InfoChip(text: pet.dataNascimento, icon: Icons.cake_outlined),
            if (pet.genero.isNotEmpty)
              _InfoChip(
                text: pet.genero,
                icon: generoFeminino ? Icons.female : Icons.male,
              ),
            if (pet.peso.isNotEmpty)
              _InfoChip(text: pet.peso, icon: Icons.monitor_weight_outlined),
            _InfoChip(
              text: pet.vacinado ? 'Vacinado' : 'Não vacinado',
              icon: pet.vacinado
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: pet.vacinado ? const Color(0xFF2E7D32) : AppColors.error,
            ),
          ],
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
          Text(
            text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: cor),
          ),
        ],
      ),
    );
  }
}
