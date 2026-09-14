import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/br_date.dart';
import '../../domain/pet.dart';
import '../providers/vacina_providers.dart';
import 'pet_gender_badge.dart';
import 'vaccine_pending_badge.dart';

/// Card de um pet na lista da Home (RF11) — fundo branco/limpo uniforme
/// (o destaque colorido agora fica só no badge de pata sobre a foto, não
/// no fundo do card inteiro — redesign de 2026-09-13, ver
/// docs/features/tutor-home.md). Foto grande, nome em destaque, espécie +
/// idade, badge de gênero e, quando aplicável, badge de vacina pendente.
///
/// O card inteiro continua sendo o acesso ao perfil do pet — não exige
/// toque no chevron.
class PetCard extends ConsumerWidget {
  const PetCard(
      {super.key,
      required this.pet,
      required this.colorIndex,
      required this.onTap});

  final Pet pet;
  final int colorIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final accent =
        colors.petCardAccents[colorIndex % colors.petCardAccents.length];
    final idade = idadeEmAnos(pet.dataNascimento);
    final especieIdade = [
      pet.especie,
      if (idade != null) '$idade ${idade == 1 ? 'ano' : 'anos'}',
    ].where((s) => s.isNotEmpty).join(' · ');

    // Só classifica "sem vacina" depois de confirmar a lista vazia —
    // nunca durante loading nem em caso de erro (RF de vacina pendente,
    // seção 18/37 do briefing): declarar pendência sem ter certeza seria
    // pior que não mostrar nada.
    final vacinasAsync = ref.watch(vacinasProvider(pet.id));
    final semVacinaCadastrada = vacinasAsync.maybeWhen(
      data: (vacinas) => vacinas.isEmpty,
      orElse: () => false,
    );

    final semanticsPartes = [
      pet.nome,
      if (pet.especie.isNotEmpty) pet.especie.toLowerCase(),
      if (idade != null) '$idade ${idade == 1 ? 'ano' : 'anos'}',
      if (pet.genero.isNotEmpty) pet.genero.toLowerCase(),
    ];
    final semanticsLabel = '${semanticsPartes.join(', ')}.'
        '${semVacinaCadastrada ? ' Nenhuma vacina cadastrada.' : ''}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Material(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipOval(
                        child: pet.foto != null && pet.foto!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: pet.foto!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    _FallbackFoto(accent: accent),
                                errorWidget: (context, url, error) =>
                                    _FallbackFoto(accent: accent),
                              )
                            : _FallbackFoto(accent: accent),
                      ),
                      // Decorativo — não precisa de rótulo próprio pro
                      // leitor de tela (seção 11 do briefing).
                      Positioned(
                        bottom: -2,
                        left: -2,
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: accent,
                          child: Icon(Icons.pets,
                              color: colors.textOnBrand, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (especieIdade.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              especieIdade,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: colors.textMuted, fontSize: 13),
                            ),
                          ],
                          if (pet.genero.isNotEmpty || semVacinaCadastrada) ...[
                            const SizedBox(height: 8),
                            // Wrap (não Row): em telas estreitas, o badge
                            // de vacina pendente quebra pra linha de baixo
                            // em vez de estourar (seção 27 do briefing).
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (pet.genero.isNotEmpty)
                                  PetGenderBadge(genero: pet.genero),
                                VaccinePendingBadge(
                                    visible: semVacinaCadastrada),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Icon(Icons.chevron_right, color: colors.textMuted),
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

class _FallbackFoto extends StatelessWidget {
  const _FallbackFoto({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: ColoredBox(
        color: context.colors.surface,
        child: Center(child: Icon(Icons.pets, color: accent, size: 32)),
      ),
    );
  }
}
